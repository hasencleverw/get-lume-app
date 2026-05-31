import { largeFilesApi, type BigFile, type FileKind } from '$lib/services/system';

type ScanRoot = 'home' | 'root';

/// Persists Space Lens scan results across tab switches. Without this the
/// component-local state was lost every time the user navigated away and back,
/// forcing a full re-scan. The data lives as long as the app is open.
class SpaceLensStore {
  files = $state<BigFile[]>([]);
  scanning = $state(false);
  scanRoot = $state<ScanRoot>('home');
  filter = $state<Set<FileKind>>(new Set());
  hasScanned = $state(false);
  // Minimum file size in MB to surface — driven by the slider.
  minSizeMb = $state(100);

  async scan() {
    if (this.scanning) return;
    this.scanning = true;
    try {
      const root = this.scanRoot === 'root' ? '/' : null;
      this.files = await largeFilesApi.scan(root, 100, [], this.minSizeMb);
      this.hasScanned = true;
    } finally {
      this.scanning = false;
    }
  }

  setRoot(root: ScanRoot) {
    this.scanRoot = root;
  }

  setMinSize(mb: number) {
    this.minSizeMb = mb;
  }

  toggleKind(k: FileKind) {
    const next = new Set(this.filter);
    if (next.has(k)) next.delete(k);
    else next.add(k);
    this.filter = next;
  }

  clearFilter() {
    this.filter = new Set();
  }
}

export const spaceLens = new SpaceLensStore();
