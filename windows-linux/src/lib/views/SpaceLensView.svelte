<script lang="ts">
  import { largeFilesApi, type BigFile, type FileKind } from '$lib/services/system';
  import { formatBytes } from '$lib/services/format';

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

  let scanning = $state(false);
  let files = $state<BigFile[]>([]);
  let filter = $state<Set<FileKind>>(new Set());
  let scanRoot = $state<'home' | 'root'>('home');

  const total = $derived(files.reduce((s, f) => s + f.size, 0));
  const filtered = $derived(
    filter.size === 0 ? files : files.filter((f) => filter.has(f.kind))
  );

  async function run() {
    scanning = true;
    try {
      const root = scanRoot === 'root' ? '/' : null;
      files = await largeFilesApi.scan(root, 100, []);
    } finally {
      scanning = false;
    }
  }

  function toggleKind(k: FileKind) {
    const next = new Set(filter);
    if (next.has(k)) next.delete(k);
    else next.add(k);
    filter = next;
  }

  function countOf(k: FileKind): number {
    return files.filter((f) => f.kind === k).length;
  }
  function bytesOf(k: FileKind): number {
    return files.filter((f) => f.kind === k).reduce((s, f) => s + f.size, 0);
  }

  function fileName(p: string) {
    const i = p.lastIndexOf('/');
    return i >= 0 ? p.slice(i + 1) : p;
  }
  function fileDir(p: string) {
    const i = p.lastIndexOf('/');
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
        <button class:active={scanRoot === 'home'} onclick={() => (scanRoot = 'home')}>Home</button>
        <button class:active={scanRoot === 'root'} onclick={() => (scanRoot = 'root')}>Sistema</button>
      </div>
      <button class="btn btn-primary" onclick={run} disabled={scanning}>
        {scanning ? 'Escaneando…' : 'Escanear'}
      </button>
    </div>
  </header>

  {#if files.length > 0}
    <section class="summary">
      <div class="total glass">
        <span class="subtle">Total nos 100 maiores</span>
        <b class="mono">{formatBytes(total)}</b>
      </div>
      <div class="kinds">
        {#each Object.entries(KIND_LABELS) as [kind, label]}
          {@const k = kind as FileKind}
          {@const n = countOf(k)}
          {@const bz = bytesOf(k)}
          {#if n > 0}
            <button
              class="kind"
              class:on={filter.has(k)}
              style="--c: {KIND_COLORS[k]}"
              onclick={() => toggleKind(k)}
            >
              <span class="kind-dot"></span>
              <span class="kind-label">{label}</span>
              <span class="kind-meta mono">{n} · {formatBytes(bz)}</span>
            </button>
          {/if}
        {/each}
      </div>
    </section>

    <section class="list glass">
      <ul>
        {#each filtered as f, i}
          <li>
            <span class="rank">{i + 1}</span>
            <span class="kind-tag" style="--c: {KIND_COLORS[f.kind]}">{KIND_LABELS[f.kind]}</span>
            <div class="meta">
              <span class="fname">{fileName(f.path)}</span>
              <span class="fdir mono">{fileDir(f.path)}</span>
            </div>
            <span class="fdate mono">{fmtDate(f.modified_secs)}</span>
            <span class="fsize mono">{formatBytes(f.size)}</span>
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

  .summary { display: grid; grid-template-columns: 220px 1fr; gap: 14px; }
  .total { padding: 14px 18px; display: flex; flex-direction: column; gap: 4px; }
  .total span { font-size: 10.5px; letter-spacing: 0.06em; text-transform: uppercase; }
  .total b { font-size: 22px; color: #fff; font-weight: 700; }

  .kinds { display: flex; flex-wrap: wrap; gap: 8px; }
  .kind {
    display: inline-flex; align-items: center; gap: 8px;
    padding: 7px 12px;
    border-radius: 999px;
    background: var(--card-bg);
    border: 1px solid var(--border);
    font-size: 12px;
    color: var(--text-secondary);
    transition: all var(--dur-fast) var(--ease-out);
  }
  .kind:hover { background: var(--card-bg-strong); color: #fff; }
  .kind.on { border-color: var(--c); background: color-mix(in srgb, var(--c) 12%, var(--card-bg)); color: #fff; }
  .kind-dot { width: 7px; height: 7px; border-radius: 999px; background: var(--c); }
  .kind-label { font-weight: 600; }
  .kind-meta { font-size: 11px; color: var(--text-muted); }

  .list { padding: 10px 0; }
  .list ul { list-style: none; }
  .list li {
    display: grid;
    grid-template-columns: 28px 90px 1fr 100px 90px;
    align-items: center;
    gap: 12px;
    padding: 9px 18px;
    font-size: 12px;
    border-top: 1px solid rgba(255,255,255,0.04);
  }
  .list li:first-child { border-top: none; }
  .list li:hover { background: rgba(255,255,255,0.03); }
  .rank { color: var(--text-muted); font-variant-numeric: tabular-nums; font-size: 11px; text-align: right; }
  .kind-tag { font-size: 10px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase; color: var(--c); }
  .meta { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
  .fname { color: #fff; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 12.5px; }
  .fdir { color: var(--text-muted); overflow: hidden; text-overflow: ellipsis; white-space: nowrap; font-size: 11px; }
  .fdate { color: var(--text-secondary); font-size: 11px; }
  .fsize { color: #fff; text-align: right; font-weight: 600; }

  .state { padding: 60px 20px; text-align: center; color: var(--text-secondary); font-size: 13px; }
  .state b { color: #fff; }
</style>
