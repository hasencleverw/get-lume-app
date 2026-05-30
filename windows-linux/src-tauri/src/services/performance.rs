//! Performance / maintenance tasks. Mirrors the macOS PerformanceView surface.
//!
//! Each task is small, idempotent, and reports back a one-line outcome that
//! the UI surfaces verbatim. Privileged tasks go through pkexec on Linux.

use anyhow::{anyhow, Context, Result};
use serde::Serialize;
use std::path::PathBuf;
use std::process::Command;

#[derive(Debug, Clone, Serialize)]
pub struct TaskOutcome {
    pub ok: bool,
    pub message: String,
}

impl TaskOutcome {
    fn ok<S: Into<String>>(msg: S) -> Self { Self { ok: true, message: msg.into() } }
    fn err<S: Into<String>>(msg: S) -> Self { Self { ok: false, message: msg.into() } }
}

#[derive(Debug, Clone, Serialize)]
pub struct StartupItem {
    pub name: String,
    pub exec: String,
    pub source: String, // user | system
    pub path: PathBuf,
    pub enabled: bool,
}

// --- DNS -------------------------------------------------------------------

#[cfg(target_os = "linux")]
pub fn flush_dns() -> TaskOutcome {
    if which("resolvectl") {
        let r = Command::new("pkexec").args(["resolvectl", "flush-caches"]).status();
        return match r {
            Ok(s) if s.success() => TaskOutcome::ok("Cache do systemd-resolved limpo"),
            Ok(s) => TaskOutcome::err(format!("resolvectl saiu com código {:?}", s.code())),
            Err(e) => TaskOutcome::err(e.to_string()),
        };
    }
    if which("nscd") {
        let r = Command::new("pkexec").args(["systemctl", "restart", "nscd"]).status();
        return match r {
            Ok(s) if s.success() => TaskOutcome::ok("nscd reiniciado"),
            Ok(s) => TaskOutcome::err(format!("systemctl saiu com código {:?}", s.code())),
            Err(e) => TaskOutcome::err(e.to_string()),
        };
    }
    TaskOutcome::err("Nenhum resolver DNS suportado encontrado")
}

#[cfg(target_os = "windows")]
pub fn flush_dns() -> TaskOutcome {
    let r = Command::new("ipconfig").arg("/flushdns").status();
    match r {
        Ok(s) if s.success() => TaskOutcome::ok("Cache DNS limpo"),
        Ok(s) => TaskOutcome::err(format!("ipconfig saiu com código {:?}", s.code())),
        Err(e) => TaskOutcome::err(e.to_string()),
    }
}

/// Elevate via the `runas` crate which calls `ShellExecuteExW` with verb
/// `runas` under the hood — the native Win32 mechanism for UAC. We
/// deliberately avoid PowerShell wrappers because that pattern (`powershell
/// + Start-Process + Hidden`) is heavily flagged by Defender heuristics on
/// unsigned binaries.
#[cfg(target_os = "windows")]
fn elevate(exe: &str, args: &[&str]) -> Result<(), String> {
    let mut cmd = runas::Command::new(exe);
    for a in args { cmd.arg(a); }
    // `gui(true)` runs the elevated child without spawning a visible cmd
    // window — but unlike PowerShell's `-WindowStyle Hidden`, this maps to
    // the standard `SW_HIDE` ShellExecute flag, not a flagged pattern.
    cmd.gui(true);
    match cmd.status() {
        Ok(s) if s.success() => Ok(()),
        Ok(s) => Err(format!("comando saiu com código {:?}", s.code())),
        Err(e) => Err(format!("autorização negada ou falha ao elevar: {e}")),
    }
}

#[cfg(target_os = "windows")]
pub fn restart_search_index() -> TaskOutcome {
    // cmd.exe with `&` runs both regardless of the first result — tolerates
    // service already stopped without throwing.
    match elevate("cmd.exe", &["/c", "net stop WSearch & net start WSearch"]) {
        Ok(_) => TaskOutcome::ok("Windows Search reiniciado"),
        Err(e) => TaskOutcome::err(e),
    }
}

#[cfg(target_os = "windows")]
pub fn disk_cleanup() -> TaskOutcome {
    // Opens the legacy Limpeza de Disco dialog. Modern Windows preferred path
    // is Storage Sense, but cleanmgr still works on every supported version.
    match Command::new("cleanmgr").arg("/sagerun:1").spawn() {
        Ok(_) => TaskOutcome::ok("Limpeza de Disco iniciada (verifique a janela aberta)"),
        Err(e) => TaskOutcome::err(format!("Falha ao abrir cleanmgr: {e}")),
    }
}

// --- Font cache ------------------------------------------------------------

#[cfg(target_os = "linux")]
pub fn rebuild_font_cache() -> TaskOutcome {
    let home = match dirs::home_dir() {
        Some(h) => h,
        None => return TaskOutcome::err("Sem HOME"),
    };
    let fc_dir = home.join(".cache/fontconfig");
    if fc_dir.exists() {
        let _ = std::fs::remove_dir_all(&fc_dir);
    }
    match Command::new("fc-cache").args(["-fv"]).output() {
        Ok(o) if o.status.success() => TaskOutcome::ok("Cache de fontes reconstruído"),
        Ok(o) => TaskOutcome::err(format!("fc-cache falhou: {}", String::from_utf8_lossy(&o.stderr))),
        Err(e) => TaskOutcome::err(e.to_string()),
    }
}

#[cfg(target_os = "windows")]
pub fn rebuild_font_cache() -> TaskOutcome {
    match elevate("cmd.exe", &["/c", "net stop FontCache & net start FontCache"]) {
        Ok(_) => TaskOutcome::ok("Serviço Font Cache reiniciado"),
        Err(e) => TaskOutcome::err(e),
    }
}

// --- Trash empty -----------------------------------------------------------

pub fn empty_trash() -> TaskOutcome {
    #[cfg(target_os = "linux")]
    {
        let Some(home) = dirs::home_dir() else { return TaskOutcome::err("Sem HOME") };
        let trash_files = home.join(".local/share/Trash/files");
        let trash_info = home.join(".local/share/Trash/info");
        let (mut count, mut bytes) = (0usize, 0u64);
        for dir in [trash_files.clone(), trash_info.clone()] {
            if let Ok(rd) = std::fs::read_dir(&dir) {
                for e in rd.flatten() {
                    let p = e.path();
                    let size = walkdir::WalkDir::new(&p)
                        .into_iter()
                        .filter_map(|x| x.ok())
                        .filter_map(|x| x.metadata().ok())
                        .filter(|m| m.is_file())
                        .map(|m| m.len())
                        .sum::<u64>();
                    if p.is_dir() {
                        let _ = std::fs::remove_dir_all(&p);
                    } else {
                        let _ = std::fs::remove_file(&p);
                    }
                    if dir == trash_files {
                        count += 1;
                        bytes += size;
                    }
                }
            }
        }
        TaskOutcome::ok(format!("Lixeira esvaziada — {} itens, {}", count, fmt_bytes(bytes)))
    }
    #[cfg(target_os = "windows")]
    {
        use windows::core::PCWSTR;
        use windows::Win32::UI::Shell::{
            SHEmptyRecycleBinW, SHERB_NOCONFIRMATION, SHERB_NOPROGRESSUI, SHERB_NOSOUND,
        };

        let flags = SHERB_NOCONFIRMATION | SHERB_NOPROGRESSUI | SHERB_NOSOUND;
        // Safety: passing NULL for window handle and path is supported and means
        // "all drives, no UI parent". Returns S_OK on success, S_FALSE when the
        // bin is empty, and various error HRESULTs otherwise.
        let result = unsafe { SHEmptyRecycleBinW(None, PCWSTR::null(), flags) };
        match result {
            Ok(_) => TaskOutcome::ok("Lixeira esvaziada"),
            Err(e) if e.code().0 == 1 => TaskOutcome::ok("Lixeira já estava vazia"),
            Err(e) => TaskOutcome::err(format!("HRESULT 0x{:08X}", e.code().0)),
        }
    }
}

// --- KDE Baloo (file indexer) ---------------------------------------------

#[cfg(target_os = "linux")]
pub fn reset_baloo() -> TaskOutcome {
    if !which("balooctl6") && !which("balooctl") {
        return TaskOutcome::err("balooctl não encontrado (apenas para KDE Plasma)");
    }
    let tool = if which("balooctl6") { "balooctl6" } else { "balooctl" };
    let _ = Command::new(tool).arg("disable").status();
    if let Some(home) = dirs::home_dir() {
        let _ = std::fs::remove_dir_all(home.join(".local/share/baloo"));
    }
    let r = Command::new(tool).arg("enable").status();
    match r {
        Ok(s) if s.success() => TaskOutcome::ok("Índice Baloo (KDE) reiniciado"),
        _ => TaskOutcome::err("Falha ao re-habilitar Baloo"),
    }
}

#[cfg(target_os = "windows")]
pub fn reset_baloo() -> TaskOutcome { TaskOutcome::err("KDE-only") }

// --- pacman cache (Arch family) -------------------------------------------

#[cfg(target_os = "linux")]
pub fn clean_package_cache() -> TaskOutcome {
    if which("pacman") {
        let r = Command::new("pkexec").args(["pacman", "-Sc", "--noconfirm"]).status();
        return match r {
            Ok(s) if s.success() => TaskOutcome::ok("Cache do pacman limpo"),
            Ok(s) => TaskOutcome::err(format!("pacman saiu com código {:?}", s.code())),
            Err(e) => TaskOutcome::err(e.to_string()),
        };
    }
    if which("apt-get") {
        let r = Command::new("pkexec").args(["apt-get", "clean"]).status();
        return match r {
            Ok(s) if s.success() => TaskOutcome::ok("Cache do apt limpo"),
            Ok(s) => TaskOutcome::err(format!("apt-get saiu com código {:?}", s.code())),
            Err(e) => TaskOutcome::err(e.to_string()),
        };
    }
    if which("dnf") {
        let r = Command::new("pkexec").args(["dnf", "clean", "all"]).status();
        return match r {
            Ok(s) if s.success() => TaskOutcome::ok("Cache do dnf limpo"),
            Ok(s) => TaskOutcome::err(format!("dnf saiu com código {:?}", s.code())),
            Err(e) => TaskOutcome::err(e.to_string()),
        };
    }
    TaskOutcome::err("Nenhum gerenciador de pacotes suportado")
}

#[cfg(target_os = "windows")]
pub fn clean_package_cache() -> TaskOutcome { TaskOutcome::err("Não aplicável") }

// --- Journal vacuum (systemd) ---------------------------------------------

#[cfg(target_os = "linux")]
pub fn vacuum_journal() -> TaskOutcome {
    if !which("journalctl") {
        return TaskOutcome::err("journalctl não encontrado");
    }
    let r = Command::new("pkexec").args(["journalctl", "--vacuum-time=7d"]).status();
    match r {
        Ok(s) if s.success() => TaskOutcome::ok("Journal compactado para últimos 7 dias"),
        Ok(s) => TaskOutcome::err(format!("journalctl saiu com código {:?}", s.code())),
        Err(e) => TaskOutcome::err(e.to_string()),
    }
}

#[cfg(target_os = "windows")]
pub fn vacuum_journal() -> TaskOutcome { TaskOutcome::err("Não aplicável") }

// --- Startup items --------------------------------------------------------

#[cfg(target_os = "linux")]
pub fn list_startup() -> Vec<StartupItem> {
    let mut out = Vec::new();
    let user_dir = dirs::config_dir().map(|p| p.join("autostart"));
    let system_dirs = ["/etc/xdg/autostart"].iter().map(PathBuf::from).collect::<Vec<_>>();

    let mut sources: Vec<(PathBuf, &'static str)> = Vec::new();
    if let Some(u) = user_dir { sources.push((u, "user")); }
    for s in system_dirs { sources.push((s, "system")); }

    for (dir, src) in sources {
        let Ok(rd) = std::fs::read_dir(&dir) else { continue };
        for e in rd.flatten() {
            let path = e.path();
            if path.extension().and_then(|s| s.to_str()) != Some("desktop") {
                continue;
            }
            let Ok(text) = std::fs::read_to_string(&path) else { continue };
            let mut name = String::new();
            let mut exec = String::new();
            let mut hidden = false;
            for line in text.lines() {
                if let Some(v) = line.strip_prefix("Name=") { if name.is_empty() { name = v.into(); } }
                else if let Some(v) = line.strip_prefix("Exec=") { if exec.is_empty() { exec = v.into(); } }
                else if line.starts_with("Hidden=true") { hidden = true; }
                else if line.starts_with("X-GNOME-Autostart-enabled=false") { hidden = true; }
            }
            if name.is_empty() { continue; }
            out.push(StartupItem {
                name,
                exec,
                source: src.into(),
                path,
                enabled: !hidden,
            });
        }
    }
    out.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    out
}

#[cfg(target_os = "windows")]
pub fn list_startup() -> Vec<StartupItem> { Vec::new() }

#[cfg(target_os = "linux")]
pub fn toggle_startup(path: PathBuf, enable: bool) -> Result<()> {
    let text = std::fs::read_to_string(&path).with_context(|| format!("read {}", path.display()))?;
    let mut lines: Vec<String> = text.lines().map(|s| s.to_string()).collect();
    let mut found = false;
    for l in &mut lines {
        if l.starts_with("Hidden=") {
            *l = format!("Hidden={}", if enable { "false" } else { "true" });
            found = true;
        }
    }
    if !found {
        lines.push(format!("Hidden={}", if enable { "false" } else { "true" }));
    }

    // User-owned file: edit directly. System-owned: copy to user autostart then mask.
    let writable = path.starts_with(dirs::config_dir().unwrap_or_default());
    if writable {
        std::fs::write(&path, lines.join("\n") + "\n")?;
    } else {
        let user_dir = dirs::config_dir().ok_or_else(|| anyhow!("no config dir"))?.join("autostart");
        std::fs::create_dir_all(&user_dir)?;
        let dest = user_dir.join(path.file_name().ok_or_else(|| anyhow!("bad filename"))?);
        std::fs::write(&dest, lines.join("\n") + "\n")?;
    }
    Ok(())
}

#[cfg(target_os = "windows")]
pub fn toggle_startup(_path: PathBuf, _enable: bool) -> Result<()> {
    Err(anyhow!("não implementado"))
}

// --- helpers ---------------------------------------------------------------

fn which(bin: &str) -> bool {
    Command::new("which").arg(bin)
        .stdout(std::process::Stdio::null())
        .stderr(std::process::Stdio::null())
        .status()
        .map(|s| s.success())
        .unwrap_or(false)
}

fn fmt_bytes(b: u64) -> String {
    const UNITS: &[&str] = &["B", "KB", "MB", "GB", "TB"];
    let mut v = b as f64;
    let mut i = 0;
    while v >= 1024.0 && i < UNITS.len() - 1 { v /= 1024.0; i += 1; }
    if i == 0 { format!("{} {}", b, UNITS[0]) } else { format!("{:.1} {}", v, UNITS[i]) }
}
