import { donationApi, type DonationState } from '$lib/services/system';

class DonationStore {
  state = $state<DonationState>({ has_donated: false, reminders_disabled: false, last_reminder: null });
  showPopup = $state(false);

  async init() {
    this.state = await donationApi.getState();
  }

  /// Triggered on app boot — 4 s delay so the UI is warm and the user isn't
  /// hit with a modal before seeing the dashboard.
  async maybeOpenAfterDelay(ms = 4000) {
    const should = await donationApi.shouldShow();
    if (!should) return;
    setTimeout(() => { this.showPopup = true; }, ms);
  }

  async openManually() {
    this.showPopup = true;
  }

  async remindLater() {
    this.state = await donationApi.markReminded();
    this.showPopup = false;
  }

  async disable() {
    this.state = await donationApi.disable();
    this.showPopup = false;
  }

  async submitKey(key: string): Promise<boolean> {
    try {
      this.state = await donationApi.applyKey(key);
      this.showPopup = false;
      return true;
    } catch {
      return false;
    }
  }
}

export const donation = new DonationStore();
