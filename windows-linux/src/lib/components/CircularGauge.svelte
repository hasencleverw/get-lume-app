<script lang="ts">
  interface Props {
    value: number; // 0-100
    size?: number;
    lineWidth?: number;
    accent?: [string, string];
    label?: string;
    unit?: string;
    showValue?: boolean;
  }
  let {
    value,
    size = 132,
    lineWidth = 11,
    accent = ['#9B6BF8', '#6B3FD8'],
    label = '',
    unit = '%',
    showValue = true
  }: Props = $props();

  const colors = $derived.by<[string, string]>(() => {
    if (value >= 80) return ['#FF4D5E', '#CC2035'];
    if (value >= 60) return ['#FFB830', '#D08A0A'];
    return accent;
  });

  const radius = $derived((size - lineWidth) / 2);
  const circumference = $derived(2 * Math.PI * radius);
  const offset = $derived(circumference * (1 - Math.min(100, Math.max(0, value)) / 100));
  const id = `lg-${Math.random().toString(36).slice(2)}`;
</script>

<div class="gauge" style="--size: {size}px">
  <svg width={size} height={size} viewBox="0 0 {size} {size}" style="transform: rotate(-90deg)">
    <defs>
      <linearGradient id="{id}-grad" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color={colors[0]} />
        <stop offset="100%" stop-color={colors[1]} />
      </linearGradient>
      <filter id="{id}-glow" x="-20%" y="-20%" width="140%" height="140%">
        <feGaussianBlur stdDeviation="3" />
      </filter>
    </defs>
    <!-- track -->
    <circle
      cx={size / 2}
      cy={size / 2}
      r={radius}
      fill="none"
      stroke="rgba(255,255,255,0.07)"
      stroke-width={lineWidth}
    />
    <!-- glow -->
    <circle
      cx={size / 2}
      cy={size / 2}
      r={radius}
      fill="none"
      stroke={colors[0]}
      stroke-width={lineWidth + 6}
      stroke-linecap="round"
      stroke-dasharray={circumference}
      stroke-dashoffset={offset}
      opacity="0.35"
      filter="url(#{id}-glow)"
      style="transition: stroke-dashoffset 0.9s cubic-bezier(.16,1,.3,1);"
    />
    <!-- arc -->
    <circle
      cx={size / 2}
      cy={size / 2}
      r={radius}
      fill="none"
      stroke="url(#{id}-grad)"
      stroke-width={lineWidth}
      stroke-linecap="round"
      stroke-dasharray={circumference}
      stroke-dashoffset={offset}
      style="transition: stroke-dashoffset 0.9s cubic-bezier(.16,1,.3,1);"
    />
  </svg>
  {#if showValue}
    <div class="center">
      <span class="value mono">{Math.round(value)}</span>
      <span class="unit">{unit}</span>
    </div>
  {/if}
  {#if label}
    <span class="label">{label}</span>
  {/if}
</div>

<style>
  .gauge {
    position: relative;
    width: var(--size);
    display: inline-flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }
  .center {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    height: var(--size);
    pointer-events: none;
  }
  .value {
    font-size: calc(var(--size) * 0.21);
    font-weight: 700;
    color: #fff;
    line-height: 1;
    letter-spacing: -0.02em;
  }
  .unit {
    font-size: calc(var(--size) * 0.10);
    color: var(--text-secondary);
    margin-top: 2px;
    font-weight: 600;
  }
  .label {
    font-size: 11px;
    font-weight: 500;
    color: var(--text-secondary);
    text-transform: uppercase;
    letter-spacing: 0.06em;
  }
</style>
