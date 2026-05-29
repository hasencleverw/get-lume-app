<script lang="ts">
  import { protectionApi, type Finding, type Severity } from '$lib/services/system';

  const SEV_COLOR: Record<Severity, string> = {
    info: '#9CA3AF', low: '#4D8FFF', medium: '#FFB830', high: '#FF4D5E'
  };
  const SEV_LABEL: Record<Severity, string> = {
    info: 'Info', low: 'Baixo', medium: 'Médio', high: 'Alto'
  };
  const KIND_LABEL = {
    'autostart': 'Autostart',
    'binary': 'Binário',
    'browser-ext': 'Extensão',
    'systemd-unit': 'systemd'
  };

  let scanning = $state(false);
  let scanned = $state(false);
  let findings = $state<Finding[]>([]);
  let itemsScanned = $state(0);
  let elapsedMs = $state(0);

  async function run() {
    scanning = true;
    try {
      const r = await protectionApi.scan();
      findings = r.findings;
      itemsScanned = r.items_scanned;
      elapsedMs = r.took_ms;
      scanned = true;
    } finally {
      scanning = false;
    }
  }

  const highCount = $derived(findings.filter((f) => f.severity === 'high').length);
  const medCount = $derived(findings.filter((f) => f.severity === 'medium').length);
  const lowCount = $derived(findings.filter((f) => f.severity === 'low').length);
  const overall = $derived.by(() => {
    if (!scanned) return 'pending';
    if (highCount > 0) return 'risk';
    if (medCount > 0) return 'attention';
    return 'safe';
  });
</script>

<div class="view">
  <header class="hero">
    <div>
      <h1 class="h-display">Protection</h1>
      <p class="subtle">
        {scanned
          ? `${itemsScanned} itens verificados em ${(elapsedMs / 1000).toFixed(1)}s`
          : 'Detecta autostarts suspeitos, binários conhecidos e extensões fora do padrão'}
      </p>
    </div>
    <button class="btn btn-primary" onclick={run} disabled={scanning}>
      {scanning ? 'Escaneando…' : scanned ? 'Re-escanear' : 'Escanear agora'}
    </button>
  </header>

  {#if scanned}
    <section class="overall" class:safe={overall === 'safe'} class:attention={overall === 'attention'} class:risk={overall === 'risk'}>
      <div class="badge">
        {#if overall === 'safe'}
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M5 13l4 4L19 7" />
          </svg>
        {:else}
          <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="M10.3 3.7L1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3l-8.5-14.3a2 2 0 0 0-3.4 0z" />
            <path d="M12 9v4M12 17h.01" />
          </svg>
        {/if}
      </div>
      <div class="overall-text">
        {#if overall === 'safe'}
          <h2 class="h-2">Sistema saudável</h2>
          <p class="subtle">Nenhum sinal de comprometimento encontrado.</p>
        {:else if overall === 'attention'}
          <h2 class="h-2">Atenção</h2>
          <p class="subtle">{medCount + lowCount} pontos para revisar — nenhum crítico.</p>
        {:else}
          <h2 class="h-2">Ação recomendada</h2>
          <p class="subtle">{highCount} achado(s) crítico(s) — revise imediatamente.</p>
        {/if}
      </div>
      <div class="counters">
        <div><b class="mono" style="color: #FF4D5E">{highCount}</b><span>Crítico</span></div>
        <div><b class="mono" style="color: #FFB830">{medCount}</b><span>Médio</span></div>
        <div><b class="mono" style="color: #4D8FFF">{lowCount}</b><span>Baixo</span></div>
      </div>
    </section>
  {/if}

  {#if findings.length > 0}
    <section class="list glass">
      <ul>
        {#each findings as f}
          <li>
            <span class="sev" style="--c: {SEV_COLOR[f.severity]}">{SEV_LABEL[f.severity]}</span>
            <span class="kind">{KIND_LABEL[f.kind] ?? f.kind}</span>
            <div class="meta">
              <span class="title">{f.title}</span>
              <span class="detail">{f.detail}</span>
              {#if f.path}<span class="path mono">{f.path}</span>{/if}
              <span class="rec">→ {f.recommendation}</span>
            </div>
          </li>
        {/each}
      </ul>
    </section>
  {:else if scanned}
    <section class="state glass">
      <p>Nada suspeito encontrado. Volte amanhã pra um novo scan ou após instalar algo novo.</p>
    </section>
  {:else}
    <section class="state glass">
      <p>Clique <b>Escanear agora</b> para verificar autostarts, binários conhecidos e extensões de navegador.</p>
    </section>
  {/if}
</div>

<style>
  .view { padding: 28px 32px 40px; display: flex; flex-direction: column; gap: 18px; overflow-y: auto; height: 100%; }
  .hero { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; }
  .hero p { margin-top: 4px; font-size: 13px; }

  .btn { padding: 10px 18px; border-radius: 10px; font-size: 13px; font-weight: 600; transition: transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out); }
  .btn-primary { background: linear-gradient(135deg, #FF4D5E, #CC2035); color: #fff; box-shadow: 0 10px 22px rgba(255,77,94,0.30); }
  .btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 14px 28px rgba(255,77,94,0.40); }
  .btn:disabled { opacity: 0.55; cursor: not-allowed; }

  .overall {
    display: grid; grid-template-columns: auto 1fr auto; gap: 22px; align-items: center;
    padding: 22px 26px;
    border-radius: 16px;
    background: var(--card-bg-strong);
    border: 1px solid var(--border);
  }
  .overall.safe { background: color-mix(in srgb, var(--success) 10%, var(--card-bg-strong)); border-color: color-mix(in srgb, var(--success) 28%, transparent); }
  .overall.safe .badge { color: var(--success); }
  .overall.attention { background: color-mix(in srgb, var(--warning) 10%, var(--card-bg-strong)); border-color: color-mix(in srgb, var(--warning) 28%, transparent); }
  .overall.attention .badge { color: var(--warning); }
  .overall.risk { background: color-mix(in srgb, var(--danger) 10%, var(--card-bg-strong)); border-color: color-mix(in srgb, var(--danger) 28%, transparent); }
  .overall.risk .badge { color: var(--danger); }

  .badge { width: 42px; height: 42px; border-radius: 12px; display: grid; place-items: center; background: rgba(255,255,255,0.06); }
  .overall-text h2 { color: #fff; margin-bottom: 2px; }

  .counters { display: flex; gap: 18px; }
  .counters > div { display: flex; flex-direction: column; align-items: center; gap: 2px; }
  .counters b { font-size: 22px; font-weight: 700; }
  .counters span { font-size: 10px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.06em; }

  .list { padding: 6px 0; }
  .list ul { list-style: none; }
  .list li {
    display: grid;
    grid-template-columns: 70px 90px 1fr;
    gap: 14px;
    align-items: flex-start;
    padding: 14px 18px;
    border-top: 1px solid rgba(255,255,255,0.04);
  }
  .list li:first-child { border-top: none; }
  .sev {
    font-size: 10px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase;
    color: var(--c);
    padding: 3px 8px; border-radius: 6px;
    background: color-mix(in srgb, var(--c) 14%, transparent);
    text-align: center;
    align-self: flex-start;
    margin-top: 2px;
  }
  .kind { font-size: 11px; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.04em; align-self: flex-start; margin-top: 6px; }
  .meta { display: flex; flex-direction: column; gap: 3px; min-width: 0; }
  .title { font-size: 13px; font-weight: 600; color: #fff; }
  .detail { font-size: 12px; color: var(--text-secondary); }
  .path { font-size: 11px; color: var(--text-muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .rec { font-size: 12px; color: var(--accent); margin-top: 4px; }

  .state { padding: 60px 20px; text-align: center; color: var(--text-secondary); font-size: 13px; }
  .state b { color: #fff; }
</style>
