import Foundation
import Sparkle

@MainActor
public final class SparkleUpdaterDriver: UpdaterDriver {
    private let updater: SPUUpdater

    public init(bundle: Bundle = .main) {
        updater = SPUUpdater(
            hostBundle: bundle,
            applicationBundle: bundle,
            userDriver: SPUStandardUserDriver(hostBundle: bundle, delegate: nil),
            delegate: nil
        )
    }

    public var automaticallyChecksForUpdates: Bool {
        get { updater.automaticallyChecksForUpdates }
        set { updater.automaticallyChecksForUpdates = newValue }
    }

    public func start() throws {
        try updater.start()
    }

    public func checkForUpdates() {
        updater.checkForUpdates()
    }
}
