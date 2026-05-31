<script lang="ts">
  import { revealItemInDir } from '@tauri-apps/plugin-opener';
  import { type FileKind } from '$lib/services/system';
  import { formatBytes } from '$lib/services/format';
  import { spaceLens } from '$lib/stores/spaceLens.svelte';

  const KIND_LABELS: Record<FileKind, string> = {
    video: 'Vídeos',
    audio: 'Áudio',
    image: 'Imagens',
    archive: 'Arquivos',
    document: 'Documentos',
    code: 'Código',
    binary: 'Binários',
    other: 'Outros'
  };
  const KIND_COLORS: Record<FileKind, string> = {
    video: '#FF8C38',
    audio: '#FFB830',
    image: '#34C87A',
    archive: '#4D8FFF',
    document: '#8B6BF8',
    code: '#00C9A7',
    binary: '#FF4D5E',
    other: '#9CA3AF'
  };

  // State lives in the store so it survives tab switches.
  const files = $derived(spaceLens.files);
  const scanning = $derived(spaceLens.scanning);
  const scanRoot = $derived(spaceLens.scanRoot);
  const filter = $derived(spaceLens.filter);

  const total = $derived(files.reduce((s, f) => s + f.size, 0));
  const filtered = $derived(
    filter.size === 0 ? files : files.filter((f) => filter.has(f.kind))
  );

  let revealError = $state<string | null>(null);

  // Slider works on a discrete set of human-friendly thresholds so dragging
  // feels meaningful (1 MB → 2 GB) instead of pixel-precise byte counts.
  const SIZE_STEPS = [1, 10, 50, 100, 250, 500, 1000, 2000];
  const sizeIndex = $derived(Math.max(0, SIZE_STEPS.indexOf(spaceLens.minSizeMb)));

  function onSizeInput(e: Event) {
    const idx = Number((e.target as HTMLInputElement).value);
    spaceLens.setMinSize(SIZE_STEPS[idx]);
  }
  function fmtSize(mb: number) {
    return mb >= 1000 ? `${(mb / 1000).toFixed(mb % 1000 === 0 ? 0 : 1)} GB` : `${mb} MB`;
  }

  async function reveal(path: string) {
    revealError = null;
    try {
      await revealItemInDir(path);
    } catch (e) {
      revealError = `Não foi possível abrir a pasta: ${e}`;
    }
  }

  function fileName(p: string) {
    const i = Math.max(p.lastIndexOf('/'), p.lastIndexOf('\\'));
    return i >= 0 ? p.slice(i + 1) : p;
  }
  function fileDir(p: string) {
    const i = Math.max(p.lastIndexOf('/'), p.lastIndexOf('\\'));
    return i >= 0 ? p.slice(0, i) : '';
  }
  function fmtDate(secs: number) {
    if (!secs) return '—';
    const d = new Date(secs * 1000);
    return d.toLocaleDateString();
  }
</script>

<div class="view">
  <header class="hero">
    <div>
      <h1 class="h-display">Space Lens</h1>
      <p class="subtle">Os 100 maiores arquivos no seu sistema — ignora &lt; 1 MB</p>
    </div>
    <div class="actions">
      <div class="seg">
        <button class:active={scanRoot === 'home'} onclick={() => spaceLens.setRoot('home')}>Home</button>
        <button class:active={scanRoot === 'root'} onclick={() => spaceLens.setRoot('root')}>Sistema</button>
      </div>
      <button class="btn btn-primary" onclick={() => spaceLens.scan()} disabled={scanning}>
        {scanning ? 'Escaneando…' : 'Escanear'}
      </button>
    </div>
  </header>

  {#if revealError}
    <div class="reveal-error">{revealError}</div>
  {/if}

  <section class="toolbar glass">
    <div class="size-control">
      <span class="size-label">Mín:</span>
      <input
        type="range"
        min="0"
        max={SIZE_STEPS.length - 1}
        step="1"
        value={sizeIndex}
        oninput={onSizeInput}
      />
      <span class="size-value mono">{fmtSize(spaceLens.minSizeMb)}</span>
    </div>
    <div class="kind-filters">
      <button class="kpill all" class:on={filter.size === 0} onclick={() => spaceLens.clearFilter()}>
        Todos
      </button>
      {#each Object.entries(KIND_LABELS) as [kind, label]}
        {@const k = kind as FileKind}
        <button
          class="kpill"
          class:on={filter.has(k)}
          style="--c: {KIND_COLORS[k]}"
          onclick={() => spaceLens.toggleKind(k)}
        >
          <span class="kpill-dot"></span>{label}
        </button>
      {/each}
    </div>
  </section>

  {#if files.length > 0}
    <section class="summary">
      <div class="total glass">
        <span class="subtle">Exibindo</span>
        <b class="mono">{formatBytes(filtered.reduce((s, f) => s + f.size, 0))}</b>
        <span class="subtle small">{filtered.length} de {files.length} arquivos · {formatBytes(total)} total</span>
      </div>
    </section>

    <section class="list glass">
      <ul>
        {#each filtered as f, i}
          <li>
            <button class="row-btn" onclick={() => reveal(f.path)} title="Abrir pasta do arquivo">
              <span class="rank">{i + 1}</span>
              <span class="kind-tag" style="--c: {KIND_COLORS[f.kind]}">{KIND_LABELS[f.kind]}</span>
              <div class="meta">
                <span class="fname">{fileName(f.path)}</span>
                <span class="fdir mono">{fileDir(f.path)}</span>
              </div>
              <span class="fdate mono">{fmtDate(f.modified_secs)}</span>
              <span class="fsize mono">{formatBytes(f.size)}</span>
              <span class="open-icon" aria-hidden="true">
                <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                  <path d="M3 7a2 2 0 0 1 2-2h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7z" />
                </svg>
              </span>
            </button>
          </li>
        {/each}
      </ul>
    </section>
  {:else if scanning}
    <section class="state glass">
      <p>Varrendo arquivos… pode levar alguns segundos em discos grandes.</p>
    </section>
  {:else}
    <section class="state glass">
      <p>Clique <b>Escanear</b> para encontrar os 100 maiores arquivos.</p>
    </section>
  {/if}
</div>

<style>
  .view { padding: 28px 32px 40px; display: flex; flex-direction: column; gap: 22px; overflow-y: auto; height: 100%; }
  .hero { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; }
  .hero p { margin-top: 4px; font-size: 13px; }
  .actions { display: flex; gap: 10px; align-items: center; }

  .seg { display: inline-flex; background: rgba(255,255,255,0.05); border: 1px solid var(--border); border-radius: 9px; padding: 2px; }
  .seg button { padding: 6px 12px; border-radius: 7px; font-size: 12px; color: var(--text-secondary); font-weight: 600; }
  .seg button.active { background: rgba(255,255,255,0.10); color: #fff; }

  .btn { padding: 10px 18px; border-radius: 10px; font-size: 13px; font-weight: 600; transition: transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out); }
  .btn-primary { background: linear-gradient(135deg, #00C9A7, #00957A); color: #fff; box-shadow: 0 10px 22px rgba(0,201,167,0.30); }
  .btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 14px 28px rgba(0,201,167,0.40); }
  .btn:disabled { opacity: 0.55; cursor: not-allowed; }

  /* Toolbar: size slider + type filters, always visible */
  .toolbar {
    display: flex;
    align-items: center;
    gap: 18px;
    padding: 12px 16px;
    flex-wrap: wrap;
  }
  .size-control { display: flex; align-items: center; gap: 10px; flex-shrink: 0; }
  .size-label { font-size: 12px; color: var(--text-secondary); font-weight: 600; }
  .size-value {
    font-size: 12.5px; color: #fff; font-weight: 700;
    min-width: 58px; text-align: right;
  }
  .size-control input[type="range"] {
    -webkit-appearance: none; appearance: none;
    width: 150px; height: 5px; border-radius: 999px;
    background: rgba(255,255,255,0.12);
    outline: none; cursor: pointer;
  }
  .size-control input[type="range"]::-webkit-slider-thumb {
    -webkit-appearance: none; appearance: none;
    width: 16px; height: 16px; border-radius: 999px;
    background: linear-gradient(135deg, #00C9A7, #00957A);
    box-shadow: 0 2px 6px rgba(0,201,167,0.5);
    cursor: pointer;
  }
  .size-control input[type="range"]::-moz-range-thumb {
    width: 16px; height: 16px; border: none; border-radius: 999px;
    background: linear-gradient(135deg, #00C9A7, #00957A);
    box-shadow: 0 2px 6px rgba(0,201,167,0.5);
    cursor: pointer;
  }

  .kind-filters { display: flex; flex-wrap: wrap; gap: 6px; }
  .kpill {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 5px 11px;
    border-radius: 999px;
    background: var(--card-bg);
    border: 1px solid var(--border);
    font-size: 11.5px; font-weight: 600;
    color: var(--text-secondary);
    transition: all var(--dur-fast) var(--ease-out);
  }
  .kpill:hover { background: var(--card-bg-strong); color: #fff; }
  .kpill.on { border-color: var(--c); background: color-mix(in srgb, var(--c) 14%, var(--card-bg)); color: #fff; }
  .kpill.all.on { border-color: var(--accent); background: color-mix(in srgb, var(--accent) 18%, var(--card-bg)); color: #fff; }
  .kpill-dot { width: 7px; height: 7px; border-radius: 999px; background: var(--c); }

  .summary { display: flex; }
  .total { padding: 14px 18px; display: flex; flex-direction: column; gap: 3px; min-width: 280px; }
  .total > span:first-child { font-size: 10.5px; letter-spacing: 0.06em; text-transform: uppercase; }
  .total b { font-size: 22px; color: #fff; font-weight: 700; }
  .total .small { font-size: 11px; text-transform: none; letter-spacing: 0; }

  .list { padding: 10px 0; }
  .list ul { list-style: none; }
  .list li { border-top: 1px solid rgba(255,255,255,0.04); }
  .list li:first-child { border-top: none; }
  .row-btn {
    width: 100%;
    display: grid;
    grid-template-columns: 28px 90px 1fr 100px 90px 22px;
    align-items: center;
    gap: 12px;
    padding: 9px 18px;
    font-size: 12px;
    text-align: left;
    background: none;
    border: none;
    color: inherit;
    cursor: pointer;
    transition: background var(--dur-fast) var(--ease-out);
  }
  .row-btn:hover { background: rgba(255,255,255,0.04); }
  .row-btn:hover .open-icon { opacity: 1; }
  .open-icon { color: var(--text-secondary); opacity: 0; transition: opacity var(--dur-fast) var(--ease-out); display: flex; justify-content: center; }
  .rank { color: var(--text-muted); font-variant-numeric: tabular-nums; font-size: 11px; text-align: right; }
  .kind-tag { font-size: 10px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; color: var(--c); }
  .meta { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
  .fname { color: #fff; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 12.5px; }
  .fdir { color: var(--text-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 11px; }
  .fdate { color: var(--text-secondary); font-size: 11px; }
  .fsize { color: #fff; text-align: right; font-weight: 600; }

  .state { padding: 60px 20px; text-align: center; color: var(--text-secondary); font-size: 13px; }
  .state b { color: #fff; }

  .reveal-error {
    padding: 10px 14px; border-radius: 10px; font-size: 12.5px; font-weight: 600;
    background: color-mix(in srgb, var(--danger) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--danger) 28%, transparent);
    color: var(--danger);
  }
</style>
