use crate::platform::host;
use anyhow::Result;
use serde::Serialize;
use sysinfo::{MemoryRefreshKind, RefreshKind, System};

#[derive(Debug, Clone, Serialize)]
pub struct MemoryCleanResult {
    pub before_used: u64,
    pub after_used: u64,
    pub freed: u64,
}

/// Drops OS file-system caches. Requires root via pkexec on Linux,
/// EmptyWorkingSet iteration on Windows (TODO).
pub fn free_memory() -> Result<MemoryCleanResult> {
    let mut sys = System::new_with_specifics(
        RefreshKind::new().with_memory(MemoryRefreshKind::everything()),
    );
    sys.refresh_memory();
    let total = sys.total_memory();
    let before_used = total.saturating_sub(sys.available_memory());

    host::free_system_memory()?;

    sys.refresh_memory();
    let after_used = total.saturating_sub(sys.available_memory());
    let freed = before_used.saturating_sub(after_used);
    Ok(MemoryCleanResult { before_used, after_used, freed })
}
