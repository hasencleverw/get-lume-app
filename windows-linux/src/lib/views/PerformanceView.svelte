<script lang="ts">
  import { performanceApi, type StartupItem, type TaskOutcome } from '$lib/services/system';
  import { platform } from '$lib/stores/platform.svelte';

  interface MaintTask {
    id: string;
    title: string;
    description: string;
    icon: string;
    run: () => Promise<TaskOutcome>;
  }

  const LINUX_TASKS: MaintTask[] = [
    {
      id: 'dns',
      title: 'Limpar cache DNS',
      description: 'systemd-resolved ou nscd · pode requerer pkexec',
      icon: 'M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83',
      run: performanceApi.flushDns
    },
    {
      id: 'fonts',
      title: 'Reconstruir cache de fontes',
      description: 'Limpa ~/.cache/fontconfig e roda fc-cache -fv',
      icon: 'M4 7l5-5h12v22H4V7z M9 2v5H4',
      run: performanceApi.rebuildFonts
    },
    {
      id: 'trash',
      title: 'Esvaziar lixeira',
      description: 'Remove tudo de ~/.local/share/Trash',
      icon: 'M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2',
      run: performanceApi.emptyTrash
    },
    {
      id: 'baloo',
      title: 'Reset Baloo (KDE)',
      description: 'Reinicia o índice de arquivos do Plasma',
      icon: 'M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm0 18a8 8 0 1 1 8-8 8 8 0 0 1-8 8z M12 8v4l3 2',
      run: performanceApi.resetBaloo
    },
    {
      id: 'pkg',
      title: 'Limpar cache de pacotes',
      description: 'pacman -Sc · apt clean · dnf clean all — requer pkexec',
      icon: 'M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z M3.27 6.96L12 12l8.73-5.04 M12 22V12',
      run: performanceApi.cleanPkgCache
    },
    {
      id: 'journal',
      title: 'Compactar journal',
      description: 'journalctl --vacuum-time=7d',
      icon: 'M12 2L2 7l10 5 10-5-10-5z M2 17l10 5 10-5 M2 12l10 5 10-5',
      run: performanceApi.vacuumJournal
    }
  ];

  const WINDOWS_TASKS: MaintTask[] = [
    {
      id: 'dns',
      title: 'Limpar cache DNS',
      description: 'ipconfig /flushdns — sem privilégios extras',
      icon: 'M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83',
      run: performanceApi.flushDns
    },
    {
      id: 'fonts',
      title: 'Reiniciar Font Cache',
      description: 'Reinicia o serviço FontCache (UAC vai pedir autorização)',
      icon: 'M4 7l5-5h12v22H4V7z M9 2v5H4',
      run: performanceApi.rebuildFonts
    },
    {
      id: 'recycle',
      title: 'Esvaziar Lixeira',
      description: 'SHEmptyRecycleBin em todas as unidades',
      icon: 'M3 6h18M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2',
      run: performanceApi.emptyTrash
    },
    {
      id: 'search',
      title: 'Reiniciar Windows Search',
      description: 'Reinicia o serviço Windows Search (UAC vai pedir autorização)',
      icon: 'M12 2a10 10 0 1 0 10 10A10 10 0 0 0 12 2zm0 18a8 8 0 1 1 8-8 8 8 0 0 1-8 8z M12 8v4l3 2',
      run: performanceApi.restartSearchIndex
    },
    {
      id: 'diskclean',
      title: 'Limpeza de Disco',
      description: 'Abre o utilitário cleanmgr (legado mas confiável)',
      icon: 'M21 16V8a2 2 0 0 0-1-1.73l-7-4a2 2 0 0 0-2 0l-7 4A2 2 0 0 0 3 8v8a2 2 0 0 0 1 1.73l7 4a2 2 0 0 0 2 0l7-4A2 2 0 0 0 21 16z M3.27 6.96L12 12l8.73-5.04 M12 22V12',
      run: performanceApi.diskCleanup
    }
  ];

  const TASKS = platform.isWindows ? WINDOWS_TASKS : LINUX_TASKS;

  let outcomes = $state<Record<string, TaskOutcome | null>>({});
  let working = $state<string | null>(null);

  async function execute(task: MaintTask) {
    working = task.id;
    outcomes = { ...outcomes, [task.id]: null };
    try {
      const r = await task.run();
      outcomes = { ...outcomes, [task.id]: r };
    } finally {
      working = null;
    }
  }

  let startup = $state<StartupItem[]>([]);
  let startupError = $state<string | null>(null);

  async function loadStartup() {
    try {
      startup = await performanceApi.listStartup();
    } catch (e) {
      startupError = String(e);
    }
  }
  if (!platform.isWindows) loadStartup();

  async function toggle(item: StartupItem) {
    try {
      await performanceApi.toggleStartup(item.path, !item.enabled);
      await loadStartup();
    } catch (e) {
      startupError = String(e);
    }
  }
</script>

<div class="view">
  <header class="hero">
    <div>
      <h1 class="h-display">Performance</h1>
      <p class="subtle">Otimizações e manutenção do sistema — cada tarefa é segura e idempotente</p>
    </div>
  </header>

  <section>
    <h2 class="h-2 section-title">Manutenção rápida</h2>
    <div class="grid">
      {#each TASKS as t (t.id)}
        {@const result = outcomes[t.id]}
        <article class="task glass">
          <header>
            <span class="icon">
              <svg viewBox="0 0 24 24" width="14" height="14" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round">
                <path d={t.icon} />
              </svg>
            </span>
            <span class="task-title">{t.title}</span>
          </header>
          <p class="task-desc">{t.description}</p>
          <div class="task-foot">
            <button class="run" disabled={working !== null} onclick={() => execute(t)}>
              {working === t.id ? 'Executando…' : 'Executar'}
            </button>
            {#if result}
              <span class="outcome" class:ok={result.ok} class:err={!result.ok}>
                {result.message}
              </span>
            {/if}
          </div>
        </article>
      {/each}
    </div>
  </section>

  {#if !platform.isWindows}
    <section>
      <h2 class="h-2 section-title">Apps que iniciam com o sistema</h2>
      {#if startupError}
        <div class="banner danger">{startupError}</div>
      {/if}
      <div class="startup glass">
        {#if startup.length === 0}
          <p class="empty">Nenhum item de inicialização encontrado.</p>
        {:else}
          <ul>
            {#each startup as item}
              <li>
                <button class="toggle" class:on={item.enabled} onclick={() => toggle(item)} title={item.enabled ? 'Desabilitar' : 'Habilitar'}>
                  <span class="knob"></span>
                </button>
                <div class="meta">
                  <span class="name">{item.name}</span>
                  <span class="exec mono">{item.exec}</span>
                </div>
                <span class="src">{item.source === 'user' ? 'usuário' : 'sistema'}</span>
              </li>
            {/each}
          </ul>
        {/if}
      </div>
    </section>
  {:else}
    <section>
      <h2 class="h-2 section-title">Apps que iniciam com o sistema</h2>
      <div class="hint glass">
        Use o atalho <b class="mono">Ctrl+Shift+Esc</b> → aba <b>Inicializar</b> do Gerenciador de Tarefas.
        Lume usa a mesma fonte de dados (Run keys do registro + pasta Startup), revelada na aba <b>Protection</b>.
      </div>
    </section>
  {/if}
</div>

<style>
  .view { padding: 28px 32px 40px; display: flex; flex-direction: column; gap: 22px; overflow-y: auto; height: 100%; }
  .hero p { margin-top: 4px; font-size: 13px; }
  .section-title { margin-bottom: 12px; }

  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 12px; }

  .task { padding: 14px 16px 12px; display: flex; flex-direction: column; gap: 8px; }
  .task header { display: flex; align-items: center; gap: 10px; }
  .task .icon { width: 28px; height: 28px; border-radius: 8px; background: linear-gradient(135deg, #FFB830, #D08A0A); display: grid; place-items: center; color: #fff; }
  .task-title { font-size: 13px; font-weight: 600; color: #fff; }
  .task-desc { font-size: 11.5px; color: var(--text-secondary); line-height: 1.5; }

  .task-foot { display: flex; align-items: center; gap: 10px; flex-wrap: wrap; }
  .run {
    padding: 6px 12px; border-radius: 8px;
    background: rgba(255,255,255,0.07); border: 1px solid var(--border);
    color: #fff; font-size: 12px; font-weight: 600;
  }
  .run:hover:not(:disabled) { background: rgba(255,255,255,0.11); }
  .run:disabled { opacity: 0.5; cursor: not-allowed; }
  .outcome { font-size: 11px; flex: 1; }
  .outcome.ok { color: var(--success); }
  .outcome.err { color: var(--danger); }

  .banner {
    padding: 10px 14px; border-radius: 10px; font-size: 12.5px; font-weight: 600;
    background: color-mix(in srgb, var(--danger) 12%, transparent);
    border: 1px solid color-mix(in srgb, var(--danger) 28%, transparent);
    color: var(--danger);
    margin-bottom: 10px;
  }

  .startup { padding: 6px 0; }
  .empty { padding: 20px; text-align: center; color: var(--text-muted); font-size: 12.5px; }
  .startup ul { list-style: none; }
  .startup li {
    display: grid;
    grid-template-columns: 36px 1fr 80px;
    align-items: center;
    gap: 14px;
    padding: 9px 18px;
    border-top: 1px solid rgba(255,255,255,0.04);
  }
  .startup li:first-child { border-top: none; }
  .startup li:hover { background: rgba(255,255,255,0.03); }

  .toggle {
    width: 30px; height: 18px; border-radius: 999px;
    background: rgba(255,255,255,0.10);
    position: relative;
    transition: background var(--dur-fast) var(--ease-out);
  }
  .toggle.on { background: var(--success); }
  .knob {
    position: absolute; top: 2px; left: 2px;
    width: 14px; height: 14px; border-radius: 999px;
    background: #fff;
    transition: transform var(--dur-fast) var(--ease-out);
  }
  .toggle.on .knob { transform: translateX(12px); }

  .meta { display: flex; flex-direction: column; gap: 1px; min-width: 0; }
  .name { color: #fff; font-size: 13px; font-weight: 500; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .exec { color: var(--text-muted); font-size: 11px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .src { color: var(--text-muted); font-size: 11px; text-align: right; text-transform: uppercase; letter-spacing: 0.04em; }

  .hint { padding: 14px 18px; font-size: 12.5px; color: var(--text-secondary); line-height: 1.6; }
  .hint b { color: #fff; }
</style>
