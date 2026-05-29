import type { SectionId } from '$lib/sections';

class NavigationStore {
  current = $state<SectionId>('dashboard');

  go(section: SectionId) {
    this.current = section;
  }
}

export const navigation = new NavigationStore();
