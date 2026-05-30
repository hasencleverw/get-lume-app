//! System tray integration.
//!
//! Behaviour:
//!  - Clicking the window's close (X) button HIDES instead of closing.
//!  - Minimizing the window HIDES it (no taskbar entry while hidden).
//!  - Left-click on the tray icon toggles visibility.
//!  - Right-click on the tray icon opens a menu with Show / Hide / Quit.
//!
//! Only Quit truly terminates the app — everything else just hides.

use tauri::{
    menu::{MenuBuilder, MenuItemBuilder, PredefinedMenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Manager, WindowEvent,
};

pub fn install(app: &tauri::App) -> tauri::Result<()> {
    let show_item = MenuItemBuilder::with_id("show", "Mostrar Lume").build(app)?;
    let hide_item = MenuItemBuilder::with_id("hide", "Ocultar").build(app)?;
    let separator = PredefinedMenuItem::separator(app)?;
    let quit_item = MenuItemBuilder::with_id("quit", "Sair do Lume").build(app)?;

    let menu = MenuBuilder::new(app)
        .items(&[&show_item, &hide_item, &separator, &quit_item])
        .build()?;

    let icon = app
        .default_window_icon()
        .cloned()
        .expect("missing default window icon");

    let _ = TrayIconBuilder::with_id("lume-main")
        .icon(icon)
        .tooltip("Lume")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| match event.id().as_ref() {
            "show" => show_main(app),
            "hide" => hide_main(app),
            "quit" => app.exit(0),
            _ => {}
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                ..
            } = event
            {
                toggle_main(tray.app_handle());
            }
        })
        .build(app)?;

    if let Some(window) = app.get_webview_window("main") {
        let handle = app.handle().clone();
        window.on_window_event(move |event| match event {
            WindowEvent::CloseRequested { api, .. } => {
                // Honor user preference: if "close to tray" is off, let the
                // close actually go through. Otherwise hide.
                let settings = crate::services::settings::load();
                if settings.close_to_tray {
                    api.prevent_close();
                    hide_main(&handle);
                }
            }
            WindowEvent::Resized(_) => {
                // Minimize is reported as a resize where the window enters the
                // minimized state. Convert that into a hide so the app's only
                // surface while idle is the tray icon.
                if let Some(w) = handle.get_webview_window("main") {
                    if w.is_minimized().unwrap_or(false) {
                        let _ = w.hide();
                    }
                }
            }
            _ => {}
        });
    }

    Ok(())
}

fn show_main(app: &AppHandle) {
    if let Some(w) = app.get_webview_window("main") {
        let _ = w.unminimize();
        let _ = w.show();
        let _ = w.set_focus();
    }
}

fn hide_main(app: &AppHandle) {
    if let Some(w) = app.get_webview_window("main") {
        let _ = w.hide();
    }
}

fn toggle_main(app: &AppHandle) {
    if let Some(w) = app.get_webview_window("main") {
        match w.is_visible() {
            Ok(true) => {
                let _ = w.hide();
            }
            _ => show_main(app),
        }
    }
}
