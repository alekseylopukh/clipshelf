import AppKit
import DesignSystem
import Store
import UniformTypeIdentifiers

struct OpenWithApplication: Identifiable, Sendable {
    let url: URL
    let name: String
    let icon: NSImage
    let isDefault: Bool

    var id: URL {
        url
    }

    struct Lookup: Sendable {
        var applications: @Sendable (UTType) -> [URL]
        var defaultApplication: @Sendable (UTType) -> URL?
        var name: @Sendable (URL) -> String
        var icon: @Sendable (URL) -> NSImage

        static let workspace = Lookup(
            applications: { NSWorkspace.shared.urlsForApplications(toOpen: $0) },
            defaultApplication: { NSWorkspace.shared.urlForApplication(toOpen: $0) },
            name: { FileManager.default.displayName(atPath: $0.path(percentEncoded: false)) },
            icon: { url in
                let icon = NSWorkspace.shared.icon(forFile: url.path(percentEncoded: false))
                icon.size = NSSize(width: DesignTokens.menuIconSize, height: DesignTokens.menuIconSize)
                return icon
            }
        )
    }

    @concurrent
    static func applications(for card: CardSummary, lookup: Lookup = .workspace) async -> [Self] {
        card.kind == .file ? applications(forFileNames: card.decodedMetadata.fileNames ?? [], lookup: lookup) : []
    }

    static func applications(forFileNames names: [String], lookup: Lookup) -> [Self] {
        let types = names.map { UTType(filenameExtension: ($0 as NSString).pathExtension) ?? .data }
        guard let first = types.first else { return [] }
        var shared = lookup.applications(first)
        for type in types.dropFirst() {
            let urls = Set(lookup.applications(type))
            shared.removeAll { !urls.contains($0) }
        }
        let defaultURL = lookup.defaultApplication(first).flatMap { shared.contains($0) ? $0 : nil }
        let others = shared.filter { $0 != defaultURL }
            .map { application($0, lookup: lookup, isDefault: false) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard let defaultURL else { return others }
        return [application(defaultURL, lookup: lookup, isDefault: true)] + others
    }

    private static func application(_ url: URL, lookup: Lookup, isDefault: Bool) -> Self {
        Self(url: url, name: lookup.name(url), icon: lookup.icon(url), isDefault: isDefault)
    }
}
