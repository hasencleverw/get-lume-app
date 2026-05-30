import type { SectionId } from '$lib/sections';

class NavigationStore {
  current = $state<SectionId>('dashboard');
  private history = $state<SectionId[]>([]);

  go(section: SectionId) {
    if (section !== this.current) {
      this.history.push(this.current);
      this.current = section;
    }
  }

  back() {
    const prev = this.history.pop();
    this.current = prev ?? 'dashboard';
  }

  get canGoBack(): boolean {
    return this.history.length > 0;
  }
}

export const navigation = new NavigationStore();
