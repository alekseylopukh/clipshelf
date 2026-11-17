import Foundation
import Observation

@MainActor
@Observable
public final class PrivacySettings {
    public static let ignoredAppsKey = "IgnoredApps"
    public static let ignoresConcealedKey = "IgnoreConcealedContent"
    public static let ignoresTransientKey = "IgnoreTransientContent"
    public static let showsShelfInScreenCaptureKey = "ShowShelfInScreenCapture"
    public static let recognizesTextInImagesKey = "RecognizeTextInImages"
    public static let fetchesLinkPreviewsKey = "FetchLinkPreviews"

    public private(set) var ignoredBundleIDs: [String] {
        didSet { defaults.set(ignoredBundleIDs, forKey: Self.ignoredAppsKey) }
    }

    public var ignoresConcealed: Bool {
        didSet { defaults.set(ignoresConcealed, forKey: Self.ignoresConcealedKey) }
    }

    public var ignoresTransient: Bool {
        didSet { defaults.set(ignoresTransient, forKey: Self.ignoresTransientKey) }
    }

    public var showsShelfInScreenCapture: Bool {
        didSet { defaults.set(showsShelfInScreenCapture, forKey: Self.showsShelfInScreenCaptureKey) }
    }

    public var recognizesTextInImages: Bool {
        didSet { defaults.set(recognizesTextInImages, forKey: Self.recognizesTextInImagesKey) }
    }

    public var fetchesLinkPreviews: Bool {
        didSet { defaults.set(fetchesLinkPreviews, forKey: Self.fetchesLinkPreviewsKey) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        ignoredBundleIDs = defaults.stringArray(forKey: Self.ignoredAppsKey) ?? [CapturePolicy.applePasswordsBundleID]
        ignoresConcealed = defaults.object(forKey: Self.ignoresConcealedKey) as? Bool ?? true
        ignoresTransient = defaults.object(forKey: Self.ignoresTransientKey) as? Bool ?? true
        showsShelfInScreenCapture = defaults.bool(forKey: Self.showsShelfInScreenCaptureKey)
        recognizesTextInImages = defaults.object(forKey: Self.recognizesTextInImagesKey) as? Bool ?? true
        fetchesLinkPreviews = defaults.bool(forKey: Self.fetchesLinkPreviewsKey)
    }

    public var capturePolicy: CapturePolicy {
        CapturePolicy(
            ignoredBundleIDs: Set(ignoredBundleIDs),
            ignoresConcealed: ignoresConcealed,
            ignoresTransient: ignoresTransient
        )
    }

    public func ignoreApps(withBundleIDs bundleIDs: [String]) {
        for bundleID in bundleIDs where !ignoredBundleIDs.contains(bundleID) {
            ignoredBundleIDs.append(bundleID)
        }
    }

    public func stopIgnoringApps(withBundleIDs bundleIDs: Set<String>) {
        ignoredBundleIDs.removeAll { bundleIDs.contains($0) }
    }
}
