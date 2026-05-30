//! User-facing settings: language, autostart, close behavior.
//!
//! Persisted to `<config_dir>/lume/settings.json`. Each field has a sensible
//! default so missing keys never break the app.

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum Language {
    Pt,
    En,
}
impl Default for Language {
    fn default() -> Self { Self::Pt }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Settings {
    pub language: Language,
    /// When true, closing the window hides to tray. When false, it really
    /// quits the app — `LumeAppDelegate` style.
    pub close_to_tray: bool,
    /// Start the app minimized to the tray on system boot (only meaningful
    /// if autostart is also on).
    pub start_minimized: bool,
}
impl Default for Settings {
    fn default() -> Self {
        Self {
            language: Language::Pt,
            close_to_tray: true,
            start_minimized: false,
        }
    }
}

fn state_path() -> Option<PathBuf> {
    dirs::config_dir().map(|p| p.join("lume").join("settings.json"))
}

pub fn load() -> Settings {
    state_path()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

pub fn save(settings: &Settings) -> std::io::Result<()> {
    let p = state_path()
        .ok_or_else(|| std::io::Error::new(std::io::ErrorKind::NotFound, "no config dir"))?;
    if let Some(parent) = p.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let json = serde_json::to_string_pretty(settings).unwrap_or_else(|_| "{}".into());
    std::fs::write(p, json)
}

#[derive(Debug, Clone, Serialize)]
pub struct AppInfo {
    pub version: String,
    pub repo_url: String,
    pub homepage: String,
    pub license: String,
}

pub fn app_info() -> AppInfo {
    AppInfo {
        version: env!("CARGO_PKG_VERSION").to_string(),
        repo_url: "https://github.com/hasencleverw/get-lume-app".into(),
        homepage: "https://getlu.me".into(),
        license: "Elastic License 2.0".into(),
    }
}
