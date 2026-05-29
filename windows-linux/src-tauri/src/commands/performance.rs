use crate::services::performance::{self, StartupItem, TaskOutcome};
use std::path::PathBuf;

#[tauri::command]
pub async fn perf_flush_dns() -> TaskOutcome {
    tokio::task::spawn_blocking(performance::flush_dns).await.unwrap_or(TaskOutcome { ok: false, message: "task panic".into() })
}

#[tauri::command]
pub async fn perf_rebuild_font_cache() -> TaskOutcome {
    tokio::task::spawn_blocking(performance::rebuild_font_cache).await.unwrap_or(TaskOutcome { ok: false, message: "task panic".into() })
}

#[tauri::command]
pub async fn perf_empty_trash() -> TaskOutcome {
    tokio::task::spawn_blocking(performance::empty_trash).await.unwrap_or(TaskOutcome { ok: false, message: "task panic".into() })
}

#[tauri::command]
pub async fn perf_reset_baloo() -> TaskOutcome {
    tokio::task::spawn_blocking(performance::reset_baloo).await.unwrap_or(TaskOutcome { ok: false, message: "task panic".into() })
}

#[tauri::command]
pub async fn perf_clean_package_cache() -> TaskOutcome {
    tokio::task::spawn_blocking(performance::clean_package_cache).await.unwrap_or(TaskOutcome { ok: false, message: "task panic".into() })
}

#[tauri::command]
pub async fn perf_vacuum_journal() -> TaskOutcome {
    tokio::task::spawn_blocking(performance::vacuum_journal).await.unwrap_or(TaskOutcome { ok: false, message: "task panic".into() })
}

#[cfg(target_os = "windows")]
#[tauri::command]
pub async fn perf_restart_search_index() -> TaskOutcome {
    tokio::task::spawn_blocking(performance::restart_search_index).await.unwrap_or(TaskOutcome { ok: false, message: "task panic".into() })
}
#[cfg(not(target_os = "windows"))]
#[tauri::command]
pub async fn perf_restart_search_index() -> TaskOutcome {
    TaskOutcome { ok: false, message: "Windows-only".into() }
}

#[cfg(target_os = "windows")]
#[tauri::command]
pub async fn perf_disk_cleanup() -> TaskOutcome {
    tokio::task::spawn_blocking(performance::disk_cleanup).await.unwrap_or(TaskOutcome { ok: false, message: "task panic".into() })
}
#[cfg(not(target_os = "windows"))]
#[tauri::command]
pub async fn perf_disk_cleanup() -> TaskOutcome {
    TaskOutcome { ok: false, message: "Windows-only".into() }
}

#[tauri::command]
pub async fn perf_list_startup() -> Vec<StartupItem> {
    tokio::task::spawn_blocking(performance::list_startup).await.unwrap_or_default()
}

#[tauri::command]
pub async fn perf_toggle_startup(path: PathBuf, enable: bool) -> Result<(), String> {
    tokio::task::spawn_blocking(move || performance::toggle_startup(path, enable))
        .await
        .map_err(|e| e.to_string())?
        .map_err(|e| e.to_string())
}
