import AppKit
import Testing
import UniformTypeIdentifiers
@testable import ShelfUI

struct OpenWithApplicationTests {
    private static let preview = URL(filePath: "/Applications/Preview.app")
    private static let zed = URL(filePath: "/Applications/Zed.app")
    private static let acrobat = URL(filePath: "/Applications/Acrobat.app")
    private static let mail = URL(filePath: "/Applications/Mail.app")

    private static func lookup(
        _ applications: [UTType: [URL]],
        defaults: [UTType: URL] = [:]
    ) -> OpenWithApplication.Lookup {
        OpenWithApplication.Lookup(
            applications: { applications[$0] ?? [] },
            defaultApplication: { defaults[$0] },
            name: { $0.deletingPathExtension().lastPathComponent },
            icon: { _ in NSImage() }
        )
    }

    @Test func `lists only apps that open every file type`() {
        let lookup = Self.lookup([
            .pdf: [Self.zed, Self.preview, Self.acrobat],
            .png: [Self.preview, Self.mail, Self.zed]
        ])

        let applications = OpenWithApplication.applications(forFileNames: ["a.pdf", "b.png"], lookup: lookup)

        #expect(applications.map(\.url) == [Self.preview, Self.zed])
    }

    @Test func `default app comes first and the rest are sorted by name`() {
        let lookup = Self.lookup(
            [.pdf: [Self.zed, Self.preview, Self.acrobat]],
            defaults: [.pdf: Self.preview]
        )

        let applications = OpenWithApplication.applications(forFileNames: ["a.pdf"], lookup: lookup)

        #expect(applications.map(\.url) == [Self.preview, Self.acrobat, Self.zed])
        #expect(applications.map(\.isDefault) == [true, false, false])
    }

    @Test func `default app that cannot open every file type is dropped`() {
        let lookup = Self.lookup(
            [.pdf: [Self.acrobat, Self.preview], .png: [Self.preview]],
            defaults: [.pdf: Self.acrobat]
        )

        let applications = OpenWithApplication.applications(forFileNames: ["a.pdf", "b.png"], lookup: lookup)

        #expect(applications.map(\.url) == [Self.preview])
        #expect(applications.map(\.isDefault) == [false])
    }
}
