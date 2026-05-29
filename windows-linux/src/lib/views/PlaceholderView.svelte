<script lang="ts">
  interface Props {
    title: string;
    subtitle: string;
    accent: string;
    plannedFeatures: string[];
  }
  let { title, subtitle, accent, plannedFeatures }: Props = $props();
</script>

<div class="view">
  <header class="hero">
    <div>
      <h1 class="h-display">{title}</h1>
      <p class="subtle">{subtitle}</p>
    </div>
    <span class="badge" style="--c: {accent}">Em construção</span>
  </header>

  <section class="card glass">
    <h2 class="h-2">Próximas funcionalidades</h2>
    <ul>
      {#each plannedFeatures as feat}
        <li>
          <span class="bullet" style="--c: {accent}"></span>
          {feat}
        </li>
      {/each}
    </ul>
  </section>
</div>

<style>
  .view { padding: 28px 32px 40px; display: flex; flex-direction: column; gap: 22px; overflow-y: auto; height: 100%; }
  .hero { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; }
  .hero p { margin-top: 4px; font-size: 13px; }
  .badge {
    padding: 5px 11px; border-radius: 999px; font-size: 11px; font-weight: 600;
    color: var(--c);
    background: color-mix(in srgb, var(--c) 14%, transparent);
    border: 1px solid color-mix(in srgb, var(--c) 28%, transparent);
  }
  .card { padding: 22px 24px; }
  .card h2 { margin-bottom: 12px; }
  ul { list-style: none; display: flex; flex-direction: column; gap: 8px; }
  li {
    display: flex; align-items: center; gap: 10px;
    padding: 6px 0;
    font-size: 13px;
    color: var(--text-secondary);
  }
  .bullet { width: 7px; height: 7px; border-radius: 999px; background: var(--c); box-shadow: 0 0 8px var(--c); flex-shrink: 0; }
</style>
