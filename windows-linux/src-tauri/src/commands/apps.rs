use crate::services::app_manager::{self, AppEntry, AppSource};

#[tauri::command]
pub async fn list_apps() -> Vec<AppEntry> {
    tokio::task::spawn_blocking(app_manager::list_apps).await.unwrap_or_default()
}

#[tauri::command]
pub async fn uninstall_app(source: AppSource, id: String) -> Result<(), String> {
    tokio::task::spawn_blocking(move || app_manager::uninstall(source, &id))
        .await
        .map_err(|e| e.to_string())?
        .map_err(|e| e.to_string())
}
