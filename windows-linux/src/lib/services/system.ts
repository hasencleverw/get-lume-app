import { invoke } from '@tauri-apps/api/core';

export interface SystemMetrics {
  cpu_usage: number;
  cpu_cores: number;
  ram_total: number;
  ram_used: number;
  ram_available: number;
  swap_total: number;
  swap_used: number;
  disk_total: number;
  disk_used: number;
  disk_free: number;
  uptime_seconds: number;
}

export interface ProcessSnapshot {
  pid: number;
  name: string;
  cpu_usage: number;
  memory: number;
}

export interface HostInfo {
  os_name: string;
  os_version: string;
  kernel: string;
  hostname: string;
  arch: string;
}

export interface JunkEntry {
  category: string;
  path: string;
  size: number;
}

export type FileKind =
  | 'video' | 'audio' | 'image' | 'archive' | 'document' | 'code' | 'binary' | 'other';

export interface BigFile {
  path: string;
  size: number;
  kind: FileKind;
  modified_secs: number;
}

export type AppSource = 'pacman' | 'dpkg' | 'rpm' | 'flatpak' | 'snap' | 'desktop' | 'windows';

export interface AppEntry {
  id: string;
  name: string;
  version: string | null;
  size_bytes: number;
  source: AppSource;
  description: string | null;
  exec: string | null;
}

export type Severity = 'info' | 'low' | 'medium' | 'high';
export type FindingKind = 'autostart' | 'binary' | 'browser-ext' | 'systemd-unit';

export interface Finding {
  kind: FindingKind;
  severity: Severity;
  title: string;
  detail: string;
  path: string | null;
  recommendation: string;
}

export interface ProtectionReport {
  findings: Finding[];
  items_scanned: number;
  took_ms: number;
}

export interface TaskOutcome {
  ok: boolean;
  message: string;
}

export interface StartupItem {
  name: string;
  exec: string;
  source: 'user' | 'system';
  path: string;
  enabled: boolean;
}

export const systemApi = {
  metrics: () => invoke<SystemMetrics>('get_metrics'),
  topProcesses: (limit = 8) => invoke<ProcessSnapshot[]>('get_top_processes', { limit }),
  hostInfo: () => invoke<HostInfo>('get_host_info'),
  freeMemory: () => invoke<{ before_used: number; after_used: number; freed: number }>('free_memory')
};

export const diskApi = {
  scanJunk: (categories: string[]) =>
    invoke<{ entries: JunkEntry[]; total_bytes: number }>('scan_junk', { categories }),
  clean: (entries: JunkEntry[]) => invoke<number>('clean_categories', { entries })
};

export const largeFilesApi = {
  scan: (root: string | null, limit = 100, kinds: FileKind[] = []) =>
    invoke<BigFile[]>('scan_largest', { root, limit, kinds })
};

export const appsApi = {
  list: () => invoke<AppEntry[]>('list_apps'),
  uninstall: (source: AppSource, id: string) => invoke<void>('uninstall_app', { source, id })
};

export const protectionApi = {
  scan: () => invoke<ProtectionReport>('protection_scan')
};

export const performanceApi = {
  flushDns:           () => invoke<TaskOutcome>('perf_flush_dns'),
  rebuildFonts:       () => invoke<TaskOutcome>('perf_rebuild_font_cache'),
  emptyTrash:         () => invoke<TaskOutcome>('perf_empty_trash'),
  resetBaloo:         () => invoke<TaskOutcome>('perf_reset_baloo'),
  cleanPkgCache:      () => invoke<TaskOutcome>('perf_clean_package_cache'),
  vacuumJournal:      () => invoke<TaskOutcome>('perf_vacuum_journal'),
  restartSearchIndex: () => invoke<TaskOutcome>('perf_restart_search_index'),
  diskCleanup:        () => invoke<TaskOutcome>('perf_disk_cleanup'),
  listStartup:        () => invoke<StartupItem[]>('perf_list_startup'),
  toggleStartup:      (path: string, enable: boolean) => invoke<void>('perf_toggle_startup', { path, enable })
};

export interface UpdateDisplay {
  current: string;
  latest: string | null;
  release_url: string | null;
  release_notes: string | null;
  available: boolean;
  last_check_secs: number | null;
}

export const updaterApi = {
  status:      () => invoke<UpdateDisplay>('updater_status'),
  shouldCheck: () => invoke<boolean>('updater_should_check'),
  checkNow:    () => invoke<UpdateDisplay>('updater_check_now')
};

export interface DonationState {
  has_donated: boolean;
  reminders_disabled: boolean;
  last_reminder: number | null;
}

export const donationApi = {
  validate:    (key: string) => invoke<boolean>('validate_donor_key', { key }),
  getState:    () => invoke<DonationState>('donation_get_state'),
  shouldShow:  () => invoke<boolean>('donation_should_show'),
  markReminded: () => invoke<DonationState>('donation_mark_reminded'),
  disable:     () => invoke<DonationState>('donation_disable_reminders'),
  applyKey:    (key: string) => invoke<DonationState>('donation_apply_key', { key })
};

export type Language = 'pt' | 'en';
export interface Settings {
  language: Language;
  close_to_tray: boolean;
  start_minimized: boolean;
}
export interface AppInfo {
  version: string;
  repo_url: string;
  homepage: string;
  license: string;
}
export const settingsApi = {
  get:               () => invoke<Settings>('settings_get'),
  set:               (settings: Settings) => invoke<Settings>('settings_set', { settings }),
  appInfo:           () => invoke<AppInfo>('settings_app_info'),
  autostartEnabled:  () => invoke<boolean>('settings_autostart_enabled'),
  setAutostart:      (enabled: boolean) => invoke<boolean>('settings_set_autostart', { enabled })
};
