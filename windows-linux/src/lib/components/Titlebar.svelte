<script lang="ts">
  import { onMount } from 'svelte';
  import { getCurrentWindow } from '@tauri-apps/api/window';

  const win = getCurrentWindow();

  let maximized = $state(false);
  let isWindows = $state(false);

  onMount(() => {
    isWindows = /windows/i.test(navigator.userAgent);
  });

  async function refresh() {
    try { maximized = await win.isMaximized(); } catch { /* */ }
  }
  refresh();

  async function minimize() { await win.minimize(); }
  async function toggleMaximize() {
    await win.toggleMaximize();
    await refresh();
  }
  async function close() { await win.close(); }
</script>

<header class="titlebar" class:windows={isWindows} data-tauri-drag-region>
  <div class="brand" data-tauri-drag-region>
    <span class="logo"></span>
    <span class="name">Lume</span>
  </div>
  <div class="title" data-tauri-drag-region></div>

  {#if isWindows}
    <!-- Windows 11-style chrome: 46×32 rectangles, white glyphs, red close on hover. -->
    <div class="winctrls">
      <button class="winctl" onclick={minimize} aria-label="Minimizar" title="Minimizar">
        <svg viewBox="0 0 10 10" width="10" height="10"><path d="M2 5h6" stroke="currentColor" stroke-width="1" stroke-linecap="square" /></svg>
      </button>
      <button class="winctl" onclick={toggleMaximize} aria-label={maximized ? 'Restaurar' : 'Maximizar'} title={maximized ? 'Restaurar' : 'Maximizar'}>
        {#if maximized}
          <svg viewBox="0 0 10 10" width="10" height="10" fill="none" stroke="currentColor" stroke-width="1">
            <rect x="2" y="3" width="5" height="5" />
            <path d="M3 3V2h5v5h-1" />
          </svg>
        {:else}
          <svg viewBox="0 0 10 10" width="10" height="10" fill="none" stroke="currentColor" stroke-width="1">
            <rect x="2.5" y="2.5" width="5" height="5" />
          </svg>
        {/if}
      </button>
      <button class="winctl close" onclick={close} aria-label="Fechar" title="Fechar">
        <svg viewBox="0 0 10 10" width="10" height="10"><path d="M2.5 2.5l5 5M7.5 2.5l-5 5" stroke="currentColor" stroke-width="1" stroke-linecap="square" /></svg>
      </button>
    </div>
  {:else}
    <!-- KDE / macOS-style traffic lights: 13px circles with glyphs on cluster hover. -->
    <div class="ctrls">
      <button class="ctl min" onclick={minimize} aria-label="Minimizar" title="Minimizar">
        <svg viewBox="0 0 10 10" width="6" height="6"><path d="M2 5h6" stroke="#5e4400" stroke-width="1.3" stroke-linecap="round" /></svg>
      </button>
      <button class="ctl max" onclick={toggleMaximize} aria-label={maximized ? 'Restaurar' : 'Maximizar'} title={maximized ? 'Restaurar' : 'Maximizar'}>
        {#if maximized}
          <svg viewBox="0 0 10 10" width="6" height="6" fill="none" stroke="#003300" stroke-width="1.1">
            <rect x="2.5" y="3.5" width="4" height="4" />
            <path d="M3.5 3.5V2.5h4v4h-1" />
          </svg>
        {:else}
          <svg viewBox="0 0 10 10" width="7" height="7" fill="none" stroke="#003300" stroke-width="1.1">
            <rect x="2.5" y="2.5" width="5" height="5" />
          </svg>
        {/if}
      </button>
      <button class="ctl close" onclick={close} aria-label="Fechar" title="Fechar">
        <svg viewBox="0 0 10 10" width="6" height="6"><path d="M3.2 3.2l3.6 3.6M6.8 3.2L3.2 6.8" stroke="#560000" stroke-width="1.3" stroke-linecap="round" /></svg>
      </button>
    </div>
  {/if}
</header>

<style>
  .titlebar {
    height: 36px;
    flex: 0 0 36px;
    display: grid;
    grid-template-columns: auto 1fr auto;
    align-items: center;
    background: var(--sidebar-bg);
    border-bottom: 1px solid var(--border);
    user-select: none;
    -webkit-user-select: none;
    position: relative;
    z-index: 10;
  }
  /* Windows builds get a slightly taller bar matching the Windows 11 default and no right padding so the close button reaches the corner. */
  .titlebar.windows { height: 32px; flex-basis: 32px; }

  .brand {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 14px;
    height: 100%;
  }
  .logo {
    width: 10px; height: 10px; border-radius: 999px;
    background: linear-gradient(135deg, var(--accent), var(--accent-2));
    box-shadow: 0 0 8px rgba(139, 107, 248, 0.55);
  }
  .name { font-size: 12px; font-weight: 600; letter-spacing: -0.005em; color: var(--text-primary); }

  .title { height: 100%; }

  /* ────────── KDE / macOS traffic lights ────────── */
  .ctrls {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 14px;
    height: 100%;
  }
  .ctl {
    width: 13px;
    height: 13px;
    border-radius: 999px;
    display: grid;
    place-items: center;
    color: transparent;
    position: relative;
    box-shadow: inset 0 0 0 0.5px rgba(0, 0, 0, 0.35);
    transition: filter var(--dur-fast) var(--ease-out);
  }
  .ctl svg { opacity: 0; transition: opacity var(--dur-fast) var(--ease-out); }
  .ctrls:hover .ctl svg { opacity: 1; }
  .ctl.min   { background: #FEBC2E; }
  .ctl.max   { background: #28C840; }
  .ctl.close { background: #FF5F57; }
  .ctl:hover  { filter: brightness(1.08); }
  .ctl:active { filter: brightness(0.9); }

  /* ────────── Windows 11 chrome ────────── */
  .winctrls {
    display: flex;
    align-items: stretch;
    height: 100%;
  }
  .winctl {
    width: 46px;
    height: 100%;
    display: grid;
    place-items: center;
    color: var(--text-primary);
    background: transparent;
    border-radius: 0;
    transition: background var(--dur-fast) var(--ease-out);
  }
  .winctl:hover { background: rgba(255, 255, 255, 0.06); }
  .winctl:active { background: rgba(255, 255, 255, 0.10); }
  .winctl.close:hover { background: #C42B1C; color: #fff; }
  .winctl.close:active { background: #b41a0a; }
  .winctl svg { display: block; }
</style>
