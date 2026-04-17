import Foundation
import Observation
import Sparkle

/// Thin wrapper around Sparkle's `SPUStandardUpdaterController`. Owns the
/// updater lifetime for the process and exposes a couple of convenience
/// properties to SwiftUI views.
///
/// The heavy lifting (feed fetching, EdDSA verification, downloaded-zip
/// unpacking, app relaunch) is all Sparkle's job. We just surface the
/// "Check for updates…" action and the canCheck flag.
@MainActor
@Observable
final class UpdaterManager {
    let controller: SPUStandardUpdaterController

    var canCheckForUpdates: Bool {
        controller.updater.canCheckForUpdates
    }

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller.checkForUpdates(nil)
    }
}
