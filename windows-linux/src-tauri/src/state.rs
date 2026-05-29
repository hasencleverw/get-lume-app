use parking_lot::Mutex;
use std::sync::Arc;
use sysinfo::System;

/// Shared application state held in Tauri's managed registry.
///
/// We keep a single `sysinfo::System` instance so CPU deltas remain accurate
/// across polls (sysinfo measures CPU usage between two consecutive refreshes).
pub struct AppState {
    pub sys: Arc<Mutex<System>>,
}

impl AppState {
    pub fn new() -> Self {
        let mut sys = System::new_all();
        sys.refresh_all();
        Self {
            sys: Arc::new(Mutex::new(sys)),
        }
    }
}
