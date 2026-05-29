use crate::services::large_files::{self, BigFile, FileKind};
use std::path::PathBuf;

#[tauri::command]
pub async fn scan_largest(root: Option<PathBuf>, limit: Option<usize>, kinds: Option<Vec<FileKind>>) -> Vec<BigFile> {
    let root = root.or_else(dirs::home_dir).unwrap_or_else(|| PathBuf::from("/"));
    let limit = limit.unwrap_or(100);
    let kinds = kinds.unwrap_or_default();
    tokio::task::spawn_blocking(move || large_files::scan_largest(&root, limit, &kinds))
        .await
        .unwrap_or_default()
}
