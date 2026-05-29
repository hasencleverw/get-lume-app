use crate::services::system_monitor::{self, HostInfo, ProcessSnapshot, SystemMetrics};
use crate::state::AppState;
use tauri::State;

#[tauri::command]
pub fn get_metrics(state: State<'_, AppState>) -> SystemMetrics {
    let mut sys = state.sys.lock();
    system_monitor::collect(&mut sys)
}

#[tauri::command]
pub fn get_top_processes(state: State<'_, AppState>, limit: Option<usize>) -> Vec<ProcessSnapshot> {
    let mut sys = state.sys.lock();
    system_monitor::top_processes(&mut sys, limit.unwrap_or(8))
}

#[tauri::command]
pub fn get_host_info() -> HostInfo {
    system_monitor::host_info()
}
