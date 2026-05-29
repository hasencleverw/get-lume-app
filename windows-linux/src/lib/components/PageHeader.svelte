<script lang="ts">
  interface Props {
    title: string;
    subtitle?: string;
    accent?: string;
  }
  let { title, subtitle = '', accent = '#8B6BF8' }: Props = $props();
</script>

<header class="page-header">
  <span class="dot" style="background: {accent}; box-shadow: 0 0 12px {accent}66"></span>
  <div>
    <h1 class="h-1">{title}</h1>
    {#if subtitle}<p class="subtitle subtle">{subtitle}</p>{/if}
  </div>
</header>

<style>
  .page-header {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 28px 32px 24px;
  }
  .dot { width: 10px; height: 10px; border-radius: 999px; flex-shrink: 0; }
  .subtitle { font-size: 13px; margin-top: 2px; }
</style>
