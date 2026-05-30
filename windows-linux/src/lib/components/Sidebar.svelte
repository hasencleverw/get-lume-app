<script lang="ts">
  import { SECTIONS, type SectionId } from '$lib/sections';
  import { navigation } from '$lib/stores/navigation.svelte';
  import { systemMetrics } from '$lib/stores/metrics.svelte';
  import { donation } from '$lib/stores/donation.svelte';
  import { updater } from '$lib/stores/updater.svelte';
  import { i18n } from '$lib/stores/i18n.svelte';
  import { formatPercent } from '$lib/services/format';

  const currentSection = $derived(navigation.current);

  const SECTION_LABEL_KEY: Record<SectionId, string> = {
    dashboard:   'sidebar.smartScan',
    memory:      'sidebar.memory',
    disk:        'sidebar.disk',
    space:       'sidebar.space',
    protection:  'sidebar.protection',
    apps:        'sidebar.apps',
    performance: 'sidebar.performance',
    settings:    'sidebar.settings'
  };

  const ramPct = $derived(
    systemMetrics.metrics
      ? (systemMetrics.metrics.ram_used / Math.max(1, systemMetrics.metrics.ram_total)) * 100
      : 0
  );
  const diskPct = $derived(
    systemMetrics.metrics
      ? (systemMetrics.metrics.disk_used / Math.max(1, systemMetrics.metrics.disk_total)) * 100
      : 0
  );
  const cpuPct = $derived(systemMetrics.metrics?.cpu_usage ?? 0);

  const issues = $derived.by(() => {
    const out: string[] = [];
    if (cpuPct >= 80) out.push(i18n.t('sidebar.issues.cpu'));
    if (ramPct >= 80) out.push(i18n.t('sidebar.issues.ram'));
    if (diskPct >= 90) out.push(i18n.t('sidebar.issues.disk'));
    return out;
  });
  const healthy = $derived(issues.length === 0);
</script>

<aside class="sidebar">
  <nav class="nav">
    {#each SECTIONS as section (section.id)}
      {@const active = currentSection === section.id}
      <button
        class="row"
        class:active
        style="--row-grad-1: {section.gradient[0]}; --row-grad-2: {section.gradient[1]}; --row-accent: {section.accent}"
        onclick={() => navigation.go(section.id)}
        title={section.label}
      >
        <span class="icon">
          <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
            <path d={section.iconPath} />
          </svg>
        </span>
        <span class="label">{i18n.t(SECTION_LABEL_KEY[section.id])}</span>
      </button>
    {/each}
  </nav>

  <div class="spacer"></div>

  {#if updater.shouldShowBanner}
    <button class="update-banner" onclick={() => updater.openRelease()} title={i18n.t('sidebar.tooltipUpdate')}>
      <span class="badge-icon">
        <svg viewBox="0 0 24 24" width="12" height="12" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
          <path d="M21 12a9 9 0 0 1-9 9 9 9 0 0 1-6.7-3" />
          <path d="M3 12a9 9 0 0 1 9-9 9 9 0 0 1 6.7 3" />
          <path d="M21 3v6h-6" />
          <path d="M3 21v-6h6" />
        </svg>
      </span>
      <div class="banner-body">
        <span class="banner-title">{i18n.t('sidebar.updateAvailable')}</span>
        <span class="banner-version">v{updater.status?.latest}</span>
      </div>
      <span
        class="banner-dismiss"
        role="button"
        tabindex="0"
        onclick={(e) => { e.stopPropagation(); updater.closeBanner(); }}
        onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.stopPropagation(); updater.closeBanner(); } }}
        title={i18n.t('sidebar.tooltipDismiss')}
      >×</span>
    </button>
  {/if}

  <div class="health" class:warn={!healthy}>
    <div class="row-head">
      <span class="dot" class:ok={healthy}></span>
      <span class="title">{i18n.t('sidebar.healthTitle')}</span>
      <span class="state">{healthy ? i18n.t('sidebar.healthOk') : i18n.t('sidebar.healthWarn')}</span>
    </div>
    {#if !healthy}
      <ul class="issues">
        {#each issues as issue}
          <li>{issue}</li>
        {/each}
      </ul>
    {/if}
    <div class="stats">
      <div><b class="mono">{formatPercent(cpuPct)}</b><span>{i18n.t('sidebar.cpu')}</span></div>
      <div><b class="mono">{formatPercent(ramPct)}</b><span>{i18n.t('sidebar.ram')}</span></div>
      <div><b class="mono">{formatPercent(diskPct)}</b><span>{i18n.t('sidebar.disk_short')}</span></div>
    </div>
  </div>

  <button class="footer-btn donate" type="button" onclick={() => donation.openManually()} title={donation.state.has_donated ? '❤️' : i18n.t('sidebar.donate')}>
    <svg viewBox="0 0 24 24" width="14" height="14" fill={donation.state.has_donated ? '#FF6B9D' : 'none'} stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
      <path d="M12 21s-7-4.35-9.5-9.5C.5 7 4 3 7 3c2 0 3.5 1 5 3 1.5-2 3-3 5-3 3 0 6.5 4 4.5 8.5C19 16.65 12 21 12 21z" />
    </svg>
    <span>{donation.state.has_donated ? i18n.t('sidebar.donor') : i18n.t('sidebar.donate')}</span>
  </button>

  <button class="footer-btn" class:active={currentSection === 'settings'} type="button" onclick={() => navigation.go('settings')}>
    <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round">
      <circle cx="12" cy="12" r="3" />
      <path d="M19.4 15a1.7 1.7 0 0 0 .3 1.9l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.7 1.7 0 0 0-1.9-.3 1.7 1.7 0 0 0-1 1.5V21a2 2 0 1 1-4 0v-.1a1.7 1.7 0 0 0-1.1-1.5 1.7 1.7 0 0 0-1.9.3l-.1.1A2 2 0 1 1 4 16.9l.1-.1a1.7 1.7 0 0 0 .3-1.9 1.7 1.7 0 0 0-1.5-1H2.9a2 2 0 1 1 0-4H3a1.7 1.7 0 0 0 1.5-1.1 1.7 1.7 0 0 0-.3-1.9l-.1-.1a2 2 0 1 1 2.8-2.8l.1.1a1.7 1.7 0 0 0 1.9.3H9a1.7 1.7 0 0 0 1-1.5V2.9a2 2 0 1 1 4 0V3a1.7 1.7 0 0 0 1 1.5 1.7 1.7 0 0 0 1.9-.3l.1-.1a2 2 0 1 1 2.8 2.8l-.1.1a1.7 1.7 0 0 0-.3 1.9V9a1.7 1.7 0 0 0 1.5 1H21a2 2 0 1 1 0 4h-.1a1.7 1.7 0 0 0-1.5 1z" />
    </svg>
    <span>{i18n.t('sidebar.settings')}</span>
  </button>
</aside>

<style>
  .sidebar {
    flex: 0 0 var(--sidebar-w);
    width: var(--sidebar-w);
    height: 100%;
    background: var(--sidebar-bg);
    border-right: 1px solid var(--border);
    padding: 14px 12px 12px;
    display: flex;
    flex-direction: column;
    position: relative;
    z-index: 2;
  }

  .nav { display: flex; flex-direction: column; gap: 1px; padding: 4px 0; }
  .row {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 6px 8px;
    border-radius: 10px;
    color: var(--text-muted);
    transition: background var(--dur-fast) var(--ease-out), color var(--dur-fast) var(--ease-out);
    text-align: left;
    width: 100%;
  }
  .row:hover { background: rgba(255, 255, 255, 0.04); color: rgba(255, 255, 255, 0.78); }
  .row .icon {
    width: 28px; height: 28px;
    border-radius: 8px;
    background: transparent;
    display: grid; place-items: center;
    color: inherit;
    transition: background var(--dur-fast) var(--ease-out), color var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out);
  }
  .row.active {
    background: rgba(255, 255, 255, 0.05);
    color: #fff;
  }
  .row.active .icon {
    background: linear-gradient(135deg, var(--row-grad-1), var(--row-grad-2));
    color: #fff;
    box-shadow: 0 6px 14px color-mix(in srgb, var(--row-accent) 32%, transparent);
  }
  .label { font-size: 12.5px; font-weight: 500; }
  .row.active .label { font-weight: 600; }

  .spacer { flex: 1; }

  .health {
    background: rgba(255, 255, 255, 0.04);
    border: 1px solid var(--border);
    border-radius: 12px;
    padding: 10px 11px;
    margin: 0 2px 8px;
    display: flex; flex-direction: column; gap: 8px;
  }
  .row-head { display: flex; align-items: center; gap: 6px; font-size: 10px; }
  .row-head .title { color: var(--text-secondary); flex: 1; text-transform: uppercase; letter-spacing: 0.06em; font-weight: 600; }
  .row-head .state { color: var(--success); font-weight: 700; font-size: 10px; }
  .health.warn .row-head .state { color: var(--warning); }
  .dot { width: 7px; height: 7px; border-radius: 999px; background: var(--warning); box-shadow: 0 0 8px var(--warning); }
  .dot.ok { background: var(--success); box-shadow: 0 0 8px var(--success); }

  .issues { list-style: none; padding: 0; margin: 0; display: flex; flex-direction: column; gap: 2px; }
  .issues li {
    font-size: 10px;
    color: color-mix(in srgb, var(--warning) 86%, white);
  }

  .stats { display: flex; gap: 6px; justify-content: space-between; }
  .stats > div { display: flex; flex-direction: column; align-items: center; gap: 1px; }
  .stats b { font-size: 12px; font-weight: 700; color: #fff; }
  .stats span { font-size: 9px; color: var(--text-muted); letter-spacing: 0.04em; text-transform: uppercase; }

  .footer-btn {
    display: flex; align-items: center; gap: 8px;
    padding: 8px 10px;
    color: var(--text-secondary);
    border-radius: 9px;
    font-size: 12px;
    text-align: left;
    width: 100%;
  }
  .footer-btn:hover { color: #fff; background: rgba(255, 255, 255, 0.04); }
  .footer-btn.donate:hover { color: #FF6B9D; }
  .footer-btn.active { color: #fff; background: rgba(255, 255, 255, 0.06); }

  .update-banner {
    display: grid;
    grid-template-columns: auto 1fr auto;
    gap: 10px;
    align-items: center;
    margin: 0 2px 10px;
    padding: 9px 11px;
    border-radius: 10px;
    background: linear-gradient(135deg, color-mix(in srgb, var(--accent) 14%, transparent), color-mix(in srgb, var(--accent-2) 10%, transparent));
    border: 1px solid color-mix(in srgb, var(--accent) 32%, transparent);
    text-align: left;
    cursor: pointer;
    transition: transform var(--dur-fast) var(--ease-out), background var(--dur-fast) var(--ease-out);
  }
  .update-banner:hover { transform: translateY(-1px); background: linear-gradient(135deg, color-mix(in srgb, var(--accent) 22%, transparent), color-mix(in srgb, var(--accent-2) 16%, transparent)); }
  .badge-icon {
    width: 22px; height: 22px;
    border-radius: 6px;
    background: var(--accent);
    color: #fff;
    display: grid; place-items: center;
    box-shadow: 0 4px 10px rgba(139, 107, 248, 0.32);
  }
  .banner-body { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
  .banner-title { font-size: 10.5px; color: var(--text-secondary); font-weight: 600; letter-spacing: 0.02em; }
  .banner-version { font-size: 12px; color: #fff; font-weight: 700; font-variant-numeric: tabular-nums; }
  .banner-dismiss {
    width: 18px; height: 18px;
    display: grid; place-items: center;
    border-radius: 5px;
    color: var(--text-muted);
    font-size: 14px; line-height: 1;
    transition: background var(--dur-fast) var(--ease-out), color var(--dur-fast) var(--ease-out);
  }
  .banner-dismiss:hover { background: rgba(255, 255, 255, 0.08); color: #fff; }
</style>
