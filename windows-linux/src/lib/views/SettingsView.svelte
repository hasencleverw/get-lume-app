<script lang="ts">
  import { onMount } from 'svelte';
  import { openUrl } from '@tauri-apps/plugin-opener';
  import { settings } from '$lib/stores/settings.svelte';
  import { donation } from '$lib/stores/donation.svelte';
  import { updater } from '$lib/stores/updater.svelte';
  import { navigation } from '$lib/stores/navigation.svelte';
  import { i18n } from '$lib/stores/i18n.svelte';
  import { platform } from '$lib/stores/platform.svelte';
  import type { Language } from '$lib/services/system';

  const LANGUAGES: { id: Language; label: string }[] = [
    { id: 'pt', label: 'Português' },
    { id: 'en', label: 'English' }
  ];

  const PIX = '95c1adaf-d8ee-4498-b7af-3a810ae30b59';
  const PAYPAL = 'hasen.borges@gmail.com';

  let keyInput = $state('');
  let keyError = $state(false);
  let keyValidating = $state(false);

  let copiedPix = $state(false);
  let copiedPayPal = $state(false);

  onMount(() => { settings.init(); });

  function lastCheckAgo(secs: number | null): string {
    if (!secs) return i18n.t('settings.updates.never');
    const diff = Date.now() / 1000 - secs;
    if (diff < 60) return i18n.t('settings.updates.now');
    if (diff < 3600) return i18n.t('settings.updates.minAgo', { n: Math.floor(diff / 60) });
    if (diff < 86400) return i18n.t('settings.updates.hourAgo', { n: Math.floor(diff / 3600) });
    return i18n.t('settings.updates.dayAgo', { n: Math.floor(diff / 86400) });
  }

  async function checkUpdate() {
    await updater.checkInBackground();
  }

  async function copyValue(value: string, which: 'pix' | 'paypal') {
    try {
      await navigator.clipboard.writeText(value);
      if (which === 'pix') {
        copiedPix = true; setTimeout(() => (copiedPix = false), 2000);
      } else {
        copiedPayPal = true; setTimeout(() => (copiedPayPal = false), 2000);
      }
    } catch { /* */ }
  }

  async function submitKey() {
    if (!keyInput.trim() || keyValidating) return;
    keyValidating = true; keyError = false;
    const ok = await donation.submitKey(keyInput);
    keyValidating = false;
    if (ok) { keyInput = ''; } else { keyError = true; }
  }

  async function openHome() { if (settings.appInfo) await openUrl(settings.appInfo.homepage); }
  async function openRepo() { if (settings.appInfo) await openUrl(settings.appInfo.repo_url); }
  async function openLatestRelease() { await updater.openRelease(); }
</script>

<div class="view">
  <header class="hero">
    <button class="back-btn" onclick={() => navigation.back()} aria-label={i18n.t('common.back')} title={i18n.t('common.back')}>
      <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
        <path d="M15 18l-6-6 6-6" />
      </svg>
      <span>{i18n.t('common.back')}</span>
    </button>
    <div>
      <h1 class="h-display">{i18n.t('page.settings.title')}</h1>
      <p class="subtle">{i18n.t('page.settings.subtitle')}</p>
    </div>
  </header>

  {#if !settings.ready}
    <section class="card glass loading">{i18n.t('common.loading')}</section>
  {:else}
    <!-- ─── Atualizações ─── -->
    <section class="card glass">
      <header class="card-head">
        <div>
          <h2 class="h-2">{i18n.t('settings.updates.title')}</h2>
          <span class="subtle">{i18n.t('settings.updates.frequency')}</span>
        </div>
        <button class="ghost" onclick={checkUpdate} disabled={updater.checking}>
          {updater.checking ? i18n.t('settings.updates.checking') : i18n.t('settings.updates.checkNow')}
        </button>
      </header>
      <div class="kv">
        <div><dt>{i18n.t('settings.updates.installed')}</dt><dd class="mono">{settings.appInfo?.version ?? '—'}</dd></div>
        <div><dt>{i18n.t('settings.updates.lastCheck')}</dt><dd class="subtle">{lastCheckAgo(updater.status?.last_check_secs ?? null)}</dd></div>
        {#if updater.status?.latest}
          <div><dt>{i18n.t('settings.updates.latest')}</dt><dd class="mono">v{updater.status.latest}</dd></div>
        {/if}
      </div>
      {#if updater.status?.available}
        <div class="update-call">
          <span><b>{i18n.t('settings.updates.available')}</b> v{updater.status.latest}</span>
          <button class="primary" onclick={openLatestRelease}>{i18n.t('settings.updates.viewOnGitHub')}</button>
        </div>
      {/if}
    </section>

    <!-- ─── Apoio ─── -->
    <section class="card glass">
      <header class="card-head">
        <div>
          <h2 class="h-2">{i18n.t('settings.donate.title')}</h2>
          {#if donation.state.has_donated}
            <span class="badge donor">{i18n.t('settings.donate.donorBadge')}</span>
          {:else}
            <span class="subtle">{i18n.t('settings.donate.tagline')}</span>
          {/if}
        </div>
      </header>

      {#if !donation.state.has_donated}
        <div class="key-row">
          <input
            type="text"
            bind:value={keyInput}
            oninput={() => (keyError = false)}
            placeholder={i18n.t('settings.donate.keyPlaceholder')}
            class:err={keyError}
            disabled={keyValidating}
          />
          <button class="primary" onclick={submitKey} disabled={!keyInput.trim() || keyValidating}>
            {keyValidating ? i18n.t('settings.donate.validating') : i18n.t('settings.donate.activate')}
          </button>
        </div>
        {#if keyError}<p class="err-text">{i18n.t('settings.donate.invalid')}</p>{/if}

        <div class="donate-grid">
          <div class="donate-card pix">
            <header>
              <span class="donate-icon">
                <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="3" y="3" width="7" height="7"/><rect x="14" y="3" width="7" height="7"/><rect x="3" y="14" width="7" height="7"/><rect x="14" y="14" width="7" height="7"/></svg>
              </span>
              <div><b>PIX</b><span class="pill">{i18n.t('settings.donate.pixBadge')}</span></div>
            </header>
            <code>{PIX}</code>
            <button class="copy" class:on={copiedPix} onclick={() => copyValue(PIX, 'pix')}>
              {copiedPix ? i18n.t('common.copied') : i18n.t('common.copy')}
            </button>
          </div>

          <div class="donate-card paypal">
            <header>
              <span class="donate-icon">
                <svg viewBox="0 0 24 24" width="13" height="13" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M2 10h20"/></svg>
              </span>
              <div><b>PayPal</b><span class="pill blue">{i18n.t('settings.donate.paypalBadge')}</span></div>
            </header>
            <code>{PAYPAL}</code>
            <button class="copy" class:on={copiedPayPal} onclick={() => copyValue(PAYPAL, 'paypal')}>
              {copiedPayPal ? i18n.t('common.copied') : i18n.t('common.copy')}
            </button>
          </div>
        </div>
      {/if}
    </section>

    <!-- ─── Geral ─── -->
    <section class="card glass">
      <header class="card-head"><h2 class="h-2">{i18n.t('settings.general.title')}</h2></header>

      <div class="row">
        <div class="row-text">
          <span class="row-title">{i18n.t('settings.general.autostart')}</span>
          <span class="row-desc">{@html i18n.t(platform.isWindows ? 'settings.general.autostartDesc.windows' : 'settings.general.autostartDesc.linux')}</span>
        </div>
        <button class="toggle" class:on={settings.autostart} onclick={() => settings.setAutostart(!settings.autostart)} aria-label={i18n.t('settings.general.autostart')}>
          <span class="knob"></span>
        </button>
      </div>

      <div class="row">
        <div class="row-text">
          <span class="row-title">{i18n.t('settings.general.closeToTray')}</span>
          <span class="row-desc">{i18n.t('settings.general.closeToTrayDesc')}</span>
        </div>
        <button class="toggle" class:on={settings.settings.close_to_tray} onclick={() => settings.patch({ close_to_tray: !settings.settings.close_to_tray })} aria-label={i18n.t('settings.general.closeToTray')}>
          <span class="knob"></span>
        </button>
      </div>

      <div class="row">
        <div class="row-text">
          <span class="row-title">{i18n.t('settings.general.language')}</span>
          <span class="row-desc">{i18n.t('settings.general.languageDesc')}</span>
        </div>
        <div class="seg">
          {#each LANGUAGES as lang}
            <button class:active={settings.settings.language === lang.id} onclick={() => settings.patch({ language: lang.id })}>
              {lang.label}
            </button>
          {/each}
        </div>
      </div>
    </section>

    <!-- ─── Sobre ─── -->
    <section class="card glass about">
      <header class="card-head"><h2 class="h-2">{i18n.t('settings.about.title')}</h2></header>
      <div class="about-body">
        <div class="about-brand">
          <img class="logo" src="/lume-icon.png" alt="Lume" />
          <div>
            <b>Lume</b>
            <span class="mono">v{settings.appInfo?.version ?? '—'}</span>
          </div>
        </div>
        <dl class="about-meta">
          <div><dt>{i18n.t('settings.about.license')}</dt><dd>{settings.appInfo?.license ?? '—'}</dd></div>
          <div><dt>{i18n.t('settings.about.repo')}</dt><dd><button class="link" onclick={openRepo}>{settings.appInfo?.repo_url ?? '—'}</button></dd></div>
          <div><dt>{i18n.t('settings.about.homepage')}</dt><dd><button class="link" onclick={openHome}>{settings.appInfo?.homepage ?? '—'}</button></dd></div>
        </dl>
      </div>
    </section>
  {/if}
</div>

<style>
  .view { padding: 28px 32px 40px; display: flex; flex-direction: column; gap: 18px; overflow-y: auto; height: 100%; }
  .hero { display: flex; flex-direction: column; gap: 10px; }
  .hero p { margin-top: 4px; font-size: 13px; }
  .back-btn {
    align-self: flex-start;
    display: flex; align-items: center; gap: 6px;
    padding: 6px 10px 6px 8px;
    border-radius: 8px;
    background: rgba(255, 255, 255, 0.05);
    border: 1px solid var(--border);
    color: var(--text-secondary);
    font-size: 12px; font-weight: 600;
    transition: background var(--dur-fast) var(--ease-out), color var(--dur-fast) var(--ease-out);
  }
  .back-btn:hover { background: rgba(255, 255, 255, 0.09); color: #fff; }
  .loading { padding: 40px; text-align: center; color: var(--text-secondary); }

  .card { padding: 20px 22px; }
  .card-head { display: flex; align-items: flex-start; justify-content: space-between; gap: 16px; margin-bottom: 14px; }
  .card-head h2 { margin-bottom: 2px; }
  .badge.donor {
    display: inline-block; margin-top: 4px;
    padding: 3px 9px; border-radius: 999px;
    background: rgba(255, 107, 157, 0.16); color: #FF6B9D;
    font-size: 11px; font-weight: 700;
  }

  /* === Atualizações === */
  .kv { display: grid; grid-template-columns: repeat(auto-fill, minmax(220px, 1fr)); gap: 10px 24px; margin-top: 4px; }
  .kv > div { display: flex; flex-direction: column; gap: 2px; }
  dt { font-size: 10.5px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--text-muted); }
  dd { font-size: 13px; color: #fff; }
  .update-call {
    margin-top: 14px;
    display: flex; justify-content: space-between; align-items: center; gap: 16px;
    padding: 10px 14px; border-radius: 10px;
    background: color-mix(in srgb, var(--accent) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--accent) 32%, transparent);
    font-size: 12.5px;
  }
  .update-call b { color: #fff; }

  /* === Apoio === */
  .key-row { display: flex; gap: 8px; margin-bottom: 14px; }
  .key-row input {
    flex: 1; padding: 9px 12px; border-radius: 9px;
    font-family: var(--font-mono); font-size: 12px;
    background: rgba(0,0,0,0.45);
    border: 1px solid rgba(255,255,255,0.12);
    color: #fff; outline: none;
  }
  .key-row input:focus { border-color: var(--accent); }
  .key-row input.err { border-color: var(--danger); }
  .err-text { color: var(--danger); font-size: 11.5px; font-weight: 600; margin-bottom: 14px; }

  .donate-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(240px, 1fr)); gap: 10px; }
  .donate-card {
    padding: 12px 14px;
    border-radius: 12px;
    background: rgba(255,255,255,0.035);
    border: 1px solid var(--border);
    display: flex; flex-direction: column; gap: 8px;
  }
  .donate-card header { display: flex; align-items: center; gap: 10px; }
  .donate-icon {
    width: 30px; height: 30px;
    border-radius: 8px; display: grid; place-items: center;
  }
  .donate-card.pix .donate-icon { background: rgba(0, 201, 167, 0.14); color: #00C9A7; }
  .donate-card.paypal .donate-icon { background: rgba(77, 143, 255, 0.14); color: #4D8FFF; }
  .donate-card header b { font-size: 13px; color: #fff; }
  .pill { font-size: 9px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; color: #00C9A7; background: rgba(0,201,167,0.15); padding: 2px 7px; border-radius: 999px; margin-left: 6px; }
  .pill.blue { color: #4D8FFF; background: rgba(77,143,255,0.15); }
  .donate-card code { font-family: var(--font-mono); font-size: 11px; color: rgba(255,255,255,0.62); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  .copy {
    align-self: flex-start;
    padding: 5px 11px; border-radius: 999px;
    background: rgba(255,255,255,0.06); border: 1px solid var(--border);
    color: #fff; font-size: 11px; font-weight: 700;
  }
  .copy:hover { background: rgba(255,255,255,0.10); }
  .copy.on { color: var(--success); background: color-mix(in srgb, var(--success) 16%, transparent); border-color: color-mix(in srgb, var(--success) 32%, transparent); }

  /* === Buttons === */
  .ghost {
    padding: 8px 14px; border-radius: 9px;
    background: rgba(255,255,255,0.06); border: 1px solid var(--border);
    color: #fff; font-size: 12px; font-weight: 600;
  }
  .ghost:hover:not(:disabled) { background: rgba(255,255,255,0.10); }
  .ghost:disabled { opacity: 0.55; cursor: not-allowed; }
  .primary {
    padding: 9px 16px; border-radius: 9px;
    background: linear-gradient(135deg, var(--accent), var(--accent-2));
    color: #fff; font-size: 12px; font-weight: 700;
    box-shadow: 0 6px 14px rgba(139,107,248,0.30);
  }
  .primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 10px 20px rgba(139,107,248,0.40); }
  .primary:disabled { opacity: 0.5; cursor: not-allowed; }

  /* === Geral === */
  .row {
    display: grid; grid-template-columns: 1fr auto;
    align-items: center; gap: 16px;
    padding: 14px 0;
    border-top: 1px solid rgba(255,255,255,0.05);
  }
  .row:first-of-type { border-top: none; padding-top: 4px; }
  .row-text { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .row-title { font-size: 13px; color: #fff; font-weight: 500; }
  .row-desc { font-size: 11.5px; color: var(--text-secondary); }
  .row-desc code { background: rgba(255,255,255,0.06); padding: 1px 5px; border-radius: 4px; }

  .toggle {
    width: 34px; height: 20px; border-radius: 999px;
    background: rgba(255,255,255,0.10); position: relative;
    transition: background var(--dur-fast) var(--ease-out);
  }
  .toggle.on { background: var(--success); }
  .knob {
    position: absolute; top: 2px; left: 2px;
    width: 16px; height: 16px; border-radius: 999px;
    background: #fff;
    transition: transform var(--dur-fast) var(--ease-out);
  }
  .toggle.on .knob { transform: translateX(14px); }

  .seg { display: inline-flex; background: rgba(255,255,255,0.05); border: 1px solid var(--border); border-radius: 9px; padding: 2px; }
  .seg button { padding: 6px 12px; border-radius: 7px; font-size: 12px; color: var(--text-secondary); font-weight: 600; }
  .seg button.active { background: rgba(255,255,255,0.10); color: #fff; }

  /* === Sobre === */
  .about-body { display: flex; flex-direction: column; gap: 14px; }
  .about-brand { display: flex; align-items: center; gap: 12px; }
  .about-brand .logo {
    width: 36px; height: 36px; border-radius: 9px;
    object-fit: cover;
    box-shadow: 0 6px 16px rgba(139, 107, 248, 0.34);
  }
  .about-brand b { font-size: 15px; color: #fff; margin-right: 8px; }
  .about-brand span { font-size: 12.5px; color: var(--text-secondary); }
  .about-meta { display: grid; gap: 10px 22px; grid-template-columns: 1fr; }
  .about-meta dt { font-size: 10.5px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--text-muted); }
  .about-meta dd { font-size: 12.5px; color: #fff; }
  .link { color: var(--accent); font-size: 12.5px; font-family: var(--font-mono); }
  .link:hover { text-decoration: underline; }
</style>
