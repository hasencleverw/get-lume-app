//! App discovery and uninstall.
//!
//! Linux sources, in priority order:
//!  1. pacman (Arch family) — `pacman -Qi` gives name, version, size
//!  2. dpkg                  — `dpkg-query -W -f`
//!  3. rpm                   — `rpm -qa --queryformat`
//!  4. flatpak               — `flatpak list --app --columns=...`
//!  5. snap                  — `snap list`
//!  6. desktop entries        — fallback for AppImages and manually-installed apps
//!     (only entries not already covered above)

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::path::PathBuf;
use std::process::Command;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum AppSource {
    Pacman,
    Dpkg,
    Rpm,
    Flatpak,
    Snap,
    Desktop,
    Windows,
}

#[derive(Debug, Clone, Serialize)]
pub struct AppEntry {
    pub id: String,            // unique identifier per source
    pub name: String,
    pub version: Option<String>,
    pub size_bytes: u64,       // 0 if unknown
    pub source: AppSource,
    pub description: Option<String>,
    pub exec: Option<String>,
}

#[cfg(target_os = "linux")]
pub fn list_apps() -> Vec<AppEntry> {
    // We deliberately list GUI applications (apps the user recognizes), not raw
    // distro packages. Enumerating pacman/dpkg/rpm directly would surface 1000+
    // libraries and dependencies — noise no one wants to scroll through. So the
    // sources are: Flatpak, Snap, and freedesktop .desktop entries. When the
    // user removes a .desktop-sourced app, `uninstall` resolves the owning
    // native package on the fly (pacman -Qoq / dpkg -S / rpm -qf).
    let mut apps: Vec<AppEntry> = Vec::new();
    let mut seen = HashSet::new();

    if which("flatpak") {
        apps.extend(flatpak_apps());
    }
    if which("snap") {
        apps.extend(snap_apps());
    }

    for a in &apps {
        seen.insert(a.name.to_lowercase());
    }
    for d in desktop_apps() {
        if !seen.contains(&d.name.to_lowercase()) {
            apps.push(d);
        }
    }

    apps.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes).then(a.name.cmp(&b.name)));
    apps
}

#[cfg(target_os = "windows")]
pub fn list_apps() -> Vec<AppEntry> {
    use winreg::enums::*;
    use winreg::RegKey;

    // Three locations cover ~all conventional installers.
    let sources: &[(winreg::HKEY, &str)] = &[
        (HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
        (HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"),
        (HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"),
    ];

    let mut apps: Vec<AppEntry> = Vec::new();
    let mut seen = std::collections::HashSet::<String>::new();

    for (root, path) in sources {
        let root_key = RegKey::predef(*root);
        let Ok(parent) = root_key.open_subkey(*path) else { continue };
        for sub_name in parent.enum_keys().flatten() {
            let Ok(k) = parent.open_subkey(&sub_name) else { continue };

            let name: String = k.get_value("DisplayName").unwrap_or_default();
            if name.is_empty() { continue; }
            // De-duplicate by display name across hives (32/64-bit mirror, per-user dupes)
            if !seen.insert(name.to_lowercase()) { continue; }

            // Skip Windows Update entries and system components.
            let sys_comp: u32 = k.get_value("SystemComponent").unwrap_or(0);
            if sys_comp == 1 { continue; }
            if name.starts_with("Update for")
                || name.starts_with("Security Update")
                || name.starts_with("Hotfix")
                || name.contains("KB") && name.contains("Microsoft")
            {
                continue;
            }

            let version: String = k.get_value("DisplayVersion").unwrap_or_default();
            let publisher: String = k.get_value("Publisher").unwrap_or_default();
            let size_kb: u32 = k.get_value("EstimatedSize").unwrap_or(0);
            let uninstall: String = k.get_value("UninstallString").unwrap_or_default();
            let quiet_uninstall: String = k.get_value("QuietUninstallString").unwrap_or_default();
            let install_loc: String = k.get_value("InstallLocation").unwrap_or_default();

            apps.push(AppEntry {
                id: if quiet_uninstall.is_empty() { uninstall.clone() } else { quiet_uninstall.clone() },
                name,
                version: if version.is_empty() { None } else { Some(version) },
                size_bytes: (size_kb as u64) * 1024,
                source: AppSource::Windows,
                description: if publisher.is_empty() { None } else { Some(publisher) },
                exec: if install_loc.is_empty() { None } else { Some(install_loc) },
            });
        }
    }

    apps.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes).then(a.name.to_lowercase().cmp(&b.name.to_lowercase())));
    apps
}

#[cfg(target_os = "linux")]
pub fn uninstall(source: AppSource, id: &str) -> anyhow::Result<()> {
    // Helper: run a command, capture stderr, surface a useful message on
    // failure instead of a bare exit code.
    fn run(mut cmd: Command) -> anyhow::Result<()> {
        let out = cmd.output()?;
        if out.status.success() {
            return Ok(());
        }
        let stderr = String::from_utf8_lossy(&out.stderr);
        let stdout = String::from_utf8_lossy(&out.stdout);
        let msg = stderr.trim().lines().last()
            .or_else(|| stdout.trim().lines().last())
            .unwrap_or("falha desconhecida")
            .to_string();
        Err(anyhow::anyhow!("{}", msg))
    }

    match source {
        AppSource::Pacman => {
            let mut c = Command::new("pkexec");
            c.args(["pacman", "-Rns", "--noconfirm", id]);
            run(c)
        }
        AppSource::Dpkg => {
            let mut c = Command::new("pkexec");
            c.args(["apt-get", "remove", "--purge", "-y", id]);
            run(c)
        }
        AppSource::Rpm => {
            let mut c = Command::new("pkexec");
            c.args(["dnf", "remove", "-y", id]);
            run(c)
        }
        AppSource::Flatpak => {
            // Flatpak apps can be installed per-user or system-wide. Try the
            // user scope first (no auth needed); if that says "not installed",
            // fall back to system scope via pkexec. `-y` = --assumeyes.
            let mut user = Command::new("flatpak");
            user.args(["uninstall", "--user", "-y", id]);
            if run(user).is_ok() {
                return Ok(());
            }
            let mut system = Command::new("pkexec");
            system.args(["flatpak", "uninstall", "--system", "-y", id]);
            run(system)
        }
        AppSource::Snap => {
            let mut c = Command::new("pkexec");
            c.args(["snap", "remove", id]);
            run(c)
        }
        AppSource::Desktop => {
            // `id` is the absolute path to the .desktop file. Resolve which
            // package owns it (pacman/dpkg/rpm) and remove that package. If the
            // file belongs to no package (a manually-dropped .desktop in
            // ~/.local/share/applications), just delete the file itself.
            let path = std::path::Path::new(id);

            if which("pacman") {
                if let Ok(out) = Command::new("pacman").args(["-Qoq", id]).env("LC_ALL", "C").output() {
                    if out.status.success() {
                        let pkg = String::from_utf8_lossy(&out.stdout).trim().to_string();
                        if !pkg.is_empty() {
                            let mut c = Command::new("pkexec");
                            c.args(["pacman", "-Rns", "--noconfirm", &pkg]);
                            return run(c);
                        }
                    }
                }
            } else if which("dpkg") {
                if let Ok(out) = Command::new("dpkg").args(["-S", id]).env("LC_ALL", "C").output() {
                    if out.status.success() {
                        let line = String::from_utf8_lossy(&out.stdout);
                        if let Some(pkg) = line.split(':').next().map(|s| s.trim().to_string()) {
                            if !pkg.is_empty() {
                                let mut c = Command::new("pkexec");
                                c.args(["apt-get", "remove", "--purge", "-y", &pkg]);
                                return run(c);
                            }
                        }
                    }
                }
            } else if which("rpm") {
                if let Ok(out) = Command::new("rpm").args(["-qf", id]).env("LC_ALL", "C").output() {
                    if out.status.success() {
                        let pkg = String::from_utf8_lossy(&out.stdout).trim().to_string();
                        if !pkg.is_empty() && !pkg.contains("not owned") {
                            let mut c = Command::new("pkexec");
                            c.args(["dnf", "remove", "-y", &pkg]);
                            return run(c);
                        }
                    }
                }
            }

            // Orphan .desktop — owned by no package. Delete the file directly
            // when it's user-writable; otherwise it needs root we won't assume.
            if path.starts_with(dirs::home_dir().unwrap_or_default()) {
                std::fs::remove_file(path)
                    .map_err(|e| anyhow::anyhow!("falha ao remover atalho: {e}"))
            } else {
                Err(anyhow::anyhow!(
                    "Este app não pertence a nenhum pacote conhecido — remova manualmente"
                ))
            }
        }
        AppSource::Windows => Err(anyhow::anyhow!("Pacotes Windows não desinstaláveis no Linux")),
    }
}

#[cfg(target_os = "windows")]
pub fn uninstall(_source: AppSource, id: &str) -> anyhow::Result<()> {
    // `id` is the registry UninstallString. Forms we handle:
    //   MsiExec.exe /X{GUID}  or  /I{GUID}   → normalize to `msiexec /x {GUID}`
    //   "C:\Path\unins000.exe" /params       → quoted exe + args
    //   C:\Path\uninstall.exe                 → bare exe
    //
    // Running it through `cmd /C` (the old approach) broke on the embedded
    // quotes and never elevated, so most uninstallers silently failed. Instead
    // we split into program + parameters and launch elevated via ShellExecute
    // (runas verb), which both fixes quoting and pops the UAC the installer
    // usually needs. The uninstaller's own window is shown (gui(false)).
    let id = id.trim();
    if id.is_empty() {
        return Err(anyhow::anyhow!("Sem comando de desinstalação registrado"));
    }

    // MSI: extract the product GUID and drive msiexec directly.
    let lower = id.to_ascii_lowercase();
    if lower.contains("msiexec") {
        if let Some(start) = id.find('{') {
            if let Some(end) = id[start..].find('}') {
                let guid = &id[start..start + end + 1];
                let mut cmd = runas::Command::new("msiexec.exe");
                cmd.arg("/x").arg(guid);
                cmd.gui(false);
                return match cmd.status() {
                    Ok(_) => Ok(()),
                    Err(e) => Err(anyhow::anyhow!("Autorização UAC negada: {e}")),
                };
            }
        }
    }

    // Non-MSI: split the command line into program + arguments.
    let (program, args) = split_command_line(id);
    if program.is_empty() {
        return Err(anyhow::anyhow!("Comando de desinstalação inválido"));
    }
    let mut cmd = runas::Command::new(&program);
    if !args.is_empty() {
        cmd.arg(&args);
    }
    cmd.gui(false);
    match cmd.status() {
        Ok(_) => Ok(()),
        Err(e) => Err(anyhow::anyhow!("Autorização UAC negada ou falha: {e}")),
    }
}

/// Split a Windows command line into (program, rest-of-args). Honors a leading
/// quoted path so `"C:\Program Files\App\unins.exe" /S` parses correctly.
#[cfg(target_os = "windows")]
fn split_command_line(s: &str) -> (String, String) {
    let s = s.trim();
    if let Some(rest) = s.strip_prefix('"') {
        if let Some(end) = rest.find('"') {
            let program = rest[..end].to_string();
            let args = rest[end + 1..].trim().to_string();
            return (program, args);
        }
    }
    match s.find(' ') {
        Some(i) => (s[..i].to_string(), s[i + 1..].trim().to_string()),
        None => (s.to_string(), String::new()),
    }
}

// --- Source backends -------------------------------------------------------
//
// pacman_apps/dpkg_apps/rpm_apps are kept for a possible future "system
// packages" view but are not part of the default app listing (which shows GUI
// apps only). Marked allow(dead_code) so they don't warn while unused.

#[cfg(target_os = "linux")]
#[allow(dead_code)]
fn pacman_apps() -> Vec<AppEntry> {
    // -Qi prints multi-line records, blank-separated. LC_ALL=C forces English
    // field labels (Name/Version/Description/Installed Size) — without it, a
    // localized system (e.g. pt_BR prints "Nome"/"Versão") makes every record
    // parse to an empty name and get silently dropped.
    let Ok(out) = Command::new("pacman").args(["-Qi"]).env("LC_ALL", "C").output() else { return vec![] };
    if !out.status.success() { return vec![]; }
    let text = String::from_utf8_lossy(&out.stdout);

    let mut apps = Vec::new();
    let mut name = String::new();
    let mut version = String::new();
    let mut desc = String::new();
    let mut size = 0u64;

    let flush = |apps: &mut Vec<AppEntry>, name: &mut String, version: &mut String, desc: &mut String, size: &mut u64| {
        if !name.is_empty() {
            apps.push(AppEntry {
                id: name.clone(),
                name: std::mem::take(name),
                version: if version.is_empty() { None } else { Some(std::mem::take(version)) },
                size_bytes: *size,
                source: AppSource::Pacman,
                description: if desc.is_empty() { None } else { Some(std::mem::take(desc)) },
                exec: None,
            });
            *size = 0;
        }
    };

    for line in text.lines() {
        if line.is_empty() {
            flush(&mut apps, &mut name, &mut version, &mut desc, &mut size);
            continue;
        }
        if let Some(v) = line.strip_prefix("Name") { name = field(v); }
        else if let Some(v) = line.strip_prefix("Version") { version = field(v); }
        else if let Some(v) = line.strip_prefix("Description") { desc = field(v); }
        else if let Some(v) = line.strip_prefix("Installed Size") {
            size = parse_pacman_size(&field(v));
        }
    }
    flush(&mut apps, &mut name, &mut version, &mut desc, &mut size);
    apps
}

#[cfg(target_os = "linux")]
#[allow(dead_code)]
fn dpkg_apps() -> Vec<AppEntry> {
    let Ok(out) = Command::new("dpkg-query")
        .args(["-W", "-f", "${Package}\t${Version}\t${Installed-Size}\t${binary:Summary}\n"])
        .output() else { return vec![] };
    if !out.status.success() { return vec![]; }
    String::from_utf8_lossy(&out.stdout).lines().filter_map(|l| {
        let mut parts = l.splitn(4, '\t');
        let name = parts.next()?.to_string();
        let version = parts.next().map(|s| s.to_string());
        let kb: u64 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
        let desc = parts.next().map(|s| s.to_string());
        Some(AppEntry {
            id: name.clone(), name, version,
            size_bytes: kb * 1024, source: AppSource::Dpkg, description: desc, exec: None,
        })
    }).collect()
}

#[cfg(target_os = "linux")]
#[allow(dead_code)]
fn rpm_apps() -> Vec<AppEntry> {
    let Ok(out) = Command::new("rpm")
        .args(["-qa", "--queryformat", "%{NAME}\t%{VERSION}\t%{SIZE}\t%{SUMMARY}\n"])
        .output() else { return vec![] };
    if !out.status.success() { return vec![]; }
    String::from_utf8_lossy(&out.stdout).lines().filter_map(|l| {
        let mut parts = l.splitn(4, '\t');
        let name = parts.next()?.to_string();
        let version = parts.next().map(|s| s.to_string());
        let bytes: u64 = parts.next().and_then(|s| s.parse().ok()).unwrap_or(0);
        let desc = parts.next().map(|s| s.to_string());
        Some(AppEntry {
            id: name.clone(), name, version,
            size_bytes: bytes, source: AppSource::Rpm, description: desc, exec: None,
        })
    }).collect()
}

#[cfg(target_os = "linux")]
fn flatpak_apps() -> Vec<AppEntry> {
    let Ok(out) = Command::new("flatpak")
        .args(["list", "--app", "--columns=application,name,version,size"])
        .output() else { return vec![] };
    if !out.status.success() { return vec![]; }
    String::from_utf8_lossy(&out.stdout).lines().filter_map(|l| {
        let parts: Vec<_> = l.split('\t').collect();
        if parts.len() < 2 { return None; }
        let id = parts[0].to_string();
        let name = parts[1].to_string();
        let version = parts.get(2).map(|s| s.to_string()).filter(|s| !s.is_empty());
        let size = parts.get(3).map(|s| parse_human_size(s)).unwrap_or(0);
        Some(AppEntry {
            id, name, version, size_bytes: size,
            source: AppSource::Flatpak, description: None, exec: None,
        })
    }).collect()
}

#[cfg(target_os = "linux")]
fn snap_apps() -> Vec<AppEntry> {
    let Ok(out) = Command::new("snap").args(["list"]).output() else { return vec![] };
    if !out.status.success() { return vec![]; }
    let text = String::from_utf8_lossy(&out.stdout);
    text.lines().skip(1).filter_map(|l| {
        let parts: Vec<_> = l.split_whitespace().collect();
        if parts.len() < 2 { return None; }
        Some(AppEntry {
            id: parts[0].to_string(),
            name: parts[0].to_string(),
            version: parts.get(1).map(|s| s.to_string()),
            size_bytes: 0,
            source: AppSource::Snap,
            description: None,
            exec: None,
        })
    }).collect()
}

#[cfg(target_os = "linux")]
fn desktop_apps() -> Vec<AppEntry> {
    let mut out = Vec::new();
    let mut dirs: Vec<PathBuf> = vec![
        PathBuf::from("/usr/share/applications"),
        PathBuf::from("/var/lib/flatpak/exports/share/applications"),
    ];
    if let Some(h) = dirs::data_local_dir() {
        dirs.push(h.join("applications"));
    }
    for d in dirs {
        let Ok(rd) = std::fs::read_dir(&d) else { continue };
        for e in rd.flatten() {
            let p = e.path();
            if p.extension().and_then(|s| s.to_str()) != Some("desktop") { continue; }
            let Ok(text) = std::fs::read_to_string(&p) else { continue };
            let mut name = String::new();
            let mut exec = String::new();
            let mut nodisplay = false;
            for line in text.lines() {
                if let Some(v) = line.strip_prefix("Name=") { if name.is_empty() { name = v.into(); } }
                else if let Some(v) = line.strip_prefix("Exec=") { if exec.is_empty() { exec = v.into(); } }
                else if line == "NoDisplay=true" || line == "Hidden=true" { nodisplay = true; }
                else if line.starts_with('[') && !name.is_empty() { break; } // only main section
            }
            if name.is_empty() || nodisplay { continue; }
            out.push(AppEntry {
                id: p.to_string_lossy().to_string(),
                name, version: None, size_bytes: 0,
                source: AppSource::Desktop,
                description: None,
                exec: if exec.is_empty() { None } else { Some(exec) },
            });
        }
    }
    out
}

// --- parsing helpers -------------------------------------------------------

#[allow(dead_code)]
fn field(s: &str) -> String {
    s.split_once(':').map(|(_, v)| v.trim().to_string()).unwrap_or_else(|| s.trim().to_string())
}

#[allow(dead_code)]
fn parse_pacman_size(s: &str) -> u64 {
    // "12.34 MiB" / "456.78 KiB" / "9.0 B"
    let s = s.trim();
    let mut num = String::new();
    let mut unit = String::new();
    let mut at_unit = false;
    for ch in s.chars() {
        if ch.is_ascii_digit() || ch == '.' { num.push(ch); }
        else if ch.is_whitespace() { at_unit = true; }
        else if at_unit { unit.push(ch); }
    }
    let val: f64 = num.parse().unwrap_or(0.0);
    let mult = match unit.to_ascii_uppercase().as_str() {
        "KIB" | "KB" | "K" => 1024.0,
        "MIB" | "MB" | "M" => 1024.0 * 1024.0,
        "GIB" | "GB" | "G" => 1024.0_f64.powi(3),
        "TIB" | "TB" | "T" => 1024.0_f64.powi(4),
        _ => 1.0,
    };
    (val * mult) as u64
}

fn parse_human_size(s: &str) -> u64 {
    let s = s.trim();
    if s.is_empty() { return 0; }
    let mut num = String::new();
    let mut unit = String::new();
    let mut at_unit = false;
    for ch in s.chars() {
        if ch.is_ascii_digit() || ch == '.' || ch == ',' { num.push(if ch == ',' { '.' } else { ch }); }
        else { at_unit = true; }
        if at_unit && !ch.is_whitespace() { unit.push(ch); }
    }
    let val: f64 = num.parse().unwrap_or(0.0);
    let mult = match unit.trim().to_ascii_uppercase().as_str() {
        "B" => 1.0,
        "KB" | "K" => 1000.0,
        "MB" | "M" => 1000.0 * 1000.0,
        "GB" | "G" => 1000.0_f64.powi(3),
        "KIB" => 1024.0,
        "MIB" => 1024.0 * 1024.0,
        "GIB" => 1024.0_f64.powi(3),
        _ => 1.0,
    };
    (val * mult) as u64
}

fn which(bin: &str) -> bool {
    Command::new("which").arg(bin)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}
