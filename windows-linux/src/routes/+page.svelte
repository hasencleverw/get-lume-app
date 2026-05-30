<script lang="ts">
  import Sidebar from '$lib/components/Sidebar.svelte';
  import Titlebar from '$lib/components/Titlebar.svelte';
  import DashboardView from '$lib/views/DashboardView.svelte';
  import MemoryView from '$lib/views/MemoryView.svelte';
  import DiskView from '$lib/views/DiskView.svelte';
  import SpaceLensView from '$lib/views/SpaceLensView.svelte';
  import ProtectionView from '$lib/views/ProtectionView.svelte';
  import ApplicationsView from '$lib/views/ApplicationsView.svelte';
  import PerformanceView from '$lib/views/PerformanceView.svelte';
  import SettingsView from '$lib/views/SettingsView.svelte';
  import { navigation } from '$lib/stores/navigation.svelte';

  const section = $derived(navigation.current);
</script>

<svelte:head>
  <title>Lume</title>
</svelte:head>

<div class="app">
<Titlebar />
<div class="shell">
  <Sidebar />
  <main class="content">
    {#if section === 'dashboard'}
      <DashboardView />
    {:else if section === 'memory'}
      <MemoryView />
    {:else if section === 'disk'}
      <DiskView />
    {:else if section === 'space'}
      <SpaceLensView />
    {:else if section === 'protection'}
      <ProtectionView />
    {:else if section === 'apps'}
      <ApplicationsView />
    {:else if section === 'performance'}
      <PerformanceView />
    {:else if section === 'settings'}
      <SettingsView />
    {/if}
  </main>
</div>
</div>

<style>
  .app {
    display: flex;
    flex-direction: column;
    height: 100vh;
    width: 100vw;
    overflow: hidden;
  }
  .shell {
    display: flex;
    flex: 1;
    min-height: 0;
    overflow: hidden;
  }
  .content {
    flex: 1;
    min-width: 0;
    height: 100%;
    overflow: hidden;
    position: relative;
  }
</style>
