<script lang="ts">
  import { appsApi, type AppEntry, type AppSource } from '$lib/services/system';
  import { formatBytes } from '$lib/services/format';

  const SOURCE_LABEL: Record<AppSource, string> = {
    pacman: 'pacman', dpkg: 'apt', rpm: 'dnf',
    flatpak: 'flatpak', snap: 'snap', desktop: '.desktop', windows: 'Windows'
  };
  const SOURCE_COLOR: Record<AppSource, string> = {
    pacman: '#1793D1', dpkg: '#E95420', rpm: '#3C6EB4',
    flatpak: '#4A90D9', snap: '#82BEA0', desktop: '#9CA3AF', windows: '#0078D4'
  };

  let loading = $state(true);
  let apps = $state<AppEntry[]>([]);
  let q = $state('');
  let activeSource = $state<AppSource | 'all'>('all');
  let working = $state<string | null>(null);
  let error = $state<string | null>(null);

  async function load() {
    loading = true;
    try {
      apps = await appsApi.list();
    } finally {
      loading = false;
    }
  }
  load();

  const filtered = $derived.by(() => {
    let list = apps;
    if (activeSource !== 'all') list = list.filter((a) => a.source === activeSource);
    if (q.trim()) {
      const needle = q.toLowerCase();
      list = list.filter((a) =>
        a.name.toLowerCase().includes(needle) ||
        a.description?.toLowerCase().includes(needle)
      );
    }
    return list;
  });

  const totalSize = $derived(apps.reduce((s, a) => s + a.size_bytes, 0));
  const sourceCounts = $derived.by(() => {
    const c = new Map<AppSource, number>();
    for (const a of apps) c.set(a.source, (c.get(a.source) ?? 0) + 1);
    return c;
  });

  async function remove(a: AppEntry) {
    if (!confirm(`Desinstalar "${a.name}"?`)) return;
    working = a.id;
    error = null;
    try {
      await appsApi.uninstall(a.source, a.id);
      apps = apps.filter((x) => !(x.source === a.source && x.id === a.id));
    } catch (e) {
      error = String(e);
    } finally {
      working = null;
    }
  }
</script>

<div class="view">
  <header class="hero">
    <div>
      <h1 class="h-display">Applications</h1>
      <p class="subtle">{apps.length} aplicativos · {formatBytes(totalSize)}</p>
    </div>
    <input type="search" bind:value={q} placeholder="Buscar aplicativos…" class="search" />
  </header>

  <nav class="tabs">
    <button class="tab" class:active={activeSource === 'all'} onclick={() => (activeSource = 'all')}>
      Todos <span class="count">{apps.length}</span>
    </button>
    {#each [...sourceCounts.entries()] as [src, count]}
      <button
        class="tab"
        class:active={activeSource === src}
        style="--c: {SOURCE_COLOR[src]}"
        onclick={() => (activeSource = src)}
      >
        <span class="dot" style="background: {SOURCE_COLOR[src]}"></span>
        {SOURCE_LABEL[src]}
        <span class="count">{count}</span>
      </button>
    {/each}
  </nav>

  {#if error}
    <div class="banner danger">{error}</div>
  {/if}

  {#if loading}
    <section class="state glass"><p>Coletando aplicativos…</p></section>
  {:else}
    <section class="list glass">
      <ul>
        {#each filtered.slice(0, 200) as a (a.source + ':' + a.id)}
          <li>
            <span class="src-tag" style="--c: {SOURCE_COLOR[a.source]}">{SOURCE_LABEL[a.source]}</span>
            <div class="meta">
              <span class="name">{a.name}</span>
              {#if a.description}<span class="desc">{a.description}</span>{/if}
            </div>
            <span class="ver mono">{a.version ?? ''}</span>
            <span class="size mono">{a.size_bytes > 0 ? formatBytes(a.size_bytes) : '—'}</span>
            <button
              class="rm"
              onclick={() => remove(a)}
              disabled={working !== null}
              title="Desinstalar"
            >
              {working === a.id ? '…' : 'Remover'}
            </button>
          </li>
        {/each}
      </ul>
      {#if filtered.length > 200}
        <p class="more subtle">Exibindo 200 de {filtered.length} — refine a busca</p>
      {/if}
    </section>
  {/if}
</div>

<style>
  .view { padding: 28px 32px 40px; display: flex; flex-direction: column; gap: 18px; overflow-y: auto; height: 100%; }
  .hero { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; }
  .hero p { margin-top: 4px; font-size: 13px; }

  .search {
    width: 320px; padding: 9px 14px;
    border-radius: 9px; font-size: 13px;
    background: var(--card-bg); border: 1px solid var(--border);
    color: #fff; outline: none;
    transition: border-color var(--dur-fast) var(--ease-out);
  }
  .search:focus { border-color: var(--accent); }

  .tabs { display: flex; flex-wrap: wrap; gap: 6px; }
  .tab {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 6px 12px; border-radius: 999px;
    background: var(--card-bg); border: 1px solid var(--border);
    font-size: 12px; color: var(--text-secondary); font-weight: 600;
  }
  .tab:hover { background: var(--card-bg-strong); color: #fff; }
  .tab.active { background: rgba(255,255,255,0.08); color: #fff; border-color: var(--border-strong); }
  .tab .count { font-size: 10.5px; color: var(--text-muted); font-weight: 600; }
  .tab .dot { width: 6px; height: 6px; border-radius: 999px; }

  .banner {
    padding: 10px 14px; border-radius: 10px; font-size: 12.5px; font-weight: 600;
    background: color-mix(in srgb, var(--danger) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--danger) 28%, transparent);
    color: var(--danger);
  }

  .list { padding: 6px 0; }
  .list ul { list-style: none; }
  .list li {
    display: grid;
    grid-template-columns: 70px 1fr 130px 90px 86px;
    align-items: center;
    gap: 12px;
    padding: 8px 18px;
    border-top: 1px solid rgba(255,255,255,0.04);
    font-size: 12.5px;
  }
  .list li:first-child { border-top: none; }
  .list li:hover { background: rgba(255,255,255,0.03); }

  .src-tag {
    font-size: 10px; font-weight: 700; letter-spacing: 0.05em; text-transform: uppercase;
    color: var(--c);
    padding: 2px 7px; border-radius: 5px;
    background: color-mix(in srgb, var(--c) 14%, transparent);
    text-align: center;
  }
  .meta { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
  .name { color: #fff; font-weight: 600; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .desc { color: var(--text-muted); font-size: 11px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .ver { color: var(--text-secondary); font-size: 11.5px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .size { color: #fff; text-align: right; }
  .rm {
    padding: 5px 10px; border-radius: 7px;
    background: rgba(255,77,94,0.10);
    border: 1px solid rgba(255,77,94,0.28);
    color: var(--danger);
    font-size: 11px; font-weight: 600;
  }
  .rm:hover:not(:disabled) { background: rgba(255,77,94,0.18); }
  .rm:disabled { opacity: 0.5; cursor: not-allowed; }

  .more { padding: 12px; text-align: center; }
  .state { padding: 60px 20px; text-align: center; color: var(--text-secondary); font-size: 13px; }
</style>
