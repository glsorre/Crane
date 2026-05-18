//
//  ContainerServiceManagement.swift
//  Crane
//

import ContainerPlugin
import Foundation
import os

struct StartServiceResult {
    let success: Bool
    let cliPath: String?
    let stderr: String?
    let plistFound: Bool
}

private func startContainerServiceViaCLI(cliURL: URL) async -> StartServiceResult {
    Log.serviceHelper.info("Starting container services via CLI at \(cliURL.path, privacy: .public)")
    let (status, output) = await runProcessCollectingOutput(
        executableURL: cliURL,
        arguments: ["system", "start", "--disable-kernel-install"]
    )
    let stderr = output.isEmpty ? nil : output
    guard status == 0 else {
        if let stderr {
            Log.serviceHelper.error(
                "`container system start --disable-kernel-install` failed with status \(status): \(stderr, privacy: .public)"
            )
        } else {
            Log.serviceHelper.error("`container system start --disable-kernel-install` failed with status \(status)")
        }
        return StartServiceResult(success: false, cliPath: cliURL.path, stderr: stderr, plistFound: true)
    }
    Log.serviceHelper.info("`container system start --disable-kernel-install` succeeded")
    return StartServiceResult(success: true, cliPath: cliURL.path, stderr: stderr, plistFound: true)
}

private func startContainerServiceViaPlistBootstrap() async -> StartServiceResult {
    let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    let plistURL = appSupport.appendingPathComponent("com.apple.container/apiserver/apiserver.plist")

    guard FileManager.default.fileExists(atPath: plistURL.path) else {
        Log.serviceHelper.warning("Plist not found at \(plistURL.path) — user must run `container system start` once")
        return StartServiceResult(success: false, cliPath: nil, stderr: nil, plistFound: false)
    }

    do {
        let data = try Data(contentsOf: plistURL)
        try data.write(to: plistURL, options: .atomic)
        Log.serviceHelper.info("Re-wrote plist to refresh file state")
    } catch {
        Log.serviceHelper.error("Failed to re-write plist: \(error.localizedDescription)")
    }

    do {
        try ServiceManager.register(plistPath: plistURL.path)
        Log.serviceHelper.info("ServiceManager.register() succeeded")
        return StartServiceResult(success: true, cliPath: nil, stderr: nil, plistFound: true)
    } catch {
        Log.serviceHelper.error("ServiceManager.register() failed: \(error.localizedDescription)")
        return StartServiceResult(success: false, cliPath: nil, stderr: error.localizedDescription, plistFound: true)
    }
}

func startContainerService() async -> StartServiceResult {
    if let cliURL = containerCLIExecutableURL() {
        return await startContainerServiceViaCLI(cliURL: cliURL)
    }

    Log.serviceHelper.warning("`container` CLI not found; falling back to launchd plist bootstrap")
    return await startContainerServiceViaPlistBootstrap()
}
