use crate::services::donation::{self, DonationState};

#[tauri::command]
pub fn donation_get_state() -> DonationState {
    donation::load_or_init_state()
}

#[tauri::command]
pub fn donation_should_show() -> bool {
    donation::should_show(&donation::load_or_init_state())
}

#[tauri::command]
pub fn donation_mark_reminded() -> DonationState {
    donation::mark_reminded()
}

#[tauri::command]
pub fn donation_disable_reminders() -> DonationState {
    donation::disable_reminders()
}

#[tauri::command]
pub fn donation_apply_key(key: String) -> Result<DonationState, String> {
    donation::apply_key(&key).ok_or_else(|| "Chave inválida".to_string())
}

#[tauri::command]
pub fn validate_donor_key(key: String) -> bool {
    donation::validate(&key)
}
