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
