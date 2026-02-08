# Crane

Native macOS GUI for [Apple Containers](https://github.com/apple/container).

Also known as **Right Crane**.

!["containers list"](screenshots/screenshot_001.png)

## Features

- **Container lifecycle** — Create, start, stop, and remove containers with extensive configuration (ports, volumes, env vars, networks, resource limits, DNS, sysctls, Rosetta)
- **Image building** — Build images from Dockerfiles with an in-app editor and syntax highlighting
- **Image management** — Pull and manage OCI images
- **Volume management** — Create and prune volumes
- **Network management** — Create networks and attach containers
- **Log streaming** — Real-time container logs with per-handle tabs and follow mode
- **Adaptive polling** — Exponential backoff reduces CPU usage when idle, resets on changes
- **Auto service startup** — Automatically starts the container API service on launch
- **Liquid Glass UI** — Native macOS 26 design language

## Requirements

- macOS 26 (Tahoe)
- Apple silicon
- [Apple container cli tool](https://github.com/apple/container)

## Building

```sh
xcodebuild -project Crane.xcodeproj -scheme Crane build
```

Or open `Crane.xcodeproj` in Xcode and build normally.

## Roadmap

- [x] Container listing with network grouping
- [x] Container management (start, stop, remove)
- [x] Container creation with full configuration
- [x] Container log streaming grouped by handle
- [x] Adaptive polling
- [x] Volume listing and management
- [x] Image listing and fetching
- [x] Image building from Dockerfiles
- [x] Network creation
- [x] Automatic API service startup
- [ ] Interactive terminal
- [ ] Live resource metrics

## Contributing

The project is in active development — contributions are welcome.
