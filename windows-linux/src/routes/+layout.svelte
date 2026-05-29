<script lang="ts">
  import '$lib/styles/global.css';
  import { onMount, onDestroy } from 'svelte';
  import { systemMetrics } from '$lib/stores/metrics.svelte';
  import { donation } from '$lib/stores/donation.svelte';
  import { updater } from '$lib/stores/updater.svelte';
  import DonationPopup from '$lib/components/DonationPopup.svelte';

  let { children } = $props();

  onMount(async () => {
    systemMetrics.start(2000);
    await donation.init();
    donation.maybeOpenAfterDelay(4000);
    updater.init();
  });

  onDestroy(() => {
    systemMetrics.stop();
  });
</script>

{@render children()}
<DonationPopup />
