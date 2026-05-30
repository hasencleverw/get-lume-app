mod commands;
mod platform;
mod services;
mod state;
mod tray;

use state::AppState;
use tauri::Manager;

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| tracing_subscriber::EnvFilter::new("info")),
        )
        .with_target(false)
        .compact()
        .init();

    tauri::Builder::default()
        // Reject a second instance: when the user double-clicks the shortcut
        // again, focus the existing window instead of spawning a new tray
        // icon + process. Closure runs in the already-running instance.
        .plugin(tauri_plugin_single_instance::init(|app, _argv, _cwd| {
            use tauri::Manager;
            if let Some(w) = app.get_webview_window("main") {
                let _ = w.unminimize();
                let _ = w.show();
                let _ = w.set_focus();
            }
        }))
        .plugin(tauri_plugin_shell::init())
        .plugin(tauri_plugin_dialog::init())
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_os::init())
        .setup(|app| {
            app.manage(AppState::new());
            tray::install(app)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::system::get_metrics,
            commands::system::get_top_processes,
            commands::system::get_host_info,
            commands::disk::scan_junk,
            commands::disk::clean_categories,
            commands::memory::free_memory,
            commands::donation::validate_donor_key,
            commands::donation::donation_get_state,
            commands::donation::donation_should_show,
            commands::donation::donation_mark_reminded,
            commands::donation::donation_disable_reminders,
            commands::donation::donation_apply_key,
            commands::updater::updater_status,
            commands::updater::updater_should_check,
            commands::updater::updater_check_now,
            commands::large_files::scan_largest,
            commands::apps::list_apps,
            commands::apps::uninstall_app,
            commands::performance::perf_flush_dns,
            commands::performance::perf_rebuild_font_cache,
            commands::performance::perf_empty_trash,
            commands::performance::perf_reset_baloo,
            commands::performance::perf_clean_package_cache,
            commands::performance::perf_vacuum_journal,
            commands::performance::perf_restart_search_index,
            commands::performance::perf_disk_cleanup,
            commands::performance::perf_list_startup,
            commands::performance::perf_toggle_startup,
            commands::protection::protection_scan,
            commands::settings::settings_get,
            commands::settings::settings_set,
            commands::settings::settings_app_info,
            commands::settings::settings_autostart_enabled,
            commands::settings::settings_set_autostart,
        ])
        .run(tauri::generate_context!())
        .expect("error while running Lume");
}
