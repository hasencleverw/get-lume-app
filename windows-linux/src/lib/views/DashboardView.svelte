<script lang="ts">
  import CircularGauge from '$lib/components/CircularGauge.svelte';
  import LineChart from '$lib/components/LineChart.svelte';
  import { systemMetrics } from '$lib/stores/metrics.svelte';
  import { formatBytes, formatUptime, formatPercent } from '$lib/services/format';
  import { sectionById } from '$lib/sections';

  const m = $derived(systemMetrics.metrics);
  const host = $derived(systemMetrics.host);
  const procs = $derived(systemMetrics.processes);

  const ramPct = $derived(m ? (m.ram_used / Math.max(1, m.ram_total)) * 100 : 0);
  const diskPct = $derived(m ? (m.disk_used / Math.max(1, m.disk_total)) * 100 : 0);
  const cpuPct = $derived(m?.cpu_usage ?? 0);
  const healthy = $derived(cpuPct < 80 && ramPct < 80 && diskPct < 90);

  function trendColor(v: number): string {
    if (v >= 80) return 'var(--danger)';
    if (v >= 60) return 'var(--warning)';
    return 'var(--success)';
  }
</script>

<div class="dash">
  <header class="hero">
    <div>
      <h1 class="h-display">Smart Scan</h1>
      <p class="subtitle subtle">Diagnóstico completo do seu sistema</p>
    </div>
    <span class="status-pill" class:warn={!healthy}>
      <span class="dot"></span>
      {healthy ? 'Saudável' : 'Atenção'}
    </span>
  </header>

  <section class="metrics-row">
    {#each [
      { id: 'dashboard', title: 'CPU', value: cpuPct, sub: m ? `${m.cpu_cores} núcleos` : '—', accent: sectionById('dashboard').gradient },
      { id: 'memory',    title: 'Memória', value: ramPct, sub: m ? `${formatBytes(m.ram_used)} / ${formatBytes(m.ram_total)}` : '—', accent: sectionById('memory').gradient },
      { id: 'disk',      title: 'Disco', value: diskPct, sub: m ? `${formatBytes(m.disk_free)} livres` : '—', accent: sectionById('disk').gradient }
    ] as tile (tile.id)}
      <article class="tile glass">
        <header>
          <span class="tile-title">{tile.title}</span>
          <span class="tile-trend" style="--c: {trendColor(tile.value)}"></span>
        </header>
        <div class="tile-gauge">
          <CircularGauge value={tile.value} size={132} lineWidth={11} accent={tile.accent as [string, string]} />
        </div>
        <footer class="tile-sub">{tile.sub}</footer>
      </article>
    {/each}
  </section>

  <section class="charts">
    <article class="chart-card glass">
      <header>
        <span class="chart-title">Uso de CPU</span>
        <span class="chart-value mono">{formatPercent(cpuPct, 1)}</span>
      </header>
      <div class="chart-area">
        <LineChart values={systemMetrics.history.cpu} color="#4D8FFF" />
      </div>
    </article>
    <article class="chart-card glass">
      <header>
        <span class="chart-title">Uso de RAM</span>
        <span class="chart-value mono">{formatPercent(ramPct, 1)}</span>
      </header>
      <div class="chart-area">
        <LineChart values={systemMetrics.history.ram} color="#8B6BF8" />
      </div>
    </article>
  </section>

  <section class="grid-2">
    <article class="card glass">
      <header class="card-head">
        <h2 class="h-2">Top processos</h2>
        <span class="subtle">Por uso composto</span>
      </header>
      <ul class="proc-list">
        {#each procs as p}
          <li>
            <span class="proc-name">{p.name}</span>
            <span class="proc-cpu mono">{p.cpu_usage.toFixed(1)}%</span>
            <span class="proc-mem mono">{formatBytes(p.memory)}</span>
          </li>
        {/each}
        {#if procs.length === 0}
          <li class="empty subtle">Coletando…</li>
        {/if}
      </ul>
    </article>

    <article class="card glass">
      <header class="card-head"><h2 class="h-2">Sistema</h2></header>
      <dl class="meta">
        <div><dt>SO</dt><dd>{host?.os_name ?? '—'} {host?.os_version ?? ''}</dd></div>
        <div><dt>Kernel</dt><dd class="mono">{host?.kernel ?? '—'}</dd></div>
        <div><dt>Host</dt><dd class="mono">{host?.hostname ?? '—'}</dd></div>
        <div><dt>Arquitetura</dt><dd class="mono">{host?.arch ?? '—'}</dd></div>
        <div><dt>Uptime</dt><dd class="mono">{m ? formatUptime(m.uptime_seconds) : '—'}</dd></div>
        <div><dt>Swap</dt><dd class="mono">{m ? `${formatBytes(m.swap_used)} / ${formatBytes(m.swap_total)}` : '—'}</dd></div>
      </dl>
    </article>
  </section>
</div>

<style>
  .dash {
    padding: 28px 32px 40px;
    display: flex;
    flex-direction: column;
    gap: 22px;
    overflow-y: auto;
    height: 100%;
  }

  .hero {
    display: flex;
    align-items: flex-end;
    justify-content: space-between;
    gap: 16px;
  }
  .hero p { margin-top: 4px; font-size: 13px; }

  .status-pill {
    display: inline-flex;
    align-items: center;
    gap: 8px;
    padding: 6px 12px;
    border-radius: 999px;
    font-size: 12px;
    font-weight: 600;
    color: var(--success);
    background: color-mix(in srgb, var(--success) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--success) 28%, transparent);
  }
  .status-pill .dot { width: 7px; height: 7px; border-radius: 999px; background: var(--success); box-shadow: 0 0 8px var(--success); }
  .status-pill.warn { color: var(--warning); background: color-mix(in srgb, var(--warning) 14%, transparent); border-color: color-mix(in srgb, var(--warning) 30%, transparent); }
  .status-pill.warn .dot { background: var(--warning); box-shadow: 0 0 8px var(--warning); }

  .metrics-row { display: grid; grid-template-columns: repeat(3, 1fr); gap: 14px; }
  .tile {
    padding: 18px 18px 16px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 14px;
    background: var(--card-bg);
  }
  .tile header { width: 100%; display: flex; align-items: center; justify-content: space-between; }
  .tile-title { font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; color: var(--text-secondary); }
  .tile-trend { width: 7px; height: 7px; border-radius: 999px; background: var(--c); box-shadow: 0 0 8px var(--c); }
  .tile-sub { font-size: 11.5px; color: var(--text-secondary); }
  .tile-gauge { padding-top: 4px; }

  .charts { display: grid; grid-template-columns: repeat(2, 1fr); gap: 14px; }
  .chart-card { padding: 16px 18px 14px; }
  .chart-card header { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 8px; }
  .chart-title { font-size: 11px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--text-secondary); font-weight: 600; }
  .chart-value { font-size: 15px; color: #fff; font-weight: 700; }
  .chart-area { height: 56px; }

  .grid-2 { display: grid; grid-template-columns: 1.4fr 1fr; gap: 14px; }
  .card { padding: 16px 18px; }
  .card-head { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 10px; }

  .proc-list { list-style: none; display: flex; flex-direction: column; gap: 2px; }
  .proc-list li {
    display: grid;
    grid-template-columns: 1fr 64px 84px;
    align-items: center;
    padding: 7px 6px;
    border-radius: 8px;
    font-size: 12px;
  }
  .proc-list li:hover { background: rgba(255,255,255,0.04); }
  .proc-name { color: #fff; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .proc-cpu, .proc-mem { color: var(--text-secondary); text-align: right; font-size: 11.5px; }
  .empty { padding: 14px 8px; }

  .meta { display: grid; grid-template-columns: 1fr 1fr; gap: 12px 18px; }
  .meta > div { display: flex; flex-direction: column; gap: 2px; }
  .meta dt { font-size: 10.5px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--text-muted); }
  .meta dd { font-size: 13px; color: #fff; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
</style>
