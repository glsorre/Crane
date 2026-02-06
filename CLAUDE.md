# CLAUDE.md

We are building the app described in @SPEC.md. Read that file for general architectural tasks or to double check the tech stack or application architecture.

Keep your replies extremely coincise and focus on conveying the key information. No unncessary fluff, no long code snippets.

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Crane (product name: "Right Crane") is a native macOS GUI for managing Apple Containers. It targets macOS 26 (Tahoe) on Apple Silicon, importing the container runtime directly via Swift rather than wrapping CLI output. Bundle ID: `me.rightright.RightCrane`.

## Build & Development

- **Build system:** Xcode project (`Crane.xcodeproj`), no SPM Package.swift
- **Build:** `xcodebuild -project Crane.xcodeproj -scheme "Right Crane" build` or open in Xcode
- **Requirements:** macOS 26.0+, Apple Silicon, Xcode with Apple SDK 26
- **Dev environment:** Uses `devenv` (Nix-based) with `devenv.nix` config and direnv (`.envrc`)
- **No test suite or linter is currently configured**

## Dependencies (via SPM in Xcode)

- `apple/container` - The Apple Container runtime library, providing: ContainerClient, ContainerAPIService, ContainerBuild, ContainerCommands, ContainerImagesService, ContainerLog, ContainerNetworkService, ContainerPersistence, ContainerPlugin, ContainerSandboxService, ContainerVersion, ContainerXPC, SocketForwarder
- `sindresorhus/LaunchAtLogin-Modern` - Launch-at-login support
- `apple/swift-argument-parser` - Argument parsing

## Architecture

**MVVM with singleton stores and reactive SwiftUI bindings (`@Observable`).**

### State Management (Singletons)

- `AppViewModel.shared` - Global app state: navigation, error display, service health checks
- `ContainersStore.shared` - Container list CRUD, background polling
- `ImagesStore.shared` - Image list, image fetching, container creation from images
- `NetworksStore.shared` - Network list and creation

Each store initializes a background `Task` that polls the container runtime API at user-configurable intervals (default: 1s containers, 3s logs). Polling intervals are stored in `UserDefaults`.

### View Hierarchy

```
CraneApp (@main)
  └── CraneView (TabView with 3 tabs)
        ├── CraneContainersListView (Table view)
        │     └── CraneDetailsView (detail page: info + logs + actions)
        ├── CraneImagesListView (DisclosureTableRow tree: images → child containers)
        └── CraneNetworksListView (DisclosureTableRow tree: networks → child containers)
```

Settings scene: `CraneSettingsView` (refresh intervals, theme, launch-at-login).

### Domain Models

- `Container` - Wraps `ClientContainer`, has `transiting` flag for UI during async ops, provides `start()/stop()/remove()` with 10s timeouts
- `Image` - Wraps `ClientImage`, tracks status (`.available`/`.fetching`/`.removing`), handles container creation with full config
- `Network` - Wraps `NetworkState`, holds network info

### Key Patterns

- **NSViewRepresentable wrappers** for `SelectableLogText` (NSTextView with scroll tracking) and `NumericField` (NSTextField with NumberFormatter)
- **Log streaming:** `DetailsViewModel` uses `StreamReader` to read container logs line-by-line from FileHandles with offset tracking, supporting multiple log handles per container
- **Service check on launch:** Verifies `com.apple.container.apiserver` is registered via `launchctl` and performs health ping before showing UI

### Source Layout

```
Crane/
  ├── CraneApp.swift          # Entry point
  ├── CraneView.swift          # Main TabView
  ├── Crane*ListView.swift     # Tab views (Containers, Images, Networks)
  ├── CraneDetailsView.swift   # Container detail page
  ├── CraneSettingsView.swift  # Preferences
  ├── ViewModels/              # @Observable stores and view models
  ├── Views/                   # Feature-specific sub-views (actions, info, logs)
  ├── Components/              # Reusable UI (SpinnerButton, PathLabel, PortLabel, etc.)
  └── Utils/                   # StreamReader, helpers, extensions on ContainerClient types
```

## Entitlements

The app uses `com.apple.security.application-groups` with groups `com.apple.container.apiserver` and `com.apple.container` for XPC communication with the container runtime.
