export type SectionId =
  | 'dashboard'
  | 'memory'
  | 'disk'
  | 'space'
  | 'protection'
  | 'apps'
  | 'performance'
  | 'settings';

export interface Section {
  id: SectionId;
  label: string;
  subtitle: string;
  gradient: [string, string];
  accent: string;
  iconPath: string; // inline SVG path data for crisp custom icons
}

export const SECTIONS: Section[] = [
  {
    id: 'dashboard',
    label: 'Smart Scan',
    subtitle: 'Diagnóstico completo do seu sistema',
    gradient: ['#8B6BF8', '#5B3FD8'],
    accent: '#8B6BF8',
    iconPath: 'M12 2l1.7 4.4L18 8l-4.3 1.6L12 14l-1.7-4.4L6 8l4.3-1.6L12 2zm6 11l1 2.5 2.5 1L19 17l-1 2.5-1-2.5-2.5-1L17 15l1-2zM5 14l1.2 3.2L9.5 18 6.3 19.2 5 22.4 3.7 19.2.5 18l3.2-0.8L5 14z'
  },
  {
    id: 'memory',
    label: 'Memory',
    subtitle: 'Libere RAM presa por processos inativos',
    gradient: ['#4D8FFF', '#2D5FD0'],
    accent: '#4D8FFF',
    iconPath: 'M5 7h14a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1zm2 3v4M11 10v4M13 10v4M17 10v4M3 11h2M3 13h2M19 11h2M19 13h2'
  },
  {
    id: 'disk',
    label: 'Disk',
    subtitle: 'Remove caches, logs e arquivos desnecessários',
    gradient: ['#FF8C38', '#D85C10'],
    accent: '#FF8C38',
    iconPath: 'M3 7a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V7zm4 4h10M7 14h7'
  },
  {
    id: 'space',
    label: 'Space Lens',
    subtitle: 'Arquivos grandes por disco',
    gradient: ['#00C9A7', '#00957A'],
    accent: '#00C9A7',
    iconPath: 'M12 4a8 8 0 1 1 0 16 8 8 0 0 1 0-16zm0 3v5l3 3'
  },
  {
    id: 'protection',
    label: 'Protection',
    subtitle: 'Detecta e remove ameaças',
    gradient: ['#FF4D5E', '#CC2035'],
    accent: '#FF4D5E',
    iconPath: 'M12 3l8 3v6c0 5-3.5 8.5-8 10-4.5-1.5-8-5-8-10V6l8-3z'
  },
  {
    id: 'apps',
    label: 'Applications',
    subtitle: 'Gerencie e desinstale aplicativos',
    gradient: ['#34C87A', '#1A9A55'],
    accent: '#34C87A',
    iconPath: 'M4 4h6v6H4V4zm10 0h6v6h-6V4zM4 14h6v6H4v-6zm10 0h6v6h-6v-6z'
  },
  {
    id: 'performance',
    label: 'Performance',
    subtitle: 'Otimizações e manutenção do sistema',
    gradient: ['#FFB830', '#D08A0A'],
    accent: '#FFB830',
    iconPath: 'M13 2L4 14h7l-1 8 9-12h-7l1-8z'
  }
];

export function sectionById(id: SectionId): Section {
  return SECTIONS.find((s) => s.id === id) ?? SECTIONS[0];
}
