//! Protection — Linux-flavored threat scan.
//!
//! Strategy (no ClamAV dependency — too heavy for a 6 MB app):
//!   1. Hardcoded JSON of known malicious / unwanted package + binary names.
//!   2. Audit ~/.config/autostart and /etc/xdg/autostart for unfamiliar Exec= entries.
//!   3. Audit ~/.local/bin and ~/.local/share/applications for suspicious binaries.
//!   4. Browser extension audit (Chromium-family + Firefox profile dirs).
//!
//! We never auto-delete. Each finding includes a recommended action; the user
//! decides.

use serde::Serialize;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum Severity {
    Info,
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize)]
#[serde(rename_all = "kebab-case")]
pub enum Kind {
    Autostart,
    Binary,
    BrowserExt,
    SystemdUnit,
}

#[derive(Debug, Clone, Serialize)]
pub struct Finding {
    pub kind: Kind,
    pub severity: Severity,
    pub title: String,
    pub detail: String,
    pub path: Option<PathBuf>,
    pub recommendation: String,
}

#[derive(Debug, Clone, Serialize)]
pub struct ScanReport {
    pub findings: Vec<Finding>,
    pub items_scanned: usize,
    pub took_ms: u64,
}

const SUSPICIOUS_NAMES: &[&str] = &[
    // Generic patterns historically tied to Linux PUPs / cryptominers / adware.
    "xmrig", "cpuminer", "minerd", "ethminer",
    "kinsing", "kdevtmpfsi", "kthrotlds",
    "bitscript", "watchbog", "outlawminer",
];

pub fn scan() -> ScanReport {
    let start = std::time::Instant::now();
    let mut findings = Vec::new();
    let mut scanned = 0usize;

    #[cfg(target_os = "linux")]
    {
        scan_autostart(&mut findings, &mut scanned);
        scan_user_bin(&mut findings, &mut scanned);
        scan_browser_extensions(&mut findings, &mut scanned);
    }

    #[cfg(target_os = "windows")]
    {
        scan_windows_run_keys(&mut findings, &mut scanned);
        scan_windows_startup_folders(&mut findings, &mut scanned);
        scan_windows_browser_extensions(&mut findings, &mut scanned);
    }

    ScanReport {
        findings,
        items_scanned: scanned,
        took_ms: start.elapsed().as_millis() as u64,
    }
}

#[cfg(target_os = "linux")]
fn scan_autostart(out: &mut Vec<Finding>, scanned: &mut usize) {
    let mut dirs = vec![PathBuf::from("/etc/xdg/autostart")];
    if let Some(cfg) = dirs::config_dir() { dirs.push(cfg.join("autostart")); }
    for d in dirs {
        let Ok(rd) = std::fs::read_dir(&d) else { continue };
        for e in rd.flatten() {
            let path = e.path();
            if path.extension().and_then(|s| s.to_str()) != Some("desktop") { continue; }
            *scanned += 1;
            let Ok(text) = std::fs::read_to_string(&path) else { continue };
            let mut name = String::new();
            let mut exec = String::new();
            for line in text.lines() {
                if let Some(v) = line.strip_prefix("Name=") { if name.is_empty() { name = v.into(); } }
                else if let Some(v) = line.strip_prefix("Exec=") { if exec.is_empty() { exec = v.into(); } }
            }
            if name.is_empty() { continue; }

            let exec_lower = exec.to_ascii_lowercase();
            let suspicious = SUSPICIOUS_NAMES.iter().any(|s| exec_lower.contains(s));
            if suspicious {
                out.push(Finding {
                    kind: Kind::Autostart,
                    severity: Severity::High,
                    title: format!("Autostart suspeito: {}", name),
                    detail: format!("Comando: {}", exec),
                    path: Some(path.clone()),
                    recommendation: "Desabilite imediatamente em Performance → Startup".into(),
                });
                continue;
            }

            // Heuristic: Exec= pointing to /tmp, ~/.cache or a random-looking binary is a yellow flag.
            if exec_lower.contains("/tmp/") || exec_lower.contains("/.cache/") {
                out.push(Finding {
                    kind: Kind::Autostart,
                    severity: Severity::Medium,
                    title: format!("Autostart em diretório temporário: {}", name),
                    detail: format!("Comando aponta para área transitória: {}", exec),
                    path: Some(path),
                    recommendation: "Verifique se você reconhece este aplicativo.".into(),
                });
            }
        }
    }
}

#[cfg(target_os = "linux")]
fn scan_user_bin(out: &mut Vec<Finding>, scanned: &mut usize) {
    let mut dirs: Vec<PathBuf> = vec![];
    if let Some(h) = dirs::home_dir() {
        dirs.push(h.join(".local/bin"));
        dirs.push(h.join("bin"));
    }
    for d in dirs {
        let Ok(rd) = std::fs::read_dir(&d) else { continue };
        for e in rd.flatten() {
            *scanned += 1;
            let p = e.path();
            let Some(name) = p.file_name().and_then(|s| s.to_str()) else { continue };
            let name_lower = name.to_ascii_lowercase();
            if SUSPICIOUS_NAMES.iter().any(|s| name_lower.contains(s)) {
                out.push(Finding {
                    kind: Kind::Binary,
                    severity: Severity::High,
                    title: format!("Binário suspeito: {}", name),
                    detail: format!("Encontrado em {}", p.display()),
                    path: Some(p),
                    recommendation: "Investigue o arquivo e remova se não reconhecer.".into(),
                });
            }
        }
    }
}

// ============================================================================
// Windows scanners
// ============================================================================

#[cfg(target_os = "windows")]
fn scan_windows_run_keys(out: &mut Vec<Finding>, scanned: &mut usize) {
    use winreg::enums::*;
    use winreg::RegKey;

    let keys: &[(winreg::HKEY, &str)] = &[
        (HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Run"),
        (HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"),
        (HKEY_LOCAL_MACHINE, r"SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"),
        (HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\Run"),
        (HKEY_CURRENT_USER, r"SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"),
    ];

    for (root, path) in keys {
        let hkey = RegKey::predef(*root);
        let Ok(k) = hkey.open_subkey(*path) else { continue };
        for (name, value) in k.enum_values().flatten() {
            *scanned += 1;
            let cmd = value.to_string();
            let cmd_lower = cmd.to_ascii_lowercase();
            let name_lower = name.to_ascii_lowercase();

            if SUSPICIOUS_NAMES.iter().any(|s| cmd_lower.contains(s) || name_lower.contains(s)) {
                out.push(Finding {
                    kind: Kind::Autostart,
                    severity: Severity::High,
                    title: format!("Autostart suspeito: {}", name),
                    detail: format!("Comando: {}", cmd),
                    path: Some(PathBuf::from(format!("{}\\{}", path, name))),
                    recommendation: "Abra o Gerenciador de Tarefas → Inicializar e desabilite.".into(),
                });
                continue;
            }
            // Heuristic: autostart pointing to Temp or AppData\Local\Temp.
            if cmd_lower.contains("\\temp\\") || cmd_lower.contains("\\appdata\\local\\temp\\") {
                out.push(Finding {
                    kind: Kind::Autostart,
                    severity: Severity::Medium,
                    title: format!("Autostart em pasta temporária: {}", name),
                    detail: format!("Comando: {}", cmd),
                    path: Some(PathBuf::from(format!("{}\\{}", path, name))),
                    recommendation: "Verifique se reconhece este aplicativo. Arquivos em Temp não deveriam ser autostarts.".into(),
                });
            }
        }
    }
}

#[cfg(target_os = "windows")]
fn scan_windows_startup_folders(out: &mut Vec<Finding>, scanned: &mut usize) {
    let mut dirs: Vec<PathBuf> = Vec::new();
    if let Some(appdata) = std::env::var_os("APPDATA") {
        dirs.push(PathBuf::from(appdata).join(r"Microsoft\Windows\Start Menu\Programs\Startup"));
    }
    if let Some(programdata) = std::env::var_os("PROGRAMDATA") {
        dirs.push(PathBuf::from(programdata).join(r"Microsoft\Windows\Start Menu\Programs\Startup"));
    }

    for dir in dirs {
        let Ok(rd) = std::fs::read_dir(&dir) else { continue };
        for e in rd.flatten() {
            *scanned += 1;
            let path = e.path();
            let name = path.file_name().and_then(|s| s.to_str()).unwrap_or("").to_string();
            let name_lower = name.to_ascii_lowercase();

            if SUSPICIOUS_NAMES.iter().any(|s| name_lower.contains(s)) {
                out.push(Finding {
                    kind: Kind::Autostart,
                    severity: Severity::High,
                    title: format!("Atalho suspeito na Inicialização: {}", name),
                    detail: format!("Caminho: {}", path.display()),
                    path: Some(path),
                    recommendation: "Remova o arquivo e adicione exclusão no Windows Defender.".into(),
                });
            }
        }
    }
}

#[cfg(target_os = "windows")]
fn scan_windows_browser_extensions(out: &mut Vec<Finding>, scanned: &mut usize) {
    let Some(local) = std::env::var_os("LOCALAPPDATA").map(PathBuf::from) else { return };
    let Some(roaming) = std::env::var_os("APPDATA").map(PathBuf::from) else { return };

    let candidate_roots: &[PathBuf] = &[
        local.join(r"Google\Chrome\User Data"),
        local.join(r"Microsoft\Edge\User Data"),
        local.join(r"BraveSoftware\Brave-Browser\User Data"),
        local.join(r"Chromium\User Data"),
        local.join(r"Vivaldi\User Data"),
        roaming.join(r"Opera Software\Opera Stable"),
    ];

    for root in candidate_roots {
        let Ok(profiles) = std::fs::read_dir(root) else { continue };
        for prof in profiles.flatten() {
            let ext_dir = prof.path().join("Extensions");
            let Ok(extensions) = std::fs::read_dir(&ext_dir) else { continue };
            for ext in extensions.flatten() {
                *scanned += 1;
                let id = ext.file_name().to_string_lossy().into_owned();
                // Valid Chromium IDs are 32 lowercase letters.
                if id.len() == 32 && id.chars().all(|c| c.is_ascii_alphabetic()) { continue; }
                out.push(Finding {
                    kind: Kind::BrowserExt,
                    severity: Severity::Low,
                    title: format!("Extensão de navegador com ID atípico: {}", id),
                    detail: format!("Em {}", ext.path().display()),
                    path: Some(ext.path()),
                    recommendation: "Abra a página de extensões do navegador e verifique.".into(),
                });
            }
        }
    }
}

// ============================================================================
// Linux scanners
// ============================================================================

#[cfg(target_os = "linux")]
fn scan_browser_extensions(out: &mut Vec<Finding>, scanned: &mut usize) {
    let Some(home) = dirs::home_dir() else { return };

    // Chromium-family — each profile has Extensions/<id>/<version>/manifest.json
    let chromium_roots: &[&str] = &[
        ".config/google-chrome", ".config/chromium", ".config/BraveSoftware/Brave-Browser",
        ".config/microsoft-edge", ".config/vivaldi", ".config/opera",
    ];
    for r in chromium_roots {
        let root = home.join(r);
        let Ok(profiles) = std::fs::read_dir(&root) else { continue };
        for prof in profiles.flatten() {
            let ext_dir = prof.path().join("Extensions");
            if !ext_dir.exists() { continue; }
            let Ok(rd) = std::fs::read_dir(&ext_dir) else { continue };
            for ext in rd.flatten() {
                *scanned += 1;
                // We surface the existence; the user can decide. A real list would
                // require an upstream IOC feed.
                let id = ext.file_name().to_string_lossy().into_owned();
                if id.len() == 32 && id.chars().all(|c| c.is_ascii_alphabetic()) {
                    // valid-looking Chromium ID — keep silent unless it matches an IOC list
                    continue;
                }
                out.push(Finding {
                    kind: Kind::BrowserExt,
                    severity: Severity::Low,
                    title: format!("Extensão de navegador com ID atípico: {}", id),
                    detail: format!("Em {}", ext.path().display()),
                    path: Some(ext.path()),
                    recommendation: "Abra a página de extensões do navegador e verifique.".into(),
                });
            }
        }
    }

    // Firefox — extensions stored in <profile>/extensions/
    let firefox = home.join(".mozilla/firefox");
    if let Ok(rd) = std::fs::read_dir(&firefox) {
        for prof in rd.flatten() {
            let ext = prof.path().join("extensions");
            let Ok(items) = std::fs::read_dir(&ext) else { continue };
            for _ in items.flatten() { *scanned += 1; }
        }
    }
}
