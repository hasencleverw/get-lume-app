use crate::services::updater::{self, UpdateDisplay};

/// Cached snapshot — instant, never hits network. Use this on every boot.
#[tauri::command]
pub fn updater_status() -> UpdateDisplay {
    updater::display_from_state(&updater::load_state())
}

/// Whether the next boot trigger should ping GitHub (≥ 7 days since last check).
#[tauri::command]
pub fn updater_should_check() -> bool {
    updater::should_check(&updater::load_state())
}

/// Hits the GitHub API and refreshes cached state. Non-fatal on failure.
#[tauri::command]
pub async fn updater_check_now() -> Result<UpdateDisplay, String> {
    updater::check_now().await.map_err(|e| e.to_string())
}
