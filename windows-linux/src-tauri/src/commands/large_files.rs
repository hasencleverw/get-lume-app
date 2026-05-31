use crate::services::large_files::{self, BigFile, FileKind};
use std::path::PathBuf;

#[tauri::command]
pub async fn scan_largest(
    root: Option<PathBuf>,
    limit: Option<usize>,
    kinds: Option<Vec<FileKind>>,
    min_size_mb: Option<u64>,
) -> Vec<BigFile> {
    let root = root.or_else(dirs::home_dir).unwrap_or_else(|| PathBuf::from("/"));
    let limit = limit.unwrap_or(100);
    let kinds = kinds.unwrap_or_default();
    let min_size_bytes = min_size_mb.unwrap_or(1) * 1024 * 1024;
    tokio::task::spawn_blocking(move || large_files::scan_largest(&root, limit, &kinds, min_size_bytes))
        .await
        .unwrap_or_default()
}
