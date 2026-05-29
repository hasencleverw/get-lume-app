<script lang="ts">
  import CircularGauge from '$lib/components/CircularGauge.svelte';
  import { systemMetrics } from '$lib/stores/metrics.svelte';
  import { systemApi } from '$lib/services/system';
  import { formatBytes } from '$lib/services/format';

  const m = $derived(systemMetrics.metrics);
  const ramPct = $derived(m ? (m.ram_used / Math.max(1, m.ram_total)) * 100 : 0);

  let isWorking = $state(false);
  let freedBytes = $state<number | null>(null);
  let errorMsg = $state<string | null>(null);

  async function runFree() {
    isWorking = true;
    errorMsg = null;
    freedBytes = null;
    try {
      const res = await systemApi.freeMemory();
      freedBytes = res.freed;
      await systemMetrics.poll();
    } catch (e) {
      errorMsg = String(e);
    } finally {
      isWorking = false;
    }
  }
</script>

<div class="view">
  <header class="hero">
    <div>
      <h1 class="h-display">Memory Cleaner</h1>
      <p class="subtle">Libere RAM presa por caches do kernel e processos inativos</p>
    </div>
  </header>

  <section class="card glass">
    <div class="gauge-area">
      <CircularGauge value={ramPct} size={188} lineWidth={14} accent={['#4D8FFF', '#2D5FD0']} />
    </div>
    <div class="info">
      <div class="rows">
        <div><span class="subtle">Em uso</span><b class="mono">{m ? formatBytes(m.ram_used) : '—'}</b></div>
        <div><span class="subtle">Disponível</span><b class="mono">{m ? formatBytes(m.ram_available) : '—'}</b></div>
        <div><span class="subtle">Total</span><b class="mono">{m ? formatBytes(m.ram_total) : '—'}</b></div>
        <div><span class="subtle">Swap</span><b class="mono">{m ? `${formatBytes(m.swap_used)} / ${formatBytes(m.swap_total)}` : '—'}</b></div>
      </div>

      <button class="cta" onclick={runFree} disabled={isWorking}>
        {isWorking ? 'Liberando…' : 'Liberar memória'}
      </button>

      {#if freedBytes !== null}
        <p class="result success">{formatBytes(freedBytes)} liberados</p>
      {/if}
      {#if errorMsg}
        <p class="result danger">{errorMsg}</p>
      {/if}
      <p class="hint subtle">
        Requer autorização (pkexec). Lume executa <code class="mono">sync && echo 3 &gt; /proc/sys/vm/drop_caches</code>
        — uma operação segura recomendada pelo kernel.
      </p>
    </div>
  </section>
</div>

<style>
  .view { padding: 28px 32px 40px; display: flex; flex-direction: column; gap: 22px; overflow-y: auto; height: 100%; }
  .hero p { margin-top: 4px; font-size: 13px; }
  .card { padding: 28px; display: grid; grid-template-columns: auto 1fr; gap: 32px; align-items: center; }
  .info { display: flex; flex-direction: column; gap: 16px; }
  .rows { display: grid; grid-template-columns: 1fr 1fr; gap: 10px 26px; }
  .rows > div { display: flex; flex-direction: column; gap: 2px; }
  .rows span { font-size: 10.5px; letter-spacing: 0.06em; text-transform: uppercase; color: var(--text-muted); }
  .rows b { color: #fff; font-size: 14px; }
  .cta {
    align-self: flex-start;
    padding: 12px 22px;
    border-radius: 11px;
    color: #fff;
    font-weight: 600;
    background: linear-gradient(135deg, #4D8FFF, #2D5FD0);
    box-shadow: 0 10px 22px rgba(77, 143, 255, 0.35);
    transition: transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out);
  }
  .cta:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 14px 28px rgba(77, 143, 255, 0.45); }
  .cta:disabled { opacity: 0.65; cursor: not-allowed; }
  .result { font-size: 13px; font-weight: 600; }
  .result.success { color: var(--success); }
  .result.danger { color: var(--danger); }
  .hint { font-size: 11.5px; max-width: 50ch; line-height: 1.5; }
  .hint code { background: rgba(255,255,255,0.06); padding: 1px 5px; border-radius: 4px; font-size: 11px; }
</style>
