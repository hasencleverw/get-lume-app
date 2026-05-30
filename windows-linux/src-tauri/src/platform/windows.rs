//! Windows host glue. Stubs only — implemented in the Windows port phase.

use anyhow::{anyhow, Context, Result};
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

// ===========================================================================
// Autostart via HKCU\Software\Microsoft\Windows\CurrentVersion\Run
// ===========================================================================
//
// Per-user autostart. Writing here doesn't require admin (no UAC prompt) and
// is the same place Task Manager → Startup reads. We use `HKEY_CURRENT_USER`
// so the toggle is local to the signed-in user.

const RUN_KEY: &str = r"Software\Microsoft\Windows\CurrentVersion\Run";
const VALUE_NAME: &str = "Lume";

pub fn is_autostart_enabled() -> bool {
    use winreg::enums::HKEY_CURRENT_USER;
    use winreg::RegKey;
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    let Ok(run) = hkcu.open_subkey(RUN_KEY) else { return false };
    let val: Result<String, _> = run.get_value(VALUE_NAME);
    val.is_ok()
}

pub fn set_autostart(enabled: bool) -> Result<()> {
    use winreg::enums::{HKEY_CURRENT_USER, KEY_SET_VALUE};
    use winreg::RegKey;
    let hkcu = RegKey::predef(HKEY_CURRENT_USER);
    if enabled {
        let exe = std::env::current_exe().context("getting current_exe")?;
        // Quote so Windows handles spaces in the path correctly.
        let cmd = format!("\"{}\"", exe.display());
        let (run, _) = hkcu
            .create_subkey(RUN_KEY)
            .context("open Run key for write")?;
        run.set_value(VALUE_NAME, &cmd)
            .context("write Lume value")?;
    } else {
        // delete_value returns NotFound if it's already not there — we treat
        // that as success because the end state matches what the caller asked.
        let run = hkcu
            .open_subkey_with_flags(RUN_KEY, KEY_SET_VALUE)
            .context("open Run key for delete")?;
        match run.delete_value(VALUE_NAME) {
            Ok(_) => {}
            Err(e) if e.kind() == std::io::ErrorKind::NotFound => {}
            Err(e) => return Err(anyhow!(e).context("delete Lume value")),
        }
    }
    Ok(())
}
