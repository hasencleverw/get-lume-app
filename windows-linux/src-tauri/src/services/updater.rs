//! Update notifier.
//!
//! Pings GitHub Releases API ≤ 1 ×/week. If the latest non-prerelease tag is
//! semver-greater than the embedded `CARGO_PKG_VERSION`, the frontend shows a
//! banner with a link to the release page. The app NEVER downloads or
//! installs anything automatically — the user decides what to do.
//!
//! Repo is set at compile time via `LUME_GITHUB_REPO=owner/repo`. Default
//! placeholder keeps the build green; change when the public repo exists.

use anyhow::{anyhow, Context, Result};
use semver::Version;
use serde::{Deserialize, Serialize};
use std::path::PathBuf;

const REPO: &str = match option_env!("LUME_GITHUB_REPO") {
    Some(v) => v,
    None => "hasencleverw/get-lume-app",
};

const SEVEN_DAYS_SECS: i64 = 7 * 24 * 60 * 60;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct UpdaterState {
    /// Unix epoch seconds of the last successful check (regardless of outcome).
    pub last_check_secs: Option<i64>,
    /// Last known latest tag seen on GitHub (cached so we can render the banner
    /// instantly on app boot even before the next check completes).
    pub last_known_latest: Option<String>,
    /// Last known release URL.
    pub last_known_url: Option<String>,
    /// Last known release notes.
    pub last_known_notes: Option<String>,
}

#[derive(Debug, Clone, Serialize)]
pub struct UpdateDisplay {
    pub current: String,
    pub latest: Option<String>,
    pub release_url: Option<String>,
    pub release_notes: Option<String>,
    pub available: bool,
    pub last_check_secs: Option<i64>,
}

#[derive(Debug, Deserialize)]
struct GhRelease {
    tag_name: String,
    html_url: String,
    body: Option<String>,
    #[serde(default)]
    prerelease: bool,
    #[serde(default)]
    draft: bool,
}

fn state_path() -> Option<PathBuf> {
    dirs::config_dir().map(|p| p.join("lume").join("updater.json"))
}

pub fn load_state() -> UpdaterState {
    state_path()
        .and_then(|p| std::fs::read_to_string(p).ok())
        .and_then(|s| serde_json::from_str(&s).ok())
        .unwrap_or_default()
}

pub fn save_state(state: &UpdaterState) -> std::io::Result<()> {
    let p = state_path()
        .ok_or_else(|| std::io::Error::new(std::io::ErrorKind::NotFound, "no config dir"))?;
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

pub fn should_check(state: &UpdaterState) -> bool {
    match state.last_check_secs {
        None => true,
        Some(t) => now_secs().saturating_sub(t) >= SEVEN_DAYS_SECS,
    }
}

pub fn current_version_str() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

/// Render-ready snapshot. Combines current binary version with persisted
/// "last seen" data so the UI can show the banner immediately.
pub fn display_from_state(state: &UpdaterState) -> UpdateDisplay {
    let current = current_version_str().to_string();
    let cur_v = Version::parse(&current).ok();
    let latest_v = state.last_known_latest.as_deref().and_then(|s| Version::parse(s).ok());

    let available = matches!((&cur_v, &latest_v), (Some(c), Some(l)) if l > c);

    UpdateDisplay {
        current,
        latest: state.last_known_latest.clone(),
        release_url: state.last_known_url.clone(),
        release_notes: state.last_known_notes.clone(),
        available,
        last_check_secs: state.last_check_secs,
    }
}

/// Hits GitHub. Updates persisted state on success. Returns rendered display.
/// Network failures are non-fatal: cached state is returned instead.
pub async fn check_now() -> Result<UpdateDisplay> {
    let release = match fetch_latest().await {
        Ok(r) => r,
        Err(e) => {
            tracing::warn!("updater fetch failed: {e}");
            // Still bump last_check so we don't hammer the API on every boot.
            let mut state = load_state();
            state.last_check_secs = Some(now_secs());
            let _ = save_state(&state);
            return Ok(display_from_state(&state));
        }
    };

    let latest_clean = release.tag_name.trim_start_matches('v').to_string();
    let mut state = load_state();
    state.last_check_secs = Some(now_secs());
    state.last_known_latest = Some(latest_clean);
    state.last_known_url = Some(release.html_url);
    state.last_known_notes = release.body;
    save_state(&state).ok();

    Ok(display_from_state(&state))
}

async fn fetch_latest() -> Result<GhRelease> {
    let url = format!("https://api.github.com/repos/{REPO}/releases/latest");
    let client = reqwest::Client::builder()
        .user_agent(format!("Lume/{}", current_version_str()))
        .timeout(std::time::Duration::from_secs(10))
        .build()
        .context("building reqwest client")?;

    let resp = client
        .get(&url)
        .header("Accept", "application/vnd.github+json")
        .send()
        .await
        .context("github API request")?;

    let status = resp.status();
    if status == reqwest::StatusCode::NOT_FOUND {
        return Err(anyhow!("repo {REPO} has no releases yet"));
    }
    let release: GhRelease = resp.error_for_status()?.json().await?;
    if release.draft || release.prerelease {
        return Err(anyhow!("latest release is a draft/prerelease"));
    }
    Ok(release)
}

