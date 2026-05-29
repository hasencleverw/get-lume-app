<script lang="ts">
  interface Props {
    values: number[];
    color?: string;
    fillOpacity?: number;
    height?: number;
  }
  let { values, color = '#8B6BF8', fillOpacity = 0.18, height = 48 }: Props = $props();

  const id = `lc-${Math.random().toString(36).slice(2)}`;

  const path = $derived.by(() => {
    if (values.length < 2) return { line: '', fill: '' };
    const w = 100;
    const max = Math.max(10, ...values);
    const step = w / (values.length - 1);
    const pt = (i: number) =>
      `${(i * step).toFixed(2)},${(height - (values[i] / max) * height * 0.92 - height * 0.04).toFixed(2)}`;
    const linePts = values.map((_, i) => pt(i)).join(' ');
    const fillPts = `0,${height} ${linePts} ${w},${height}`;
    return {
      line: `M ${linePts.split(' ').join(' L ')}`,
      fill: `M ${fillPts.split(' ').join(' L ')} Z`
    };
  });
</script>

<svg viewBox="0 0 100 {height}" preserveAspectRatio="none" class="chart">
  <defs>
    <linearGradient id="{id}-fill" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color={color} stop-opacity={fillOpacity} />
      <stop offset="100%" stop-color={color} stop-opacity="0" />
    </linearGradient>
  </defs>
  {#if path.fill}
    <path d={path.fill} fill="url(#{id}-fill)" />
  {/if}
  {#if path.line}
    <path d={path.line} fill="none" stroke={color} stroke-width="1.4" vector-effect="non-scaling-stroke" stroke-linecap="round" stroke-linejoin="round" />
  {/if}
</svg>

<style>
  .chart { width: 100%; height: 100%; display: block; }
</style>
