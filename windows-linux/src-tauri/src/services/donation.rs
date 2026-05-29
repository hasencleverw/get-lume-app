//! Donation reminder + key validation.
//!
//! HMAC-SHA256 port — verbatim from the macOS DonationManager.
//! The valid key is kept off the repository — see developer notes.
//! The pepper is stored as raw bytes so `strings <binary>` does not reveal it.
//!
//! State persistence: JSON at `<config_dir>/lume/donation.json`. The reminder
//! kicks in once per 30 days unless the user has activated a key or disabled
//! reminders permanently.

use hmac::{Hmac, Mac};
use serde::{Deserialize, Serialize};
use sha2::Sha256;
use std::path::PathBuf;
use subtle::ConstantTimeEq;

type HmacSha256 = Hmac<Sha256>;

// "lume-2026-hasen-borges-protect-secret-pepper-v2"
const PEPPER: &[u8] = &[
    0x6c, 0x75, 0x6d, 0x65, 0x2d, 0x32, 0x30, 0x32, 0x36, 0x2d, 0x68, 0x61,
    0x73, 0x65, 0x6e, 0x2d, 0x62, 0x6f, 0x72, 0x67, 0x65, 0x73, 0x2d, 0x70,
    0x72, 0x6f, 0x74, 0x65, 0x63, 0x74, 0x2d, 0x73, 0x65, 0x63, 0x72, 0x65,
    0x74, 0x2d, 0x70, 0x65, 0x70, 0x70, 0x65, 0x72, 0x2d, 0x76, 0x32,
];

const EXPECTED: &[u8; 32] = &[
    0x3f, 0x5d, 0x8f, 0x1c, 0x61, 0x73, 0x3d, 0x69,
    0x38, 0x08, 0x07, 0x26, 0xff, 0x31, 0x0b, 0x89,
    0x7b, 0x07, 0x50, 0x57, 0x4d, 0x7d, 0x8c, 0x90,
    0xfd, 0x2e, 0x42, 0xf6, 0x6c, 0x0b, 0xb9, 0x39,
];

const TWO_DAYS_SECS: i64 = 2 * 24 * 60 * 60;
const THIRTY_DAYS_SECS: i64 = 30 * 24 * 60 * 60;

pub fn validate(key: &str) -> bool {
    let normalised = key.trim().to_uppercase();
    let mut mac = match HmacSha256::new_from_slice(PEPPER) {
        Ok(m) => m,
        Err(_) => return false,
    };
    mac.update(normalised.as_bytes());
    let digest = mac.finalize().into_bytes();
    digest.ct_eq(EXPECTED).into()
}

// ──────────────────────────────────────────────────────────────────────────
// Persistent state
// ──────────────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct DonationState {
    pub has_donated: bool,
    pub reminders_disabled: bool,
    /// Unix epoch seconds of the first time the user launched the app.
    /// The first reminder is held back 2 days from this point so we don't
    /// hassle the user before they've even tried Lume.
    pub first_seen: Option<i64>,
    /// Unix epoch seconds of the last time we showed the reminder.
    pub last_reminder: Option<i64>,
}

fn state_path() -> Option<PathBuf> {
    dirs::config_dir().map(|p| p.join("lume").join("donation.json"))
}

pub fn load_state() -> DonationState {
    let Some(p) = state_path() else { return DonationState::default() };
    std::fs::read_to_string(&p)
        .ok()
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

/// Same as [`load_state`], but persists `first_seen = now` on the very first
/// boot. Use this in the get_state / should_show paths so the 2-day grace
/// window starts ticking immediately when the user opens Lume for the first
/// time, not on the day they actually accept the popup.
pub fn load_or_init_state() -> DonationState {
    let mut s = load_state();
    if s.first_seen.is_none() {
        s.first_seen = Some(now_secs());
        let _ = save_state(&s);
    }
    s
}

pub fn save_state(state: &DonationState) -> std::io::Result<()> {
    let Some(p) = state_path() else {
        return Err(std::io::Error::new(std::io::ErrorKind::NotFound, "no config dir"));
    };
    if let Some(parent) = p.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let json = serde_json::to_string_pretty(state).unwrap_or_else(|_| "{}".into());
    std::fs::write(p, json)
}

fn now_secs() -> i64 {
    std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .map(|d| d.as_secs() as i64)
        .unwrap_or(0)
}

/// Should the popup show right now?
///
/// Schedule:
///   - first time: wait 2 days after install
///   - subsequent: 30 days after the last "remind me later"
///   - never: if user activated a key or disabled reminders
pub fn should_show(state: &DonationState) -> bool {
    if state.has_donated || state.reminders_disabled {
        return false;
    }
    let now = now_secs();
    match state.last_reminder {
        None => {
            let first = state.first_seen.unwrap_or(now);
            now.saturating_sub(first) >= TWO_DAYS_SECS
        }
        Some(t) => now.saturating_sub(t) >= THIRTY_DAYS_SECS,
    }
}

/// Mark "remind me later" — schedules the next prompt 30 days from now.
pub fn mark_reminded() -> DonationState {
    let mut s = load_state();
    s.last_reminder = Some(now_secs());
    let _ = save_state(&s);
    s
}

/// Mark "don't ask again".
pub fn disable_reminders() -> DonationState {
    let mut s = load_state();
    s.reminders_disabled = true;
    let _ = save_state(&s);
    s
}

/// Validate + persist on success.
pub fn apply_key(key: &str) -> Option<DonationState> {
    if !validate(key) {
        return None;
    }
    let prev = load_state();
    let s = DonationState {
        has_donated: true,
        reminders_disabled: true,
        first_seen: prev.first_seen.or_else(|| Some(now_secs())),
        last_reminder: prev.last_reminder,
    };
    let _ = save_state(&s);
    Some(s)
}

#[cfg(test)]
mod tests {
    use super::*;


    #[test]
    fn rejects_invalid_keys() {
        assert!(!validate(""));
        assert!(!validate("LUME-DONOR-AAAA-BBBB-CCCC-DDDD"));
    }

    #[test]
    fn should_show_logic() {
        let now = now_secs();
        let mut s = DonationState::default();
        // Day 0 of install — too early
        s.first_seen = Some(now);
        assert!(!should_show(&s));

        // Just under 2 days — still too early
        s.first_seen = Some(now - TWO_DAYS_SECS + 60);
        assert!(!should_show(&s));

        // Just past 2 days — show
        s.first_seen = Some(now - TWO_DAYS_SECS - 1);
        assert!(should_show(&s));

        // Donor — never
        s.has_donated = true;
        assert!(!should_show(&s));

        // Reminders disabled — never
        s.has_donated = false;
        s.reminders_disabled = true;
        assert!(!should_show(&s));

        // After "remind later" — silent for 30 days
        s.reminders_disabled = false;
        s.last_reminder = Some(now);
        assert!(!should_show(&s));

        s.last_reminder = Some(now - THIRTY_DAYS_SECS - 1);
        assert!(should_show(&s));
    }
}
