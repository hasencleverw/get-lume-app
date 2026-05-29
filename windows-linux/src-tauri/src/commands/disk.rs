use crate::services::disk_scanner::{self, Category, JunkEntry, ScanReport};

#[tauri::command]
pub async fn scan_junk(categories: Vec<Category>) -> Result<ScanReport, String> {
    let categories = categories;
    tokio::task::spawn_blocking(move || disk_scanner::scan(&categories))
        .await
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub async fn clean_categories(entries: Vec<JunkEntry>) -> Result<u64, String> {
    tokio::task::spawn_blocking(move || disk_scanner::clean(&entries))
        .await
        .map_err(|e| e.to_string())?
        .map_err(|e| e.to_string())
}
