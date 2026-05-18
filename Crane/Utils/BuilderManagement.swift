//
//  BuilderManagement.swift
//  Crane
//

import Foundation
import os

/// Outcome of trying to start the BuildKit builder via the `container` CLI after `get(buildkit)` failed.
enum StartBuilderContainerOutcome: Sendable {
    case builderReady
    case failed
    case needsRosettaChoice
}

/// Runs `container builder start` once (no `build.rosetta` changes). Used after the user installs Linux VM Rosetta.
func runContainerBuilderStartOnly() async -> Bool {
    guard let cliURL = containerCLIExecutableURL() else {
        Log.serviceHelper.warning("`container` CLI not found; cannot start BuildKit builder")
        return false
    }
    Log.serviceHelper.info("Running `container builder start` at \(cliURL.path, privacy: .public)")
    let (status, output) = await runContainerCLI(cliURL: cliURL, arguments: ["builder", "start"])
    guard status == 0 else {
        Log.serviceHelper.error("`container builder start` failed with status \(status): \(output, privacy: .public)")
        return false
    }
    Log.serviceHelper.info("`container builder start` succeeded")
    return true
}

/// Sets `build.rosetta` to false and runs `container builder start` (QEMU path). Used when the user opts out of Rosetta.
func startBuilderContainerWithRosettaDisabledViaCLI() async -> Bool {
    guard let cliURL = containerCLIExecutableURL() else {
        Log.serviceHelper.warning("`container` CLI not found; cannot start BuildKit builder")
        return false
    }
    return await startBuilderViaCLIWithRosettaDisabled(cliURL: cliURL)
}

/// First attempt to start the builder: runs `container builder start` only. Does not disable `build.rosetta`.
func startBuilderContainerViaCLI() async -> StartBuilderContainerOutcome {
    guard let cliURL = containerCLIExecutableURL() else {
        Log.serviceHelper.warning("`container` CLI not found; cannot start BuildKit builder")
        return .failed
    }
    Log.serviceHelper.info("Starting BuildKit builder via CLI at \(cliURL.path, privacy: .public)")
    let (status, output) = await runContainerCLI(cliURL: cliURL, arguments: ["builder", "start"])
    if status == 0 {
        Log.serviceHelper.info("`container builder start` succeeded")
        return .builderReady
    }
    if output.contains("Rosetta is not installed") {
        Log.serviceHelper.info("BuildKit bootstrap requires Linux VM Rosetta or user choice to disable build.rosetta")
        return .needsRosettaChoice
    }
    Log.serviceHelper.error("`container builder start` failed with status \(status): \(output, privacy: .public)")
    return .failed
}

private func startBuilderViaCLIWithRosettaDisabled(cliURL: URL) async -> Bool {
    Log.serviceHelper.info("Disabling build.rosetta and starting BuildKit at \(cliURL.path, privacy: .public)")
    let (propStatus, propOut) = await runContainerCLI(
        cliURL: cliURL,
        arguments: ["system", "property", "set", "build.rosetta", "false"]
    )
    if propStatus != 0 {
        Log.serviceHelper.warning(
            "`container system property set build.rosetta false` failed with status \(propStatus): \(propOut, privacy: .public)"
        )
    } else {
        Log.serviceHelper.info("Set build.rosetta to false; retrying `container builder start`")
    }
    let (status, output) = await runContainerCLI(cliURL: cliURL, arguments: ["builder", "start"])
    guard status == 0 else {
        Log.serviceHelper.error("`container builder start` failed with status \(status): \(output, privacy: .public)")
        return false
    }
    Log.serviceHelper.info("`container builder start` succeeded")
    return true
}
