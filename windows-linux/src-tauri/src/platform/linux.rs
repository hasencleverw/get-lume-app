//! Linux host glue. Privileged ops via pkexec; trash via `gio trash`
//! (already present on every major desktop — KDE, GNOME, XFCE).

use anyhow::{anyhow, Context, Result};
use std::path::{Path, PathBuf};
use std::process::Command;

/// Free OS file-system caches: requires root via pkexec.
/// `sync && echo 3 > /proc/sys/vm/drop_caches`
pub fn free_system_memory() -> Result<()> {
    let status = Command::new("pkexec")
        .args([
            "sh",
            "-c",
            "sync && echo 3 > /proc/sys/vm/drop_caches",
        ])
        .status()
        .context("failed to spawn pkexec")?;
    if !status.success() {
        return Err(anyhow!("pkexec exited with status {:?}", status.code()));
    }
    Ok(())
}

/// Send a path to the user's trash via the `trash` crate (GIO-compatible).
pub fn trash_path(path: &Path) -> Result<()> {
    trash::delete(path).with_context(|| format!("failed to trash {}", path.display()))
}

/// XDG-aware download directory.
pub fn downloads_dir() -> Option<PathBuf> {
    dirs::download_dir()
}

/// Flush DNS via systemd-resolved (most modern distros). Falls back to nscd.
pub fn flush_dns() -> Result<()> {
    if Command::new("which").arg("resolvectl").status()?.success() {
        let st = Command::new("pkexec")
            .args(["resolvectl", "flush-caches"])
            .status()?;
        if st.success() {
            return Ok(());
        }
    }
    let st = Command::new("pkexec")
        .args(["systemctl", "restart", "nscd"])
        .status()?;
    if !st.success() {
        return Err(anyhow!("no supported DNS resolver found"));
    }
    Ok(())
}

// ============================================================================
// XDG autostart helpers
// ============================================================================
//
// Linux convention: a `.desktop` file in `~/.config/autostart` is launched
// by the session manager on login. Adding/removing the file toggles
// autostart at the user level, no system-wide changes or root needed.

fn autostart_desktop_path() -> Option<PathBuf> {
    dirs::config_dir().map(|p| p.join("autostart").join("lume.desktop"))
}

pub fn is_autostart_enabled() -> bool {
    autostart_desktop_path().is_some_and(|p| p.exists())
}

pub fn set_autostart(enabled: bool) -> Result<()> {
    let Some(p) = autostart_desktop_path() else {
        return Err(anyhow!("no XDG config dir"));
    };
    if !enabled {
        if p.exists() {
            std::fs::remove_file(&p).with_context(|| format!("rm {}", p.display()))?;
        }
        return Ok(());
    }
    if let Some(parent) = p.parent() {
        std::fs::create_dir_all(parent)?;
    }
    // Prefer the system-installed path; fall back to whatever Lume was launched as.
    let exec = if Path::new("/usr/bin/lume").exists() {
        "/usr/bin/lume".to_string()
    } else if let Some(home) = dirs::home_dir() {
        let local = home.join(".local").join("bin").join("lume");
        if local.exists() {
            local.to_string_lossy().into_owned()
        } else {
            "lume".to_string()
        }
    } else {
        "lume".to_string()
    };
    let body = format!(
        "[Desktop Entry]\n\
         Type=Application\n\
         Name=Lume\n\
         Exec={exec}\n\
         Icon=lume\n\
         Terminal=false\n\
         X-GNOME-Autostart-enabled=true\n\
         Comment=Lume — System Cleaner\n"
    );
    std::fs::write(&p, body).with_context(|| format!("write {}", p.display()))
}

/// Distribution label, parsed from /etc/os-release.
pub fn distro_pretty_name() -> String {
    std::fs::read_to_string("/etc/os-release")
        .ok()
        .and_then(|s| {
            s.lines()
                .find_map(|l| l.strip_prefix("PRETTY_NAME=").map(|v| v.trim_matches('"').to_string()))
        })
        .unwrap_or_else(|| "Linux".into())
}
