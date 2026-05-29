<script lang="ts">
  import { diskApi, type JunkEntry } from '$lib/services/system';
  import { formatBytes } from '$lib/services/format';

  type CategoryId = 'user-cache' | 'app-logs' | 'temp-files' | 'old-downloads' | 'trash' | 'dev-caches';

  interface CategoryDef {
    id: CategoryId;
    label: string;
    description: string;
    accent: string;
  }

  const CATEGORIES: CategoryDef[] = [
    { id: 'user-cache',   label: 'Caches de usuário',  description: '~/.cache — caches de aplicativos', accent: '#8B6BF8' },
    { id: 'app-logs',     label: 'Logs',                description: '~/.local/state — logs persistidos', accent: '#4D8FFF' },
    { id: 'temp-files',   label: 'Arquivos temporários',description: '/tmp, /var/tmp', accent: '#FF8C38' },
    { id: 'old-downloads',label: 'Downloads antigos',   description: 'Mais de 30 dias em ~/Downloads', accent: '#00C9A7' },
    { id: 'trash',        label: 'Lixeira',             description: 'Conteúdo de ~/.local/share/Trash', accent: '#FFB830' },
    { id: 'dev-caches',   label: 'Caches de devs',      description: 'pip, npm, yarn, cargo, go-build', accent: '#34C87A' }
  ];

  let selected = $state<Set<CategoryId>>(new Set(CATEGORIES.map((c) => c.id)));
  let scanning = $state(false);
  let cleaning = $state(false);
  let entries = $state<JunkEntry[]>([]);
  let totalBytes = $state(0);
  let recovered = $state<number | null>(null);

  function toggle(id: CategoryId) {
    const next = new Set(selected);
    if (next.has(id)) next.delete(id);
    else next.add(id);
    selected = next;
  }

  async function runScan() {
    scanning = true;
    recovered = null;
    try {
      const res = await diskApi.scanJunk([...selected]);
      entries = res.entries;
      totalBytes = res.total_bytes;
    } finally {
      scanning = false;
    }
  }

  async function runClean() {
    if (entries.length === 0) return;
    cleaning = true;
    try {
      recovered = await diskApi.clean(entries);
      entries = [];
      totalBytes = 0;
    } finally {
      cleaning = false;
    }
  }

  function bytesPerCategory(id: CategoryId): number {
    return entries.filter((e) => e.category === id).reduce((sum, e) => sum + e.size, 0);
  }
</script>

<div class="view">
  <header class="hero">
    <div>
      <h1 class="h-display">Disk Cleaner</h1>
      <p class="subtle">Remove caches, logs e arquivos desnecessários — sempre via lixeira, nunca rm -rf</p>
    </div>
    <div class="actions">
      <button class="btn btn-ghost" onclick={runScan} disabled={scanning || cleaning}>
        {scanning ? 'Escaneando…' : 'Escanear'}
      </button>
      <button
        class="btn btn-primary"
        onclick={runClean}
        disabled={cleaning || scanning || entries.length === 0}
      >
        {cleaning ? 'Movendo para lixeira…' : `Limpar ${formatBytes(totalBytes)}`}
      </button>
    </div>
  </header>

  {#if recovered !== null}
    <div class="banner success">{formatBytes(recovered)} recuperados — itens enviados para a lixeira</div>
  {/if}

  <section class="grid">
    {#each CATEGORIES as cat (cat.id)}
      {@const checked = selected.has(cat.id)}
      {@const catBytes = bytesPerCategory(cat.id)}
      <button
        class="cat"
        class:active={checked}
        style="--cat-accent: {cat.accent}"
        onclick={() => toggle(cat.id)}
      >
        <span class="check" class:on={checked}>
          {#if checked}
            <svg viewBox="0 0 16 16" width="11" height="11" fill="none" stroke="#0B0B1E" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
              <path d="M3 8.5l3 3 7-7" />
            </svg>
          {/if}
        </span>
        <div class="cat-body">
          <span class="cat-label">{cat.label}</span>
          <span class="cat-desc">{cat.description}</span>
        </div>
        <span class="cat-size mono">{catBytes > 0 ? formatBytes(catBytes) : '—'}</span>
      </button>
    {/each}
  </section>

  {#if entries.length > 0}
    <section class="entries glass">
      <header><h2 class="h-2">Itens encontrados</h2><span class="subtle">{entries.length} caminhos</span></header>
      <ul>
        {#each entries.slice(0, 80) as e}
          <li>
            <span class="path mono">{e.path}</span>
            <span class="size mono">{formatBytes(e.size)}</span>
          </li>
        {/each}
        {#if entries.length > 80}
          <li class="more subtle">…e mais {entries.length - 80} itens</li>
        {/if}
      </ul>
    </section>
  {/if}
</div>

<style>
  .view { padding: 28px 32px 40px; display: flex; flex-direction: column; gap: 22px; overflow-y: auto; height: 100%; }
  .hero { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; }
  .hero p { margin-top: 4px; font-size: 13px; }

  .actions { display: flex; gap: 10px; }
  .btn {
    padding: 10px 18px; border-radius: 10px; font-size: 13px; font-weight: 600;
    transition: transform var(--dur-fast) var(--ease-out), box-shadow var(--dur-fast) var(--ease-out), background var(--dur-fast) var(--ease-out);
  }
  .btn-ghost { background: rgba(255,255,255,0.06); border: 1px solid var(--border); color: #fff; }
  .btn-ghost:hover:not(:disabled) { background: rgba(255,255,255,0.10); }
  .btn-primary { background: linear-gradient(135deg, #FF8C38, #D85C10); color: #fff; box-shadow: 0 10px 22px rgba(255,140,56,0.35); }
  .btn-primary:hover:not(:disabled) { transform: translateY(-1px); box-shadow: 0 14px 28px rgba(255,140,56,0.45); }
  .btn:disabled { opacity: 0.55; cursor: not-allowed; }

  .banner {
    padding: 12px 16px;
    border-radius: 12px;
    font-weight: 600;
    font-size: 13px;
    background: color-mix(in srgb, var(--success) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--success) 30%, transparent);
    color: var(--success);
  }

  .grid { display: grid; grid-template-columns: repeat(2, 1fr); gap: 12px; }
  .cat {
    display: grid;
    grid-template-columns: auto 1fr auto;
    gap: 14px;
    align-items: center;
    padding: 16px 18px;
    border-radius: 14px;
    background: var(--card-bg);
    border: 1px solid var(--border);
    text-align: left;
    transition: border-color var(--dur-fast) var(--ease-out), background var(--dur-fast) var(--ease-out);
  }
  .cat:hover { background: var(--card-bg-strong); }
  .cat.active { border-color: color-mix(in srgb, var(--cat-accent) 50%, transparent); background: color-mix(in srgb, var(--cat-accent) 7%, var(--card-bg)); }
  .check {
    width: 22px; height: 22px; border-radius: 7px;
    background: rgba(255,255,255,0.06);
    border: 1px solid var(--border);
    display: grid; place-items: center;
    transition: background var(--dur-fast) var(--ease-out), border-color var(--dur-fast) var(--ease-out);
  }
  .check.on { background: var(--cat-accent); border-color: var(--cat-accent); }
  .cat-body { display: flex; flex-direction: column; gap: 2px; }
  .cat-label { font-size: 13px; font-weight: 600; color: #fff; }
  .cat-desc { font-size: 11.5px; color: var(--text-secondary); }
  .cat-size { font-size: 12px; color: var(--text-secondary); font-weight: 600; }

  .entries { padding: 16px 18px; }
  .entries header { display: flex; align-items: baseline; justify-content: space-between; margin-bottom: 10px; }
  .entries ul { list-style: none; max-height: 320px; overflow-y: auto; }
  .entries li {
    display: grid;
    grid-template-columns: 1fr 80px;
    gap: 12px;
    padding: 6px 6px;
    font-size: 11.5px;
  }
  .path { color: var(--text-secondary); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .size { text-align: right; color: #fff; }
  .more { color: var(--text-muted); text-align: center; padding-top: 8px; }
</style>
