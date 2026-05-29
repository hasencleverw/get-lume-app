import { updaterApi, type UpdateDisplay } from '$lib/services/system';
import { openUrl } from '@tauri-apps/plugin-opener';

class UpdaterStore {
  status = $state<UpdateDisplay | null>(null);
  checking = $state(false);
  // Session-only hide. Banner returns on the next app boot if the update is
  // still pending — by design, the user can never permanently silence updates.
  private hiddenThisSession = $state(false);

  async init() {
    this.status = await updaterApi.status();
    if (await updaterApi.shouldCheck()) {
      this.checkInBackground();
    }
  }

  async checkInBackground() {
    if (this.checking) return;
    this.checking = true;
    try {
      this.status = await updaterApi.checkNow();
    } catch (e) {
      console.warn('updater check failed', e);
    } finally {
      this.checking = false;
    }
  }

  get shouldShowBanner(): boolean {
    if (!this.status || this.hiddenThisSession) return false;
    return this.status.available;
  }

  async openRelease() {
    if (this.status?.release_url) {
      try {
        await openUrl(this.status.release_url);
      } catch (e) {
        console.warn('failed to open release URL', e);
      }
    }
  }

  closeBanner() {
    this.hiddenThisSession = true;
  }
}

export const updater = new UpdaterStore();
