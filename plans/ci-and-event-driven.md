# Plan: ProgressUpdateEvent end-to-end for fetch and build

## Context

The user picked B.2.2 (wire `ProgressUpdateEvent` for fetch/build) and declined to uncomment the CI test job. This plan is therefore scoped to that one direction. The CI half of the original draft is retained as a "follow-up" appendix for when the user reconsiders.

### What I found while exploring

- **`apple/container` 1.0+ exposes no public lifecycle event stream** for containers/images/networks/volumes. The author's own comment in `Crane/Utils/Polling.swift:23` is correct. The `AsyncStream`s in the SDK are for log bytes (`ContainerLogs.swift`) and BuildKit gRPC traffic — neither covers resource lifecycle. So "true event-driven for external changes" is impossible today. (The `CraneMutationBus` + `RefreshCoordinator` already covers self-mutation events.)
- **Fetch progress is already fully wired end-to-end** and does not need a backend change:
  - `ClientImage.fetch(reference:containerSystemConfig:progressUpdate:)` accepts `@Sendable ([ProgressUpdateEvent]) async -> Void`.
  - `Crane/ViewModels/ImagesStore.swift:189` passes a callback that updates `image.fetchProgress?.apply(events)`.
  - `Crane/ViewModels/FetchProgress.swift` is a complete `apply(_:)` over every `ProgressUpdateEvent` case and exposes `fraction`, `bytesDescription`, `itemsDescription`.
  - `Crane/Components/ImageRowView.swift:58` renders a `ProgressView(value: progress.fraction)` + bytes + items counter + sub-description. **Already works.**
- **Build progress is NOT wired**, but for a different reason than fetch:
  - `Builder.build(_ config: BuildConfig)` (`ContainerBuild`) does **not** accept a `progressUpdate` parameter. The build pipeline goes over a separate BuildKit gRPC channel whose events are not surfaced to the `Builder` client the way `ClientImage.fetch` does. The only high-level callbacks in `Builder.BuildConfig` are `terminal`, `quiet`, etc.
  - `Crane/ViewModels/BuildViewModel.runBuildKitClientSession` (`BuildViewModel.swift:330`) writes the export tar to `tempExportURL/appendingPathComponent("out.tar")` and that file grows during the build. Its size is the best available signal.
  - The current `BuildStatus` enum (`BuildViewModel.swift:6`) is coarse: `.startingBuilder`, `.building`, `.unpacking`, `.success`, `.failed`. The placeholder row (`CraneImagesListView.swift:BuildPlaceholderRow`) shows just a spinner + status text, no progress.
  - **There is no fetch-style progress channel exposed by the SDK for builds.** We can only approximate from the export-tar file size, and document the gap.

### Scope of this plan

1. **Confirm + lightly tighten the fetch-progress path.** It already works; add a unit test for `FetchProgress.apply(_:)` over the full event set so regressions are caught, and verify the row in manual smoke.
2. **Add a `BuildProgress` model that polls the on-disk export tar size during `.building`** and exposes `fraction`/`bytesDescription` like `FetchProgress`.
3. **Wire it into `BuildViewModel`** as a published property, fed by a `Task` that polls `FileManager` every ~500 ms while `status == .building`.
4. **Render it in `BuildPlaceholderRow`** next to the existing spinner.
5. **Document the SDK gap** in `BuildViewModel.swift` (a comment explaining why we approximate via file size) so future contributors don't try to "fix" it by reaching into BuildKit gRPC internals.

## Part A — CI test job (NOT in this round; kept as appendix at the bottom)

User decision: do not uncomment the CI test job. They will run tests locally before any change. So this round contains zero CI workflow changes. The CI re-enable plan is preserved below as **Appendix: CI re-enable** for when the user revisits it.

## Part B — ProgressUpdateEvent end-to-end (this round)

### B.1 Files to modify

- `Crane/ViewModels/BuildProgress.swift` — **new**. `@Observable` model mirroring `FetchProgress` shape: `currentSize: Int64`, `totalSize: Int64` (best-effort), `phase: BuildProgressPhase` (`.preparing` / `.building` / `.unpacking`), `fraction: Double?`, `bytesDescription: String?`. No `apply(_:)` because the SDK does not feed us build events (see B.3).
- `Crane/ViewModels/BuildViewModel.swift` — add `var buildProgress: BuildProgress?`; start a `Task` that polls the export-tar file size every ~500 ms while `status == .building`; cancel it on `status != .building` or `.success`/`.failed`. The tar path is the one we already create in `runBuildKitClientSession`: `tempExportURL.appendingPathComponent("out.tar")`. Total size has to be estimated from the resulting image's `clientImage.diskUsage(id:)` post-export, or by sampling over a few seconds; document the approximation in a comment. Add a doc comment explaining why the SDK does not provide a progress callback for `Builder.build(_:)`.
- `Crane/Views/CraneImagesListView.swift` — `BuildPlaceholderRow` gets a new branch: when `status == .building` *and* `buildProgress != nil`, render the live `ProgressView` + bytes label, mirroring `ImageRowView.fetchProgressView`. When `buildProgress == nil`, keep the existing spinner.
- `CraneTests/FetchProgressTests.swift` — **new**, unit test for `FetchProgress.apply(_:)` covering every `ProgressUpdateEvent` case. Cheap; locks down the existing wiring. (`FetchProgressTests` is missing today; `CraneTests/` currently has 19 files, none cover `FetchProgress`.)

### B.2 Reuse

- `Crane/ViewModels/FetchProgress.swift` — shape model (`fraction`, `bytesDescription`, `itemsDescription`) copied 1:1 into `BuildProgress`. Could extract a protocol, but the two have different update paths (one event-driven, one file-poll) and no shared behavior; duplication is fine.
- `Crane/Components/ImageRowView.swift::fetchProgressView` — the visual treatment (linear `ProgressView` + bytes/items caption + sub-description) is exactly what we want for builds. Build a tiny `BuildProgressView` next to `fetchProgressView` to keep the visual language identical; both live in `CraneImagesListView.swift` next to `BuildPlaceholderRow` to avoid scope creep into `ImageRowView`.
- `Crane/Utils/Log.swift` — add `Log.buildProgress` subsystem for the file-poll errors.
- `ByteCountFormatter` — same as `FetchProgress.bytesDescription`.

### B.3 SDK gap to document

`apple/container`'s `Builder.build(_:)` does not accept a `progressUpdate` parameter (only `ClientImage.fetch(...)` does). The build pipeline goes over BuildKit gRPC and the SDK does not surface mid-build progress to `Builder` clients. We approximate by polling the export-tar file size, which is the only on-disk signal during the build. The approximation is best-effort:
- The tar size grows monotonically, so `size / <final-size>` under-estimates until the build finishes.
- "Final size" can be sampled 1–2 seconds after `Builder.build(_:)` returns, when the tar is sealed and the size stabilises.
- If the build fails before sealing the tar, the row jumps to `.failed` with the partial size shown.

This is documented in `BuildViewModel.swift` near the `runBuildKitClientSession` doc comment, so future contributors don't try to "fix" it by reaching into BuildKit gRPC internals or by parsing `BuildStdio`. The right fix is upstream in `apple/container`; the right tracking issue is a single TODO line pointing at `Builder.build(_:)` in the SDK.

### B.4 Steps

- [ ] Add `Crane/ViewModels/BuildProgress.swift` with the model in B.1.
- [ ] Add `CraneTests/FetchProgressTests.swift` covering every `ProgressUpdateEvent` case + computed properties.
- [ ] Edit `Crane/ViewModels/BuildViewModel.swift`:
  - Add `var buildProgress: BuildProgress?` (set to non-nil on entry to `runBuildKitPipeline`, cleared on terminal status).
  - Add a private `pollExportTarSize(...)` `Task` started when `status = .building`, cancelled when leaving `.building`.
  - Add the doc comment from B.3 explaining the SDK limitation.
- [ ] Edit `Crane/Views/CraneImagesListView.swift`:
  - Add a private `BuildProgressView(progress:)` that mirrors `ImageRowView.fetchProgressView` styling.
  - In `BuildPlaceholderRow.trailingControl`, render the new progress view when `viewModel.buildProgress != nil` and `viewModel.status == .building`; fall back to the existing circular `ProgressView` otherwise.
- [ ] Run the full test suite locally: `scripts/test.sh` (user's standing rule).
- [ ] Manual smoke:
  1. `ImageFetchView`: enter `docker.io/library/ubuntu:24.04` (~100 MB). Confirm the Images tab row shows a live `ProgressView` with bytes/items counting up. (Should already work; this is a regression check.)
  2. `ImageBuildView`: paste `FROM alpine:latest\nRUN dd if=/dev/urandom of=/big bs=1M count=200` and build. Confirm the placeholder row shows a live progress bar growing during `.building`, then `.unpacking`, then disappears.
  3. Cancel / fail paths: build a Dockerfile that `RUN exit 1`. Confirm the row jumps to `.failed` and the partial size is shown (or absent if `buildProgress` is nil at failure time).

### B.5 Verification

- `scripts/test.sh` (or `xcodebuild test` per the project test plan) green locally.
- `FetchProgressTests` green; covers full `ProgressUpdateEvent` enum.
- Manual: live progress visible for both fetch and build paths; partial-size visible on failure.
- No new dependencies; uses only `Foundation` and `os.log`.

## Non-goals

- No changes to the public `apple/container` SDK; no vendoring; no BuildKit gRPC interposition.
- No re-enable of the CI test job (deferred per user).
- No `RuntimeEventBus` / `AsyncStream<RuntimeEvent>` (deferred to a follow-up when the SDK gains a real lifecycle event stream).
- No polling-interval changes (B.2.1 from the original draft).
- No new entitlements; no new dependencies.
- No localization work beyond reusing existing keys (`buildInProgress`, `buildUnpacking` already exist).

---

## Appendix: CI test re-enable (follow-up, not this round)

For when the user is ready to revisit CI. Captured here so we don't lose the exploration.

### Test classification (from `CraneTests/`)

- **Unit (13 files, no live apiserver needed):** `AppSettingsTests`, `BuildViewModelPathTests`, `ConnectionHealthTrackerTests`, `ContainerShellLauncherTests`, `CraneErrorDiagnosticTests`, `CraneErrorTests`, `DetailsViewModelFormattingTests`, `DialogStatusTests`, `LogLineFormatterTests`, `PollingTests`, `ResourceNamingTests`, `RunContainerValidationTests`, `RuntimeStatusExtensionsTests`, `StreamReaderTests`
- **Integration (4 files + 1 base; inherit `CraneTestBase` which calls `containerClient.list()` in `setUp()`):** `ContainersStoreTests`, `ImagesStoreTests`, `NetworksStoreTests`, `VolumesStoreTests`
- Integration tests sweep resources in `tearDown` (containers/networks/volumes prefixed `crane-test-`).

### Approach

1. **Test plan file** `CraneTests/CraneUnitTests.xctestplan` listing only the 13 unit test classes. Run on every PR.
2. **Re-enable the `test:` job in `.github/workflows/ci.yml`** to run the unit plan. Add `brew install xcbeautify` to the job.
3. **Optional `integration-tests` job** (`workflow_dispatch` + nightly schedule) that installs `container` from the signed pkg in `apple/container`'s GitHub release, runs `container system start`, then runs the full suite.
4. `scripts/test.sh` gets a `--unit` flag for the unit plan path.

### Files (when re-enabling)

- `CraneTests/CraneUnitTests.xctestplan` — **new**.
- `.github/workflows/ci.yml` — uncomment + harden `test:`; add `integration-tests:`.
- `scripts/test.sh` — `--unit` mode.

### Verification

- `scripts/test.sh --unit` green on a clean `macos-26` runner with no `container` install.
- `scripts/test.sh` (no flag) green on a runner with apiserver up.
- Timing: <2 min for unit suite.
