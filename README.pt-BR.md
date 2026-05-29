<div align="center">

<img src="Icone.png" alt="Lume" width="120" height="120">

# Lume

**A alternativa nativa e gratuita aos apps de limpeza pagos para macOS, Windows e Linux.**

[![Plataforma](https://img.shields.io/badge/plataforma-macOS%20%7C%20Windows%20%7C%20Linux-8B6BF8?style=flat-square)](#downloads)
[![Licença](https://img.shields.io/badge/licen%C3%A7a-Elastic%20License%202.0-00C9A7?style=flat-square)](LICENSE)
[![Versão](https://img.shields.io/badge/vers%C3%A3o-Beta%201.0.0-FFB830?style=flat-square)](#)
[![Idiomas](https://img.shields.io/badge/idiomas-PT%20%C2%B7%20EN%20%C2%B7%20ES-4D8FFF?style=flat-square)](#)
[![Doar](https://img.shields.io/badge/❤-Doar-FF4D5E?style=flat-square)](#apoie-o-projeto)

**[getlu.me](https://getlu.me)**

[English](README.md) · [Português](README.pt-BR.md)

</div>

---

O Lume é um utilitário de limpeza nativo e leve que faz tudo que os apps pagos como o CleanMyMac fazem — limpeza de disco, otimização de memória, detecção de malware, gerenciamento de apps, descoberta de arquivos grandes, otimizações de performance — sem mensalidade, sem cadastro, sem anúncios e sem inchaço.

A versão macOS é **~5 MB universal** (Apple Silicon + Intel). As versões Windows e Linux são igualmente compactas.

<div align="center">
  <img src="docs/screenshots/Smart scan - tela inicial.png" alt="Dashboard do Lume" width="780">
</div>

## Recursos

| Módulo | O que faz |
|---|---|
| 🟣 **Smart Scan / Dashboard** | Medidores de CPU, RAM e disco em tempo real, com diagnóstico instantâneo da saúde do sistema |
| 🔵 **Limpeza de Memória** | Libera RAM presa em processos inativos usando APIs nativas do sistema |
| 🟠 **Limpeza de Disco** | Remove caches, logs, temporários, downloads antigos, Lixeira e dados órfãos de apps — sempre pela Lixeira, recuperável |
| 🟢 **Space Lens** | Encontra os maiores arquivos e pastas em qualquer disco montado, com filtros por tipo e tamanho |
| 🔴 **Proteção** | Detecta adware, PUPs e malware conhecidos em LaunchAgents, serviços do sistema, /Applications e extensões de navegadores |
| 🟢 **Aplicativos** | Lista apps instalados com tamanho e último uso, desinstala junto com arquivos de suporte |
| 🟡 **Performance** | Limpeza de cache DNS, reindexação de busca, limpeza de fontes, esvaziar Lixeira, controle de Launch Agents |
| 🟣 **Menu Bar / Bandeja** | Painel rápido com métricas ao vivo e limpeza de memória em um clique — sem precisar abrir a janela principal |

## Downloads

<div align="center">

| Plataforma | Formato | Arquivo |
|---|---|---|
| 🍎 **macOS** 13+ | `.pkg` Universal (Apple Silicon + Intel) | [Lume_Installer.pkg](https://github.com/hasencleverw/get-lume-app/releases/latest) |
| 🪟 **Windows** 10/11 | Instalador `.exe` (NSIS) · `.zip` Portable | [Lume_x64-setup.exe](https://github.com/hasencleverw/get-lume-app/releases/latest) |
| 🐧 **Linux** | `.deb` Debian/Ubuntu · `.rpm` Fedora · `.pkg.tar.zst` Arch | [Escolha sua distro](https://github.com/hasencleverw/get-lume-app/releases/latest) |

</div>

> **Atenção — Beta:** o Lume está atualmente assinado ad-hoc (sem Apple Developer ID). No primeiro lançamento o macOS pode mostrar um aviso do Gatekeeper. Clique com o botão direito no app → **Abrir**, ou rode `sudo xattr -dr com.apple.quarantine /Applications/Lume.app` uma vez.

## Capturas de tela

<table>
<tr>
<td width="50%"><img src="docs/screenshots/Disco.png" alt="Limpeza de Disco"></td>
<td width="50%"><img src="docs/screenshots/Space Lens.png" alt="Space Lens"></td>
</tr>
<tr>
<td align="center"><b>Limpeza de Disco</b> — junk categorizado, tudo seguro para Lixeira</td>
<td align="center"><b>Space Lens</b> — encontre os maiores arquivos em qualquer disco</td>
</tr>
<tr>
<td width="50%"><img src="docs/screenshots/Protection.png" alt="Proteção"></td>
<td width="50%"><img src="docs/screenshots/Smart scan - tela inicial.png" alt="Dashboard"></td>
</tr>
<tr>
<td align="center"><b>Proteção</b> — varredura de ameaças em 4 camadas</td>
<td align="center"><b>Smart Scan</b> — saúde do sistema em tempo real</td>
</tr>
</table>

## Por que Lume em vez das alternativas pagas?

|  | Lume | Apps de limpeza pagos |
|---|:---:|:---:|
| Preço | **Grátis para sempre** | R$ 200–400 / ano |
| Tamanho do app | ~5 MB | ~300 MB |
| Conta obrigatória | Não | Sim |
| Coleta de dados | Não | Sim (anônima) |
| Sistemas suportados | macOS · Windows · Linux | Só macOS |
| Source available | ✅ Elastic License 2.0 | ❌ |
| Idiomas | PT · EN · ES | EN + |

## Arquitetura

O Lume é construído nativamente em cada plataforma para a melhor experiência e o menor binário possível:

```
                       ┌─────────────────────────┐
                       │  Sistema de design       │
                       │  compartilhado (landing) │
                       └────────────┬────────────┘
                                    │
       ┌────────────────────────────┼────────────────────────────┐
       │                            │                            │
┌──────▼───────┐            ┌───────▼────────┐           ┌──────▼─────┐
│   macOS      │            │    Windows     │           │    Linux   │
│ Swift +      │            │  C# / WinUI 3  │           │ GTK4 / Qt  │
│ SwiftUI      │            │                │           │            │
└──────────────┘            └────────────────┘           └────────────┘
```

Este repositório hospeda tanto a **referência macOS** (`macos/`, Swift 6 / SwiftUI / SPM) quanto o **port Windows + Linux** (`windows-linux/`, Tauri 2 / Rust + SvelteKit) — um espelho 1:1 dos serviços Swift. Os instaladores são anexados à [página de Releases](https://github.com/hasencleverw/get-lume-app/releases).

> **Status atual da implementação:** Windows e Linux atualmente são entregues pelo port compartilhado em Tauri 2. Implementações nativas em C# / WinUI 3 (Windows) e GTK4 (Linux) estão planejadas para versões maiores futuras, seguindo a mesma arquitetura de serviços da referência Swift.

### Estrutura do código (macOS)

```
macos/
├── Package.swift                — Manifesto do Swift Package Manager
├── build.sh                     — Gera .app universal + .dmg + .pkg
├── installer/                   — Páginas HTML do instalador PKG
└── Lume/
    ├── LumeApp.swift            — @main + AppDelegate + MenuBarExtra
    ├── ContentView.swift        — Sidebar e roteamento de seções
    ├── Models/                  — Enums e design tokens
    ├── Services/                — Lógica pura (sem UI)
    │   ├── SystemMonitor.swift           — Stats de CPU/RAM/disco + purge
    │   ├── DiskScanner.swift             — Categorias de junk + políticas
    │   ├── LargeFilesScanner.swift       — Motor do Space Lens
    │   ├── MalwareScanner.swift          — Detecção de ameaças em 4 camadas
    │   ├── AppManager.swift              — Descoberta de apps + desinstalação
    │   ├── PermissionsManager.swift      — Detecção de Acesso Completo
    │   ├── PrivilegedExecutor.swift      — Cache de sudo por sessão
    │   ├── DonationManager.swift         — Chave HMAC-SHA256
    │   ├── Localization.swift            — 220+ chaves em PT/EN/ES
    │   └── …
    ├── Views/                   — Views SwiftUI por seção
    └── Resources/               — Ícones, sons, Info.plist
```

### Estrutura do código (Windows + Linux)

Windows e Linux compartilham um único codebase Tauri 2. A camada de serviços em Rust é um port 1:1 da referência Swift — cada módulo em `Lume/Services/` corresponde a um arquivo Rust em `windows-linux/src-tauri/src/services/`.

```
windows-linux/
├── package.json                  — Deps SvelteKit + Tauri CLI
├── svelte.config.js
├── vite.config.ts
├── tsconfig.json
│
├── src/                          — UI (SvelteKit, compartilhada Windows + Linux)
│   ├── app.html
│   ├── app.d.ts
│   ├── lib/                      — componentes, stores, design tokens
│   └── routes/                   — views por seção
│
└── src-tauri/
    ├── Cargo.toml
    ├── tauri.conf.json           — bundles: nsis + msi (Windows), deb + rpm + appimage (Linux)
    ├── build.rs
    ├── capabilities/             — Permissões Tauri v2
    ├── icons/                    — .ico (Windows), .png (Linux), imagens do instalador NSIS
    └── src/
        ├── main.rs / lib.rs / state.rs / tray.rs
        ├── commands/             — Bridge JS ↔ Rust (um arquivo por feature)
        │   ├── apps.rs
        │   ├── disk.rs
        │   ├── memory.rs
        │   ├── large_files.rs
        │   ├── protection.rs
        │   ├── performance.rs
        │   ├── system.rs
        │   ├── donation.rs
        │   └── updater.rs
        ├── services/             — Lógica pura (espelho 1:1 de macOS/Lume/Services/)
        │   ├── system_monitor.rs        — Stats de CPU/RAM/disco
        │   ├── disk_scanner.rs          — Categorias de junk + Lixeira segura
        │   ├── large_files.rs           — Motor do Space Lens
        │   ├── protection.rs            — Detecção de ameaças em 4 camadas
        │   ├── app_manager.rs           — Descoberta de apps + desinstalação
        │   ├── memory_cleaner.rs        — Libera RAM via APIs do SO
        │   ├── performance.rs           — Cache DNS, caches, índices
        │   ├── donation.rs              — Chave HMAC-SHA256
        │   └── updater.rs               — Verificação de novas versões
        └── platform/             — Implementações específicas por SO
            ├── mod.rs            — Dispatcher #[cfg(target_os)]
            ├── windows.rs        — Win32 / WMI / Registro / NTAPI
            └── linux.rs          — procfs / D-Bus / systemd / gio
```

### Mapa de serviços (Swift ↔ Rust)

O port Tauri preserva a camada de serviços do macOS 1:1. Correções no Swift de referência guiam mudanças no Rust e vice-versa.

| macOS (Swift) | Windows + Linux (Rust) | O que faz |
|---|---|---|
| `Services/SystemMonitor.swift` | `services/system_monitor.rs` | Stats de CPU / RAM / disco |
| `Services/DiskScanner.swift` | `services/disk_scanner.rs` | Categorias de junk + políticas |
| `Services/LargeFilesScanner.swift` | `services/large_files.rs` | Motor do Space Lens |
| `Services/MalwareScanner.swift` | `services/protection.rs` | Detecção de ameaças em 4 camadas |
| `Services/AppManager.swift` | `services/app_manager.rs` | Descoberta + desinstalação de apps |
| `Services/PermissionsManager.swift` | `services/permissions.rs` *(em andamento)* | Detecção de privilégios |
| `Services/PrivilegedExecutor.swift` | `services/privileged.rs` *(em andamento)* | Cache de sessão elevada |
| `Services/DonationManager.swift` | `services/donation.rs` | Chave HMAC-SHA256 |
| `Services/Localization.swift` | SvelteKit `i18n` + arquivos de locale | 220+ chaves em PT / EN / ES |

## Compilar a partir do código (macOS)

Requisitos: **macOS 13+**, **Xcode Command Line Tools** (Swift 5.9+).

```bash
git clone https://github.com/hasencleverw/get-lume-app.git
cd lume-app/macos

# Build debug (só a arquitetura atual)
swift build

# Release completo: .app universal + .dmg + .pkg
bash build.sh release
```

O script de release produz:

- `macos/Lume_Installer.pkg` — instalador assinado
- `macos/Lume.dmg` — imagem de disco drag-and-drop
- `/tmp/LumeApp/Lume.app` — binário universal (arm64 + x86_64)

## Compilar a partir do código (Windows + Linux)

Requisitos: **Rust 1.75+**, **Node.js 20+**, **npm 10+** (ou pnpm).
No Linux, instale também as bibliotecas que o Tauri precisa:

```bash
sudo apt install libwebkit2gtk-4.1-dev libssl-dev libgtk-3-dev \
                 libayatana-appindicator3-dev librsvg2-dev
```

```bash
git clone https://github.com/hasencleverw/get-lume-app.git
cd lume-app/desktop
npm ci

# Dev (SO atual, com hot reload)
npm run tauri dev

# Release Windows: Lume-Setup.exe (NSIS) + Lume.msi
npm run tauri build -- --target x86_64-pc-windows-msvc

# Release Linux: .AppImage + .deb + .rpm
npm run tauri build
```

Os binários de release são gerados em `windows-linux/src-tauri/target/release/bundle/`:

- **Linux** → `appimage/Lume_*.AppImage` · `deb/Lume_*_amd64.deb` · `rpm/Lume-*.x86_64.rpm`
- **Windows** → `nsis/Lume-Setup-*.exe` · `msi/Lume_*.msi`

Os builds das duas plataformas rodam via CI em [`.github/workflows/desktop-release.yml`](.github/workflows/desktop-release.yml) a cada tag `v*`.

## Contribuindo

Pull requests são muito bem-vindos. Para mudanças não-triviais, abra uma issue antes para alinharmos a direção.

Áreas onde precisamos de ajuda:

- **Tradução** — francês, alemão, italiano, mandarim, japonês
- **Database de ameaças** — adições verificadas à lista de malware em `MalwareScanner.swift`
- **Assinatura Apple Developer ID** — patrocínio dos US$ 99/ano para notarização adequada
- **Pacotes Linux** — PKGBUILD do AUR, manifesto Flathub, receita Snap

## Apoie o projeto

O Lume é desenvolvido por uma única pessoa que paga tudo do próprio bolso. Se o app te economiza o custo de uma assinatura de limpeza paga, considere apoiar:

| Método | Onde |
|---|---|
| 🇧🇷 PIX | `95c1adaf-d8ee-4498-b7af-3a810ae30b59` |
| 🌎 PayPal | `hasen.borges@gmail.com` |
| ⭐ Estrela | a mais simples — deixe uma estrela aqui no repo |

Depois de doar, mande o comprovante para **hasen.borges@gmail.com** e você receberá uma chave de doador que desativa permanentemente os lembretes no app.

## Licença

[Elastic License 2.0](LICENSE) © 2026 Hasen Borges
