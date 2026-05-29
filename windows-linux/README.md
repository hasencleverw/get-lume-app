# Lume — Linux / Windows

Port nativo de **Lume** (macOS) para Linux e Windows usando Tauri 2.
Backend Rust, frontend Svelte 5 + Vite. Binário final ~10 MB.

## Status atual

| Módulo | Linux | Windows |
|---|---|---|
| Dashboard (Smart Scan) — CPU/RAM/disk/processes ao vivo | ✅ | ✅ (compilação) |
| Memory Cleaner (`drop_caches` via pkexec) | ✅ | ⏳ stub |
| Disk Cleaner (6 categorias + lixeira via `gio`) | ✅ | ✅ caminhos prontos, lixeira via `trash` crate |
| Space Lens | ⏳ esqueleto | ⏳ |
| Protection | ⏳ esqueleto | ⏳ |
| Applications | ⏳ esqueleto | ⏳ |
| Performance | ⏳ esqueleto | ⏳ |
| Donation key (HMAC-SHA256) | ✅ testado | ✅ testado |
| Localization (PT/EN/ES) | ⏳ | ⏳ |

## Stack

- **Tauri 2.x** — Rust backend + WebView frontend, IPC, tray icon.
- **Svelte 5** com runes API (`$state`, `$derived`, `$props`).
- **SvelteKit 2** (adapter-static — sem servidor Node em produção).
- **Vite 5** dev server na porta 1420.
- **sysinfo 0.32** — CPU, RAM, disco e processos cross-platform.
- **trash 5** — lixeira nativa em todos os SOs.
- **walkdir / rayon** — varredura recursiva paralela.
- **hmac + sha2 + subtle** — validação da chave de doador.

## Estrutura

```
lume/
├── package.json
├── svelte.config.js
├── vite.config.ts
├── tsconfig.json
├── src/                        # Frontend Svelte 5
│   ├── app.html
│   ├── app.d.ts
│   ├── lib/
│   │   ├── components/         # Sidebar, CircularGauge, LineChart, PageHeader
│   │   ├── views/              # Dashboard, Memory, Disk, Placeholder*
│   │   ├── services/           # IPC wrappers (system.ts, format.ts)
│   │   ├── stores/             # navigation.svelte.ts, metrics.svelte.ts
│   │   ├── styles/             # tokens.css, global.css
│   │   └── sections.ts         # enum + cores da macOS port
│   └── routes/                 # +layout.svelte, +page.svelte
└── src-tauri/                  # Backend Rust
    ├── Cargo.toml
    ├── tauri.conf.json
    ├── build.rs
    ├── capabilities/default.json
    ├── icons/                  # 32/128/128@2x/icon.png/icon.ico/tray.png
    └── src/
        ├── main.rs
        ├── lib.rs
        ├── state.rs            # Mutex<System> compartilhado
        ├── commands/           # Bindings IPC para o frontend
        ├── services/           # Lógica pura: system_monitor, disk_scanner,
        │                       # memory_cleaner, donation
        └── platform/           # linux.rs / windows.rs (mesma surface)
```

## Comandos

```bash
# 1. Instalar dependências
npm install

# 2. Modo dev (Vite + Tauri lado a lado, hot reload)
npm run tauri:dev

# 3. Build de release (gera .deb, .rpm e .AppImage no Linux)
npm run tauri:build
```

## Privilégios

- **Linux**: pkexec (PolicyKit). O primeiro comando privilegiado gera um
  prompt único de senha. `drop_caches` e operações de DNS/font cache passam por aqui.
- **Windows**: UAC. A estratégia escolhida (a implementar) é spawnar um helper
  elevado uma vez por sessão e enviar comandos via named pipe, evitando múltiplos
  prompts de UAC.

## Próximos passos (roadmap claro)

1. **Localization** — porta direta do `Localization.swift` para um JSON consumido pelo Svelte. As chaves já são compatíveis (`sidebar.memory`, `page.dashboard.title` etc).
2. **Space Lens** — `walkdir` + `rayon`, paginação no frontend, filtros por tipo.
3. **Applications** — combinar `pacman -Qq` (+ `dpkg-query`, `rpm -qa`, `flatpak list`, `snap list`) com parse de `.desktop` files via `freedesktop-desktop-entry`.
4. **Protection** — JSON com assinaturas conhecidas + scan de autostarts (`~/.config/autostart`, `/etc/xdg/autostart`) + `systemctl --user list-unit-files --state=enabled`.
5. **Performance** — DNS flush, font cache (fc-cache), `tracker3 reset` / `balooctl6`, `pacman -Sc` (Arch).
6. **MenuBarExtra → tray** — Tauri 2 já tem `tray-icon` no Cargo. Implementar painel flutuante com gauges + ação rápida de limpeza.
7. **Settings** — TOML em `$XDG_CONFIG_HOME/lume/config.toml`. Idioma, autostart (`~/.config/autostart/lume.desktop`), telemetria.

## Porta Windows

A camada `platform/windows.rs` já existe com stubs. Para terminar:

| Módulo | API necessária |
|---|---|
| Memory cleaner | `EmptyWorkingSet` em todos os processos (PSAPI.dll) |
| Disk cleanup | caminhos já mapeados; lixeira via `IFileOperation` (crate `trash` já cobre) |
| Apps Manager | leitura de `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` + WOW6432Node + `Get-StartApps` |
| Performance | `ipconfig /flushdns`, `net stop/start WSearch`, `net stop/start FontCache` |
| Privileged ops | UAC via `ShellExecute(..., "runas", ...)`, helper service + named pipe |

O Cargo.toml já tem a feature `windows` com os módulos Win32 mínimos
(`Win32_System_Memory`, `Win32_System_ProcessStatus`, `Win32_UI_Shell`, etc).

## Decisões de arquitetura

- **Tauri 2 sobre Tauri 1**: APIs mais limpas, segurança baseada em capabilities,
  tray cross-platform nativo, e SvelteKit oficialmente suportado.
- **Svelte 5 (runes) sobre Svelte 4**: zero overhead de reatividade, ergonomia de
  hooks no estilo Solid sem perder o compilador.
- **adapter-static** sem SSR: o app embute o frontend como arquivos estáticos no
  binário Tauri. Não precisa de Node em produção.
- **`trash` crate** ao invés de `gio trash` direto: cobre Linux/Windows/macOS com a
  mesma chamada, e na ausência do `gio` usa o protocolo XDG trash diretamente.
- **`subtle::ConstantTimeEq`** na validação da chave de doador: comparação em
  tempo constante elimina timing leaks (mesmo padrão usado na versão macOS).
- **`sync && echo 3 > drop_caches`**: a abordagem recomendada pelo próprio kernel
  para liberar caches manualmente. Reversível, segura, sem efeitos colaterais em
  processos ativos.

## Testes

```bash
cd src-tauri && cargo test
```

O teste `donation::tests` confirma que o validador Rust rejeita chaves
inválidas e que o HMAC-SHA256 é bit-a-bit compatível com o Swift original.
A chave válida é mantida fora do repositório — veja as notas do desenvolvedor.
