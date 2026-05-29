//! Platform-specific implementations.
//!
//! Each module exposes the same surface; `lib.rs` picks one via `cfg`.

#[cfg(target_os = "linux")]
pub mod linux;
#[cfg(target_os = "linux")]
pub use linux as host;

#[cfg(target_os = "windows")]
pub mod windows;
#[cfg(target_os = "windows")]
pub use windows as host;
