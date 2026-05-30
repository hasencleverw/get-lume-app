import { messages, type MessageKey } from '$lib/i18n/messages';
import type { Language } from '$lib/services/system';

class I18n {
  lang = $state<Language>('pt');

  setLang(lang: Language) {
    this.lang = lang;
  }

  /// Translation. Falls back to PT then to the key itself if missing.
  /// Supports {placeholder} interpolation: `i18n.t('foo', { n: 3 })`.
  t(key: MessageKey | string, vars?: Record<string, string | number>): string {
    const dict = messages[this.lang] as Record<string, string>;
    const fallback = messages.pt as Record<string, string>;
    let s = dict[key] ?? fallback[key] ?? key;
    if (vars) {
      for (const [k, v] of Object.entries(vars)) {
        s = s.replaceAll(`{${k}}`, String(v));
      }
    }
    return s;
  }
}

export const i18n = new I18n();
