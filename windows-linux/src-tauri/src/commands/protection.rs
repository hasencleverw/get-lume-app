use crate::services::protection::{self, ScanReport};

#[tauri::command]
pub async fn protection_scan() -> ScanReport {
    tokio::task::spawn_blocking(protection::scan).await.unwrap_or(ScanReport {
        findings: vec![], items_scanned: 0, took_ms: 0,
    })
}
