# AGENTS.md

## 1. 프로젝트 목적

이 프로젝트는 터미널 shell 이 아니라, Hyprland 기반의 GUI shell 을 만드는 프로젝트다.

- 구현 기반은 `AGS + GJS + Gtk4 + Astal`
- 목적은 Hyprland 환경에서 동작하는 사용자용 shell UI 를 만드는 것
- 이 저장소의 flake 는 개발용 `devShell`, shell source package, Home Manager module, NixOS helper module 을 제공한다
- 실제 사용 환경에서는 Home Manager 의 `programs.ags-shell.enable` 로 AGS 런타임 패키지와 shell source symlink 를 구성할 수 있다

## 2. 현재 프로젝트 상태

현재 상태는 "기본 shell UI 의 디자인/기능 구현이 상당 부분 들어간 상태" 이다.

- 앱 엔트리포인트는 [app.tsx](/home/rflxn/development/new-shell/app.tsx:1) 이다
- 현재 `app.tsx` 는 `ags/gtk4/app`, `style.scss`, IPC request handler, layout tree 를 연결하고, JSX 로 생성된 window 를 재귀적으로 `app.add_window()` 에 등록한다
- 스타일 엔트리포인트 [style.scss](/home/rflxn/development/new-shell/style.scss:1) 는 theme, bar, global menu, shutdown confirmation overlay, widgets 스타일을 import 한다
- 기본 레이아웃은 [layout.json](/home/rflxn/development/new-shell/layout.json:1) 의 JSON 설정을 [layout.tsx](/home/rflxn/development/new-shell/layout.tsx:1) 에서 parse 해서 구성한다
- 각 layout 항목은 `monitor`, `widgets.left/center/right`, `components` 배열로 bar 위젯과 overlay component 를 선언한다
- 현재 JSON 설정은 `DP-3` 에 feed hub/window title/workspaces/datetime/system controls 및 주요 overlay menu 를 배치하고, `HDMI-A-1` 에 datetime/workspaces/hardware monitor 를 배치한다
- 구현된 주요 UI 는 bar, app launcher, feed hub(system tray + notifications), Hyprland workspaces/window title, system controls(volume/network/bluetooth/battery), shutdown confirmation overlay, hardware monitor 이다
- 전역 메뉴 상태는 [components/global-store.tsx](/home/rflxn/development/new-shell/components/global-store.tsx:1) 에서 관리하며, 메뉴들은 `Gtk.Revealer` 와 layer-shell overlay window 로 표시한다
- IPC 는 [ipc/index.ts](/home/rflxn/development/new-shell/ipc/index.ts:1) 에서 처리하며, 현재 `ags request launcher <toggle|open|close>` 를 지원한다
- 디자인/기능 배치에 대한 현재 요약은 [docs/current-state.md](/home/rflxn/development/new-shell/docs/current-state.md:1) 를 참고한다
- 알려진 문제와 검증 이슈는 [docs/known-issue.md](/home/rflxn/development/new-shell/docs/known-issue.md:1) 를 참고한다
- 타입 환경은 `@girs` 로 생성되어 있으며, Hyprland/Notifd/Mpris/Tray/Network/Battery/WirePlumber 등의 타입이 준비되어 있다
- Nix 설정은 [flake.nix](/home/rflxn/development/new-shell/flake.nix:1) 에서 개발용 `devShell`, `ags-shell` package, Home Manager module, NixOS helper module 을 제공한다
- 문서 라우팅은 [docs/README.md](/home/rflxn/development/new-shell/docs/README.md:1) 를 기준으로 보고, API 레퍼런스는 `docs/reference` 아래의 분할된 구조를 사용한다

핵심 참고 문서:

- 문서 라우팅: [docs/README.md](/home/rflxn/development/new-shell/docs/README.md:1)
- 현재 구현 상태: [docs/current-state.md](/home/rflxn/development/new-shell/docs/current-state.md:1)
- 알려진 문제: [docs/known-issue.md](/home/rflxn/development/new-shell/docs/known-issue.md:1)
- Nix 통합: [docs/nix.md](/home/rflxn/development/new-shell/docs/nix.md:1)
- 전체 라우팅 인덱스: [docs/reference/README.md](/home/rflxn/development/new-shell/docs/reference/README.md:1)
- AGS 모듈: [docs/reference/ags-modules.md](/home/rflxn/development/new-shell/docs/reference/ags-modules.md:1)
- AGS CLI / intrinsic: [docs/reference/ags-cli-and-intrinsics.md](/home/rflxn/development/new-shell/docs/reference/ags-cli-and-intrinsics.md:1)
- GJS runtime: [docs/reference/gjs-runtime.md](/home/rflxn/development/new-shell/docs/reference/gjs-runtime.md:1)
- GNOME core: [docs/reference/gnome-core.md](/home/rflxn/development/new-shell/docs/reference/gnome-core.md:1)
- GTK UI stack: [docs/reference/gtk-ui.md](/home/rflxn/development/new-shell/docs/reference/gtk-ui.md:1)
- Wayland shell helper: [docs/reference/wayland-shell.md](/home/rflxn/development/new-shell/docs/reference/wayland-shell.md:1)
- Astal 라이브러리: [docs/reference/astal-libraries.md](/home/rflxn/development/new-shell/docs/reference/astal-libraries.md:1)
- 로컬 GIR 인벤토리: [docs/reference/local-inventory.md](/home/rflxn/development/new-shell/docs/reference/local-inventory.md:1)

## 3. 프로젝트 진행시 주의사항

### 유저가 요청한 사항 "만" 구현할 것

- 요청 범위를 임의로 넓히지 않는다
- 사용자가 요청하지 않은 리팩터링, 스타일 변경, 구조 변경, 부가 기능 추가를 하지 않는다
- 더 좋은 방향이 있어도 먼저 사용자 요청 범위를 우선한다

### 무엇을 어떻게 구현했는지 설명할 것

- 작업 후에는 무엇을 바꿨는지 명확히 설명한다
- 어디를 수정했는지, 왜 그렇게 했는지, 무엇이 달라졌는지를 짧고 정확하게 정리한다
- 사용자가 요청한 범위 밖의 변경이 있다면 반드시 명시한다

### 모든 구현은 항상 정리한 API index 를 참고할 것

- 구현 전에 먼저 `docs/reference` 의 분할된 API index 를 확인한다
- AGS 관련 구현은 AGS 문서를 먼저 확인한다
- GJS/GNOME/Astal 관련 구현은 대응 문서를 확인한 뒤 `@girs` 타입 파일로 정확한 import, property, signal, overload 를 검증한다
- 동작/개념은 공식 문서를 기준으로 보고, 정확한 타입과 import 경로는 `@girs` 를 기준으로 본다

### 추가 운영 원칙

- 이 저장소는 이미 실제 AGS shell UI 구현이 들어간 상태다. 구현 시 현재 widget/store/style 구조를 먼저 파악하고, 기존 패턴을 유지하면서 신중하게 확장한다
- `flake.nix` 는 devShell, package, Home Manager module, NixOS helper module 을 함께 제공한다. 설치 흐름을 바꿀 때는 `docs/nix.md` 와 module option 을 같이 맞춘다
- 실제 shell 기능 구현 전에는 가능한 한 Hyprland, Astal, Gtk4, layer-shell 관련 문서를 먼저 대조한다
- 이 프로젝트는 Nix 기반이므로, 필요한 도구가 현재 PATH 에 없으면 `nix develop` 또는 `nix-shell -p ...` 같은 방식으로 일시적으로 도구를 확보해 사용할 수 있다
- monocolor 아이콘이 필요하면 Google Material Symbols SVG 를 사용하고, 파일은 `assets/icons/material/*.svg` 경로에 저장해서 사용한다
