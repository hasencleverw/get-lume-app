//! Windows host glue. Stubs only — implemented in the Windows port phase.

use anyhow::{anyhow, Result};
use std::path::{Path, PathBuf};

pub fn free_system_memory() -> Result<()> {
    // Iterate all running processes and call EmptyWorkingSet on each. This
    // trims the working set without killing the process — the OS pages out
    // unused pages, which is the closest Windows equivalent to Linux's
    // drop_caches. Per-process failures are silent (we never have the right
    // to touch every process, especially system ones).
    use windows::Win32::Foundation::{CloseHandle, FALSE, HANDLE};
    use windows::Win32::System::ProcessStatus::{EnumProcesses, EmptyWorkingSet};
    use windows::Win32::System::Threading::{
        OpenProcess, PROCESS_QUERY_INFORMATION, PROCESS_SET_QUOTA,
    };

    const MAX_PIDS: usize = 4096;
    let mut pids = vec![0u32; MAX_PIDS];
    let mut bytes_returned: u32 = 0;

    let ok = unsafe {
        EnumProcesses(
            pids.as_mut_ptr(),
            (pids.len() * std::mem::size_of::<u32>()) as u32,
            &mut bytes_returned,
        )
    };
    if ok.is_err() {
        return Err(anyhow!("EnumProcesses failed"));
    }

    let count = bytes_returned as usize / std::mem::size_of::<u32>();
    for &pid in &pids[..count] {
        if pid == 0 { continue; }
        let access = PROCESS_QUERY_INFORMATION | PROCESS_SET_QUOTA;
        let handle = unsafe { OpenProcess(access, FALSE, pid) };
        let Ok(h) = handle else { continue };
        if h.is_invalid() { continue; }
        unsafe {
            let _ = EmptyWorkingSet(h);
            let _ = CloseHandle(h);
        }
    }
    Ok(())
}

pub fn trash_path(path: &Path) -> Result<()> {
    trash::delete(path).map_err(|e| anyhow!("trash failed: {e}"))
}

pub fn downloads_dir() -> Option<PathBuf> {
    dirs::download_dir()
}

pub fn flush_dns() -> Result<()> {
    let status = std::process::Command::new("ipconfig")
        .arg("/flushdns")
        .status()?;
    if !status.success() {
        return Err(anyhow!("ipconfig /flushdns failed"));
    }
    Ok(())
}

pub fn distro_pretty_name() -> String {
    "Windows".into()
}

pub fn is_autostart_enabled() -> bool {
    false // implemented in the Windows phase via HKCU\…\Run
}

pub fn set_autostart(_enabled: bool) -> Result<()> {
    Err(anyhow!("Windows autostart not implemented yet"))
}
