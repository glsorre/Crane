//
//  BuildProgress.swift
//  Crane
//
//  Live build progress for `BuildViewModel`. Mirrors the shape of
//  `FetchProgress` so the placeholder row in `CraneImagesListView` can
//  render the same visual treatment for both fetch and build operations.
//
//  Unlike `FetchProgress` — which is driven by `ProgressUpdateEvent`
//  callbacks delivered by `ClientImage.fetch(...)` — build progress
//  cannot be sourced from `apple/container`'s `Builder.build(_:)`
//  (see the SDK-gap note in `BuildViewModel.swift`). Instead, this model
//  is fed by a file-size poll against the export tar written by
//  `Builder.BuildExport`. The "total" is best-effort: the tar is
//  streamed and its final size is not knowable until the build seals it,
//  so `fraction` is `nil` until a stable size is observed and may
//  briefly under-report.
//

import Foundation
import Observation

enum BuildProgressPhase: String, Sendable {
    case preparing
    case building
    case unpacking
}

@Observable
final class BuildProgress: Identifiable {
    let id = UUID()

    /// Bytes observed on disk for the export tar. Monotonically
    /// non-decreasing for the lifetime of a build; reset to `0` on a new
    /// build.
    var currentSize: Int64 = 0

    /// Best-effort final size. `nil` while the tar is still being
    /// streamed. Once the build finishes and the size stabilises, the
    /// owning task freezes this value so the row shows a final fraction.
    var totalSize: Int64? = nil

    /// Coarse phase, derived from the calling `BuildStatus`. Drives the
    /// "preparing / building / unpacking" caption.
    var phase: BuildProgressPhase = .preparing

    /// True once the build has sealed the tar and `totalSize` is fixed.
    /// Used by the UI to switch from indeterminate (`ProgressView()`) to
    /// determinate (`ProgressView(value:)`) rendering.
    var isFinalised: Bool = false

    /// Computed fraction in `0.0...1.0`. `nil` while indeterminate.
    var fraction: Double? {
        guard let total = totalSize, total > 0 else { return nil }
        return min(1.0, Double(currentSize) / Double(total))
    }

    /// Localised byte description, e.g. `"12.3 MB / 50.0 MB"` or just
    /// `"12.3 MB"` when the total is unknown. `nil` when no bytes have
    /// been observed yet.
    var bytesDescription: String? {
        guard currentSize > 0 || (totalSize ?? 0) > 0 else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        let current = formatter.string(fromByteCount: currentSize)
        if let totalSize, totalSize > 0 {
            let total = formatter.string(fromByteCount: totalSize)
            return "\(current) / \(total)"
        }
        return current
    }

    /// Human-readable phase label, suitable for the row's subtitle.
    var phaseDescription: String {
        switch phase {
        case .preparing:
            return String(localized: "buildStarting")
        case .building:
            return String(localized: "buildInProgress")
        case .unpacking:
            return String(localized: "buildUnpacking")
        }
    }

    /// Updates the observed size. Called by the file-poll task in
    /// `BuildViewModel`. `size` is clamped to `>= 0`; negative values
    /// (which `FileManager` can return for a deleted file) are ignored.
    func updateCurrentSize(_ size: Int64) {
        guard size >= 0 else { return }
        currentSize = max(currentSize, size)
    }

    /// Freezes the final size. After this call `fraction` is non-nil and
    /// `bytesDescription` shows `"current / total"`. Idempotent: later
    /// calls with the same or smaller value are no-ops; a larger value
    /// is treated as the new ground truth (handles a tar that grew
    /// briefly after sealing).
    func finalise(totalSize finalTotal: Int64) {
        guard finalTotal >= 0 else { return }
        if let existing = totalSize {
            totalSize = max(existing, finalTotal)
        } else {
            totalSize = finalTotal
        }
        currentSize = max(currentSize, totalSize ?? 0)
        isFinalised = true
    }
}
