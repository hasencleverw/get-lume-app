import { settingsApi, type Settings, type AppInfo } from '$lib/services/system';
import { i18n } from '$lib/stores/i18n.svelte';

class SettingsStore {
  settings = $state<Settings>({ language: 'pt', close_to_tray: true, start_minimized: false });
  autostart = $state(false);
  appInfo = $state<AppInfo | null>(null);
  ready = $state(false);

  async init() {
    const [s, a, info] = await Promise.all([
      settingsApi.get(),
      settingsApi.autostartEnabled(),
      settingsApi.appInfo()
    ]);
    this.settings = s;
    this.autostart = a;
    this.appInfo = info;
    i18n.setLang(s.language);
    this.ready = true;
  }

  async patch(partial: Partial<Settings>) {
    const next = { ...this.settings, ...partial };
    this.settings = await settingsApi.set(next);
    if (partial.language) i18n.setLang(this.settings.language);
  }

  async setAutostart(enabled: boolean) {
    this.autostart = await settingsApi.setAutostart(enabled);
  }
}

export const settings = new SettingsStore();
