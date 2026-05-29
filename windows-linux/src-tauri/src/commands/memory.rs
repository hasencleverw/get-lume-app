use crate::services::memory_cleaner::{self, MemoryCleanResult};

#[tauri::command]
pub async fn free_memory() -> Result<MemoryCleanResult, String> {
    tokio::task::spawn_blocking(memory_cleaner::free_memory)
        .await
        .map_err(|e| e.to_string())?
        .map_err(|e| e.to_string())
}
