use crate::platform::host;
use crate::services::settings::{self, AppInfo, Settings};

#[tauri::command]
pub fn settings_get() -> Settings {
    settings::load()
}

#[tauri::command]
pub fn settings_set(settings: Settings) -> Result<Settings, String> {
    settings::save(&settings).map_err(|e| e.to_string())?;
    Ok(settings)
}

#[tauri::command]
pub fn settings_app_info() -> AppInfo {
    settings::app_info()
}

#[tauri::command]
pub fn settings_autostart_enabled() -> bool {
    host::is_autostart_enabled()
}

#[tauri::command]
pub fn settings_set_autostart(enabled: bool) -> Result<bool, String> {
    host::set_autostart(enabled).map_err(|e| e.to_string())?;
    Ok(host::is_autostart_enabled())
}
