//! Space Lens — walk a tree and surface the largest files.
//!
//! Single-threaded walkdir is fast enough on SSDs (millions of inodes/sec).
//! We bound the result heap so memory stays flat even on huge trees.

use serde::Serialize;
use std::collections::BinaryHeap;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "kebab-case")]
pub enum FileKind {
    Video,
    Audio,
    Image,
    Archive,
    Document,
    Code,
    Binary,
    Other,
}

impl FileKind {
    pub fn classify(path: &Path) -> Self {
        let Some(ext) = path.extension().and_then(|s| s.to_str()).map(|s| s.to_ascii_lowercase()) else {
            return Self::Other;
        };
        match ext.as_str() {
            "mp4" | "mkv" | "mov" | "avi" | "webm" | "flv" | "wmv" | "m4v" => Self::Video,
            "mp3" | "wav" | "flac" | "ogg" | "m4a" | "opus" | "aac" => Self::Audio,
            "jpg" | "jpeg" | "png" | "gif" | "webp" | "tiff" | "tif" | "bmp" | "heic" | "raw" | "svg" => Self::Image,
            "zip" | "tar" | "gz" | "bz2" | "xz" | "zst" | "7z" | "rar" | "tgz" | "tbz" => Self::Archive,
            "pdf" | "doc" | "docx" | "xls" | "xlsx" | "ppt" | "pptx" | "odt" | "ods" | "epub" | "txt" | "md" => Self::Document,
            "rs" | "ts" | "tsx" | "js" | "jsx" | "py" | "go" | "swift" | "java" | "kt" | "rb" | "c" | "cpp" | "h" | "hpp" | "cs" | "php" => Self::Code,
            "iso" | "img" | "dmg" | "exe" | "msi" | "deb" | "rpm" | "appimage" | "dll" | "so" | "dylib" => Self::Binary,
            _ => Self::Other,
        }
    }
}

#[derive(Debug, Clone, Serialize)]
pub struct BigFile {
    pub path: PathBuf,
    pub size: u64,
    pub kind: FileKind,
    pub modified_secs: i64, // unix epoch; 0 if unknown
}

// BinaryHeap is a max-heap; we want the N largest so we store inverted-by-size
// to make it a min-heap that pops smallest first.
#[derive(Eq, PartialEq)]
struct HeapEntry(u64, PathBuf, FileKind, i64);
impl Ord for HeapEntry {
    fn cmp(&self, other: &Self) -> std::cmp::Ordering { other.0.cmp(&self.0) }
}
impl PartialOrd for HeapEntry {
    fn partial_cmp(&self, other: &Self) -> Option<std::cmp::Ordering> { Some(self.cmp(other)) }
}

pub fn scan_largest(root: &Path, limit: usize, kinds: &[FileKind], min_size_bytes: u64) -> Vec<BigFile> {
    let filter_kinds = if kinds.is_empty() { None } else { Some(kinds) };
    // Floor at 1 MB to keep the walk cheap regardless of the slider value.
    let min_size = min_size_bytes.max(1024 * 1024);
    let mut heap: BinaryHeap<HeapEntry> = BinaryHeap::with_capacity(limit + 1);

    let walker = WalkDir::new(root)
        .follow_links(false)
        .same_file_system(false)
        .into_iter()
        .filter_entry(|e| {
            // Skip well-known mount points and pseudo-FS roots when starting from /.
            if let Some(name) = e.file_name().to_str() {
                if e.depth() == 1 {
                    return !matches!(
                        name,
                        "proc" | "sys" | "run" | "dev" | "tmp" | "var" | "snap" | "boot"
                    );
                }
            }
            true
        });

    for entry in walker.filter_map(|e| e.ok()) {
        let Ok(md) = entry.metadata() else { continue };
        if !md.is_file() { continue; }
        let kind = FileKind::classify(entry.path());
        if let Some(k) = filter_kinds {
            if !k.contains(&kind) { continue; }
        }
        let size = md.len();
        if size < min_size { continue; }

        let modified = md
            .modified()
            .ok()
            .and_then(|t| t.duration_since(std::time::UNIX_EPOCH).ok())
            .map(|d| d.as_secs() as i64)
            .unwrap_or(0);

        heap.push(HeapEntry(size, entry.path().to_path_buf(), kind, modified));
        if heap.len() > limit {
            heap.pop();
        }
    }

    let mut out: Vec<BigFile> = heap
        .into_iter()
        .map(|HeapEntry(size, path, kind, modified)| BigFile { path, size, kind, modified_secs: modified })
        .collect();
    out.sort_by(|a, b| b.size.cmp(&a.size));
    out
}
