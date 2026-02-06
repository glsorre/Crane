# Technical Specification: Right Crane

## 1. Overview

**Right Crane** is a native macOS graphical user interface for managing Apple Containers. It targets **macOS 26 (Tahoe)** and later, leveraging the native `Containerization` Swift framework to create, run, and manage Linux containers on Apple Silicon.

Unlike wrappers that parse CLI output, Right Crane imports the container runtime directly, treating containers as first-class Swift objects.

## 2. System Architecture

### 2.1 Technology Stack

* **Platform:** macOS 26.0+ (Tahoe) | Apple Silicon (arm64)
* **Language:** Swift 6.0
* **UI Framework:** SwiftUI (using the new "Liquid Glass" design paradigms where appropriate)
* **Dependencies:**
  * `apple/container` — The runtime library (`ContainerClient`, `ContainerAPIService`, `ContainerNetworkService`, `ContainerPersistence`, etc.)
  * `sindresorhus/LaunchAtLogin-Modern` — Launch-at-login support
  * `apple/swift-argument-parser` — Argument parsing

### 2.2 Application Layers

1. **Presentation Layer (SwiftUI):**
   * Uses `@Observable` macros for high-performance state binding.
   * TabView-based navigation with three tabs (Containers, Images, Networks).
   * `NavigationStack` with a `CraneRoute` enum (`.list`, `.detail(container:)`) for detail routing.

2. **Domain Layer (Singleton Stores):**
   * **`AppViewModel.shared`** — Global app state: navigation path, error display, service health checks on launch.
   * **`ContainersStore.shared`** — Container list CRUD, background polling, search/filter.
   * **`ImagesStore.shared`** — Image list, image fetching/removal, container creation from images.
   * **`NetworksStore.shared`** — Network list, network creation.
   * **`DetailsViewModel`** — Per-detail-view model for log streaming and container actions.
   * All stores are `@Observable` classes using polling-based state updates (not actors or event streams).

3. **Data Layer (Wrapper Models):**
   * `Container` wraps `ClientContainer` from the `apple/container` library.
   * `Image` wraps `ClientImage` and `ContainerizationOCI.Image`.
   * `Network` wraps `NetworkState` from `ContainerNetworkService`.

## 3. Data Model

### 3.1 Container

Defined in `ContainersStore.swift`. Wraps the library's `ClientContainer`.

```swift
@Observable
class Container: Identifiable, Hashable {
    var id: String
    var container: ClientContainer
    var transiting: Bool  // UI flag: true during async start/stop/remove

    func start() async throws   // bootstrap + process.start(), 10s timeout, 5s post-delay
    func stop() async throws    // container.stop(), 10s timeout, 5s post-delay
    func remove() async throws  // container.delete(), 10s timeout
}
```

### 3.2 Image

Defined in `ImagesStore.swift`. Wraps the library's `ClientImage` and OCI image configuration.

```swift
enum ImageStatus {
    case available
    case fetching
    case removing
}

@Observable
class Image: Identifiable, Hashable {
    var id: String                                     // Reference string
    var image: ClientImage?
    var imageConfiguration: ContainerizationOCI.Image?
    var status: ImageStatus

    func remove() async throws
    func createContainer(
        id: String,
        executable: String,
        arguments: [String],
        environment: [String],
        networks: [Network]
    ) async throws
}
```

### 3.3 Network

Defined in `NetworksStore.swift`. Wraps the library's `NetworkState`.

```swift
@Observable
class Network: Identifiable, Hashable {
    var id: String
    var network: NetworkState
    var transiting: Bool
}
```

## 4. Functional Requirements & Implementation

### 4.1 Container Lifecycle

All operations use the `apple/container` library directly via async Swift calls.

* **Listing:** `ClientContainer.list()` — polled at a configurable interval (UserDefaults key `"refreshInterval"`, default 1 second).
* **Starting:** `ProcessIO.create(tty: true, interactive: false, detach: true)` → `container.bootstrap(stdio:)` → `process.start()`.
* **Stopping:** `container.stop()`.
* **Removing:** `container.delete()` (only when stopped).
* **Timeouts:** All operations wrapped with `withTimeout()` (default 10 seconds). Start and stop include a 5-second post-delay for state propagation.
* **State Updates:** Polling-based with set diffing — containers are added, updated, or removed each cycle. No event bus or `AsyncStream`.

### 4.2 Image Management

* **Listing:** `ClientImage.list()` — polled at the same `"refreshInterval"` interval.
* **Fetching:** `ClientImage.fetch(reference:)` after `ClientImage.normalizeReference()`.
* **Removing:** `ClientImage.delete(reference:)`.
* **Container Creation:** `ClientContainer.create(configuration:options:kernel:)` using `ClientKernel.getDefaultKernel(for: .current)`, with user-specified name, executable, arguments, environment variables, and network attachments.

### 4.3 Networking

* **Listing:** `ClientNetwork.list()` — polled at the same `"refreshInterval"` interval.
* **Creation:** `ClientNetwork.create(configuration: .init(id: id, mode: NetworkMode.nat))`.
* **Display:** IP addresses shown in both the container table and detail info panel. Port links use `http://localhost:{hostPort}`.
* **Hierarchy:** Networks tab shows a tree of networks → child containers via `DisclosureTableRow`.

### 4.4 Log Streaming

Read-only log viewing (no interactive terminal).

* **Implementation:** `DetailsViewModel` retrieves `FileHandle` arrays via `container.logs()`. Each handle is read line-by-line using `StreamReader` with offset tracking.
* **Multiple Handles:** Tabs per handle — handle 0 is "Process", handles 1–(n−1) are "Process 2", "Process 3", etc., and the last handle is "System".
* **Polling:** Logs polled at a configurable interval (UserDefaults key `"logsInterval"`, default 3 seconds).
* **Auto-scroll:** `SelectableLogText` (NSViewRepresentable wrapping NSTextView) tracks user scroll position. When "Follow Logs" toggle is on and the user hasn't scrolled away, new output auto-scrolls to bottom.

## 5. UI/UX Specifications

### 5.1 Main Layout

```
CraneApp (@main)
  ├── WindowGroup → CraneView
  └── Settings → CraneSettingsView
```

`CraneView` is a `NavigationStack` containing a `TabView` with three tabs:

1. **Containers** — `CraneContainersListView`
2. **Images** — `CraneImagesListView`
3. **Networks** — `CraneNetworksListView`

On startup, `CraneView` checks that `com.apple.container.apiserver` is registered (via `launchctl print`) and performs a `ClientHealthCheck.ping(timeout: 10s)`. Fatal errors offer a "Quit" button; non-fatal errors offer a "Refresh" button that resets all stores.

### 5.2 Containers Tab

A searchable `Table` view with the following columns:

| Column   | Content                                                |
|----------|--------------------------------------------------------|
| name     | Container ID                                           |
| status   | Icon via `RuntimeStatus.getIcon()`                     |
| cpus     | CPU count                                              |
| memory   | Memory in GiB                                          |
| networks | Network names                                          |
| ips      | IP addresses (monospaced)                              |
| ports    | `PublishedPortLabel` (host:container, link to localhost)|
| sockets  | `PublishedPathLabel` (host:container)                   |
| mounts   | `PublishedPathLabel` (volume sources strip `/volume.img`)|
| actions  | `ContainerActionsView` (start/stop, remove)            |

Selecting a row navigates to `CraneDetailsView`.

### 5.3 Container Detail View

A `TabView` with one tab per log handle. Each tab contains:

* **Left panel:** `ContainerDetailsInfoView` (max width 200) — container ID, CPUs, memory, IPs, ports, sockets, mounts.
* **Right panel:** `ContainerLogsView` — `SelectableLogText` with "Follow Logs" toggle.

Toolbar: start/stop `SpinnerButton`, remove button (trash icon, only when stopped). Both disabled during `transiting`.

### 5.4 Images Tab

A searchable `Table` using `DisclosureTableRow` to show a tree of images → child containers.

| Column  | Content                                              |
|---------|------------------------------------------------------|
| name    | Image reference (with photo.fill icon) or container ID |
| actions | `ImagesActionsView` or `ContainerActionsView`        |

**Toolbar popover (+ button):** TextField for image reference → "Fetch Image" button.

**Image actions:**
* When `.available`: Run button (opens container creation popover) and remove button.
* When `.fetching` or `.removing`: progress indicator.

**Container creation popover (width 400):** Fields for name, executable (placeholder from image entrypoint), arguments (placeholder from image cmd), environment (multi-line), network toggles. Submit via `SpinnerButton`.

### 5.5 Networks Tab

A searchable `Table` using `DisclosureTableRow` to show a tree of networks → child containers.

| Column  | Content                                              |
|---------|------------------------------------------------------|
| name    | Network ID (with network icon) or container ID       |
| ip      | IP address for containers (monospaced)               |
| actions | `ContainerActionsView` for containers                |

**Toolbar popover (+ button):** TextField for network name → "Create Network" button.

### 5.6 Settings

`CraneSettingsView` as a grouped form (`minWidth: 400, minHeight: 320`):

* **General:** Launch at Login toggle (via `LaunchAtLogin.Toggle`).
* **Auto Refresh:** Auto-refresh toggle, list refresh interval (`NumericField`, 1–60s), logs refresh interval (`NumericField`, 1–60s).

### 5.7 Reusable Components

* **`SpinnerButton`** — Button that shows a circular progress indicator when loading.
* **`SelectableLogText`** — NSViewRepresentable wrapping NSTextView. Monospaced font (11pt), gray background, auto-scroll with user-scroll detection.
* **`NumericField`** — NSViewRepresentable wrapping NSTextField with NumberFormatter (min 1, max 60, suffix "s").
* **`PublishedPortLabel`** — `PortLabel(host):PortLabel(container)`. Host port links to `http://localhost:{port}` and has a copy button.
* **`PublishedPathLabel`** — `PathLabel(host):PathLabel(container)`. Host path opens Finder and has a copy button.

## 6. Permissions & Sandboxing

* **Application Groups:** `com.apple.security.application-groups` with:
  * `com.apple.container.apiserver`
  * `com.apple.container`
* These entitlements enable XPC communication with the container runtime service.

## 7. Future Work

* **Dockerfile Building** — Build images from Dockerfiles via BuildKit / `container-builder-shim`.
* **Interactive Terminal Access** — `container.exec()` with stdin/stdout piping and a terminal emulator (e.g., SwiftTerm).
* **Live CPU/Memory Metrics** — Real-time resource usage via Virtualization framework metrics.
* **Volume Creation** — Dedicated UI for creating and managing volumes.
* **Auto-launch Container API Server** — Optionally start `com.apple.container.apiserver` on app launch if not already running.
