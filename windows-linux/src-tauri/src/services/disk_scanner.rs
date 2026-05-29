//! Disk junk discovery + safe cleanup.
//!
//! Cleanup is **never** rm -rf. Every entry is moved to the user's trash via
//! `platform::host::trash_path`, which uses the `trash` crate (GIO on Linux,
//! IFileOperation on Windows). Each category has explicit safety rules.

use crate::platform::host;
use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::time::{Duration, SystemTime};
use walkdir::WalkDir;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Category {
    UserCache,
    AppLogs,
    TempFiles,
    OldDownloads,
    Trash,
    DevCaches,
}

impl Category {
    pub fn label(self) -> &'static str {
        match self {
            Self::UserCache => "User caches",
            Self::AppLogs => "Application logs",
            Self::TempFiles => "Temporary files",
            Self::OldDownloads => "Old downloads (30+ days)",
            Self::Trash => "Trash bin",
            Self::DevCaches => "Developer caches",
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct JunkEntry {
    pub category: Category,
    pub path: PathBuf,
    pub size: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ScanReport {
    pub entries: Vec<JunkEntry>,
    pub total_bytes: u64,
}

/// Walks each category root and reports candidate paths with cumulative size.
pub fn scan(categories: &[Category]) -> ScanReport {
    let mut entries = Vec::new();
    for cat in categories {
        entries.extend(scan_category(*cat));
    }
    let total_bytes = entries.iter().map(|e| e.size).sum();
    ScanReport { entries, total_bytes }
}

fn scan_category(cat: Category) -> Vec<JunkEntry> {
    let roots = roots_for(cat);
    let mut out = Vec::new();
    for root in roots {
        if !root.exists() {
            continue;
        }
        match cat {
            Category::OldDownloads => {
                out.extend(scan_old_downloads(&root));
            }
            _ => {
                // Top-level entries inside the category root — gives users
                // granular control (they can leave one folder, trash another).
                if let Ok(rd) = std::fs::read_dir(&root) {
                    for entry in rd.flatten() {
                        let path = entry.path();
                        if !is_safe_to_trash(&path, cat) {
                            continue;
                        }
                        let size = path_size(&path);
                        if size == 0 {
                            continue;
                        }
                        out.push(JunkEntry { category: cat, path, size });
                    }
                }
            }
        }
    }
    out
}

fn scan_old_downloads(root: &Path) -> Vec<JunkEntry> {
    let cutoff = SystemTime::now() - Duration::from_secs(60 * 60 * 24 * 30);
    let mut out = Vec::new();
    if let Ok(rd) = std::fs::read_dir(root) {
        for entry in rd.flatten() {
            let path = entry.path();
            let Ok(md) = entry.metadata() else { continue };
            let mtime = md.modified().unwrap_or(SystemTime::UNIX_EPOCH);
            if mtime > cutoff {
                continue;
            }
            let size = path_size(&path);
            if size == 0 {
                continue;
            }
            out.push(JunkEntry {
                category: Category::OldDownloads,
                path,
                size,
            });
        }
    }
    out
}

/// Move every entry in `categories` to the user's trash. Returns bytes recovered.
pub fn clean(entries: &[JunkEntry]) -> Result<u64> {
    let mut recovered = 0u64;
    for entry in entries {
        if !entry.path.exists() {
            continue;
        }
        match host::trash_path(&entry.path) {
            Ok(_) => recovered += entry.size,
            Err(e) => {
                tracing::warn!("failed to trash {}: {e}", entry.path.display());
            }
        }
    }
    Ok(recovered)
}

// --- platform-specific roots --------------------------------------------------

#[cfg(target_os = "linux")]
fn roots_for(cat: Category) -> Vec<PathBuf> {
    let home = dirs::home_dir().unwrap_or_default();
    match cat {
        Category::UserCache => vec![home.join(".cache")],
        Category::AppLogs => vec![home.join(".local/state")],
        Category::TempFiles => vec![PathBuf::from("/tmp"), PathBuf::from("/var/tmp")],
        Category::OldDownloads => host::downloads_dir().into_iter().collect(),
        Category::Trash => vec![home.join(".local/share/Trash/files")],
        Category::DevCaches => vec![
            home.join(".cache/pip"),
            home.join(".cache/npm"),
            home.join(".npm/_cacache"),
            home.join(".cache/yarn"),
            home.join(".cargo/registry/cache"),
            home.join(".cache/go-build"),
        ],
    }
}

#[cfg(target_os = "windows")]
fn roots_for(cat: Category) -> Vec<PathBuf> {
    let local = std::env::var_os("LOCALAPPDATA").map(PathBuf::from).unwrap_or_default();
    let app = std::env::var_os("APPDATA").map(PathBuf::from).unwrap_or_default();
    let temp = std::env::var_os("TEMP").map(PathBuf::from).unwrap_or_default();
    let windir = std::env::var_os("WINDIR").map(PathBuf::from).unwrap_or_default();
    match cat {
        Category::UserCache => vec![local.join("Temp"), local.join("Microsoft/Windows/INetCache")],
        Category::AppLogs => vec![local.join("CrashDumps"), windir.join("Logs")],
        Category::TempFiles => vec![temp, windir.join("Temp")],
        Category::OldDownloads => host::downloads_dir().into_iter().collect(),
        Category::Trash => vec![], // handled via SHEmptyRecycleBin (future)
        Category::DevCaches => vec![
            local.join("NuGet/v3-cache"),
            local.join("pip/Cache"),
            app.join("npm-cache"),
        ],
    }
    .into_iter()
    .filter(|p| !p.as_os_str().is_empty())
    .collect()
}

/// Safety rules: never trash directories that look load-bearing
/// (e.g. `~/.cache/mesa_shader_cache` is fine, but `~/.cache` itself is not).
fn is_safe_to_trash(path: &Path, cat: Category) -> bool {
    let Some(name) = path.file_name().and_then(|s| s.to_str()) else {
        return false;
    };
    // Never delete hidden roots or symlinks to elsewhere.
    if path.is_symlink() {
        return false;
    }
    // Cross-category blocklist of names that are dangerous to trash blindly.
    const BLOCKLIST: &[&str] = &["Trash", "trash", ".", "..", "lost+found"];
    if BLOCKLIST.contains(&name) {
        return false;
    }
    match cat {
        Category::TempFiles => {
            // Avoid wiping live socket dirs (systemd, X11, pulse) in /tmp.
            !matches!(name, ".X11-unix" | ".ICE-unix" | ".font-unix" | "systemd-private-*" | "snap-private-tmp")
                && !name.starts_with("systemd-private-")
                && !name.starts_with(".XIM-unix")
        }
        _ => true,
    }
}

fn path_size(path: &Path) -> u64 {
    if path.is_file() {
        return path.metadata().map(|m| m.len()).unwrap_or(0);
    }
    let mut total = 0u64;
    for entry in WalkDir::new(path).into_iter().filter_map(|e| e.ok()) {
        if let Ok(md) = entry.metadata() {
            if md.is_file() {
                total = total.saturating_add(md.len());
            }
        }
    }
    total
}
