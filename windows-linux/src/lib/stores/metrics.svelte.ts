import { systemApi, type SystemMetrics, type ProcessSnapshot, type HostInfo } from '$lib/services/system';

class MetricsStore {
  metrics = $state<SystemMetrics | null>(null);
  processes = $state<ProcessSnapshot[]>([]);
  host = $state<HostInfo | null>(null);
  history = $state<{ cpu: number[]; ram: number[] }>({ cpu: [], ram: [] });

  private timer: ReturnType<typeof setInterval> | null = null;

  async start(intervalMs = 2000) {
    if (this.timer) return;
    this.host = await systemApi.hostInfo();
    await this.poll();
    this.timer = setInterval(() => this.poll(), intervalMs);
  }

  stop() {
    if (this.timer) clearInterval(this.timer);
    this.timer = null;
  }

  async poll() {
    try {
      const [m, p] = await Promise.all([systemApi.metrics(), systemApi.topProcesses(8)]);
      this.metrics = m;
      this.processes = p;
      this.pushHistory(m);
    } catch (err) {
      console.error('metrics poll failed', err);
    }
  }

  private pushHistory(m: SystemMetrics) {
    const ramPct = (m.ram_used / Math.max(1, m.ram_total)) * 100;
    const next = {
      cpu: [...this.history.cpu, m.cpu_usage].slice(-30),
      ram: [...this.history.ram, ramPct].slice(-30)
    };
    this.history = next;
  }
}

export const systemMetrics = new MetricsStore();
