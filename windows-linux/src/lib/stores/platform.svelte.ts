export type Platform = 'windows' | 'linux' | 'macos' | 'unknown';

function detect(): Platform {
  const ua = navigator.userAgent.toLowerCase();
  if (ua.includes('windows')) return 'windows';
  if (ua.includes('mac os')) return 'macos';
  if (ua.includes('linux') || ua.includes('x11')) return 'linux';
  return 'unknown';
}

class PlatformStore {
  current = $state<Platform>(detect());
  get isWindows() { return this.current === 'windows'; }
  get isLinux() { return this.current === 'linux'; }
  get isMac() { return this.current === 'macos'; }
}

export const platform = new PlatformStore();
