import AppKit
import Foundation
import ImageIO
import Media
import Store
import UniformTypeIdentifiers

/// made-up cards and generated media for ShelfSnapshotTests; no real clipboard data
struct SnapshotFixtures {
    let directory: URL
    let thumbnails: URL
    let cards: [CardSummary]
    let boards: [Board]
    let representations: @Sendable (Int64) async throws -> [Representation]

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "ShelfSnapshots-\(UUID().uuidString)", directoryHint: .isDirectory)
        thumbnails = directory.appending(path: "Thumbnails", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: thumbnails, withIntermediateDirectories: true)

        let now = Date.now
        let photo = try Self.png(width: 1600, height: 1000, hues: (0.08, 0.6))
        let linkImage = try Self.png(width: 1200, height: 630, hues: (0.55, 0.75))
        try linkImage.write(to: thumbnails.appending(path: "11.png"))
        let report = directory.appending(path: "Quarterly Report.png")
        try Self.png(width: 800, height: 1000, hues: (0.3, 0.45)).write(to: report)
        let notes = directory.appending(path: "Meeting Notes.txt")
        try Data("Agenda\n1. Shelf polish\n2. Release notes\n".utf8).write(to: notes)
        let sketch = directory.appending(path: "Sketch.png")
        try Self.png(width: 600, height: 600, hues: (0.9, 0.1)).write(to: sketch)
        let panorama = try Self.png(width: 2400, height: 600, hues: (0.5, 0.95))
        let portrait = try Self.png(width: 600, height: 1800, hues: (0.15, 0.35))
        let cutout = try Self.png(width: 800, height: 800, hues: (0.7, 0.85), isTransparent: true)

        cards = Self.textCards(now: now) + Self.mediaCards(now: now) + Self.moreCards(now: now)
        boards = [
            Board(id: 1, name: "Work", color: "blue", createdAt: now),
            Board(id: 2, name: "Design", color: "orange", createdAt: now),
            Board(id: 3, name: "Snippets", color: "green", createdAt: now)
        ]

        let richText = try Self.rtf()
        let fileURLs = [report, notes, sketch].map { Data($0.absoluteString.utf8) }
        let byCard: [Int64: [Representation]] = [
            2: [Representation(itemIndex: 0, uti: NSPasteboard.PasteboardType.rtf.rawValue, data: richText)],
            6: [Representation(itemIndex: 0, uti: UTType.png.identifier, data: photo)],
            7: [Representation(itemIndex: 0, uti: "public.file-url", data: fileURLs[0])],
            8: [
                Representation(itemIndex: 0, uti: "public.file-url", data: fileURLs[1]),
                Representation(itemIndex: 1, uti: "public.file-url", data: fileURLs[2]),
                Representation(itemIndex: 2, uti: "public.file-url", data: fileURLs[0])
            ],
            9: [Representation(itemIndex: 0, uti: UTType.png.identifier, data: panorama)],
            10: [Representation(itemIndex: 0, uti: UTType.png.identifier, data: portrait)],
            11: [Representation(itemIndex: 0, uti: UTType.png.identifier, data: cutout)]
        ]
        representations = { byCard[$0] ?? [] }
    }

    private static func textCards(now: Date) -> [CardSummary] {
        [
            CardSummary(
                id: 1,
                kind: .text,
                preview: "Remember to pick up the framed print from the gallery on Thursday before six. "
                    + "The receipt is in the blue folder on the shelf by the door.",
                metadata: #"{"characterCount":142,"lineCount":1,"wordCount":27}"#,
                sourceApp: SourceApp(bundleID: "com.apple.iCal", name: "Calendar"),
                createdAt: now.addingTimeInterval(-120)
            ),
            CardSummary(
                id: 2,
                kind: .text,
                title: "Launch Plan",
                preview: "Quarterly plan\nShip the shelf by Friday.",
                metadata: #"{"characterCount":41,"lineCount":2,"wordCount":7}"#,
                sourceApp: SourceApp(bundleID: "com.apple.Notes", name: "Notes"),
                createdAt: now.addingTimeInterval(-600)
            ),
            CardSummary(
                id: 3,
                kind: .link,
                preview: "https://www.example.com/articles/designing-for-the-desktop",
                metadata: #"{"pageTitle":"Designing for the Desktop","pixelWidth":1200,"pixelHeight":630,"#
                    + #""url":"https://www.example.com/articles/designing-for-the-desktop"}"#,
                sourceApp: SourceApp(bundleID: "com.apple.Safari", name: "Safari"),
                createdAt: now.addingTimeInterval(-1800),
                contentHash: "11"
            ),
            CardSummary(
                id: 4,
                kind: .color,
                preview: "#FF9F0A",
                metadata: ##"{"color":"#FF9F0A"}"##,
                sourceApp: SourceApp(bundleID: "com.apple.dt.Xcode", name: "Xcode"),
                createdAt: now.addingTimeInterval(-3600),
                boardID: 2
            ),
            CardSummary(
                id: 5,
                kind: .text,
                preview: "func greet(_ name: String) -> String {\n    let greeting = \"Hello, \\(name)\"\n"
                    + "    return greeting\n}",
                metadata: #"{"characterCount":92,"lineCount":4,"wordCount":11}"#,
                sourceApp: SourceApp(bundleID: "com.apple.Terminal", name: "Terminal"),
                createdAt: now.addingTimeInterval(-7200)
            )
        ]
    }

    private static func mediaCards(now: Date) -> [CardSummary] {
        [
            CardSummary(
                id: 6,
                kind: .image,
                metadata: #"{"pixelWidth":1600,"pixelHeight":1000}"#,
                sourceApp: SourceApp(bundleID: "com.apple.Preview", name: "Preview"),
                createdAt: now.addingTimeInterval(-86400),
                contentHash: "12"
            ),
            CardSummary(
                id: 7,
                kind: .file,
                metadata: #"{"fileNames":["Quarterly Report.png"]}"#,
                sourceApp: SourceApp(bundleID: "com.apple.finder", name: "Finder"),
                createdAt: now.addingTimeInterval(-172_800)
            ),
            CardSummary(
                id: 8,
                kind: .file,
                metadata: #"{"fileNames":["Meeting Notes.txt","Sketch.png","Quarterly Report.png"],"#
                    + #""totalFileSize":2400000}"#,
                sourceApp: SourceApp(bundleID: "com.apple.mail", name: "Mail"),
                createdAt: now.addingTimeInterval(-259_200)
            )
        ]
    }

    private static func moreCards(now: Date) -> [CardSummary] {
        [
            CardSummary(
                id: 9,
                kind: .image,
                metadata: #"{"pixelWidth":2400,"pixelHeight":600}"#,
                sourceApp: SourceApp(bundleID: "com.apple.iBooksX", name: "Books"),
                createdAt: now.addingTimeInterval(-345_600),
                contentHash: "13"
            ),
            CardSummary(
                id: 10,
                kind: .image,
                metadata: #"{"pixelWidth":600,"pixelHeight":1800}"#,
                sourceApp: SourceApp(bundleID: "com.apple.MobileSMS", name: "Messages"),
                createdAt: now.addingTimeInterval(-432_000),
                contentHash: "14"
            ),
            CardSummary(
                id: 11,
                kind: .image,
                metadata: #"{"pixelWidth":800,"pixelHeight":800}"#,
                sourceApp: SourceApp(bundleID: "com.apple.news", name: "News"),
                createdAt: now.addingTimeInterval(-518_400),
                contentHash: "15"
            ),
            CardSummary(
                id: 12,
                kind: .link,
                preview: "https://www.example.org/guides/keyboard-shortcuts",
                metadata: #"{"pageTitle":"Keyboard Shortcuts Guide","#
                    + #""url":"https://www.example.org/guides/keyboard-shortcuts"}"#,
                sourceApp: SourceApp(bundleID: "com.apple.shortcuts", name: "Shortcuts"),
                createdAt: now.addingTimeInterval(-604_800)
            ),
            CardSummary(
                id: 13,
                kind: .text,
                preview: "Episode 12 at 18:30",
                metadata: #"{"characterCount":19,"lineCount":1,"wordCount":4}"#,
                sourceApp: SourceApp(bundleID: "com.apple.podcasts", name: "Podcasts"),
                createdAt: now.addingTimeInterval(-691_200)
            ),
            CardSummary(
                id: 14,
                kind: .color,
                preview: "#1C1C1E",
                metadata: ##"{"color":"#1C1C1E"}"##,
                sourceApp: SourceApp(bundleID: "com.apple.freeform", name: "Freeform"),
                createdAt: now.addingTimeInterval(-777_600)
            ),
            CardSummary(
                id: 15,
                kind: .unknown,
                metadata: #"{"typeIdentifier":"com.example.sample-item"}"#,
                createdAt: now.addingTimeInterval(-864_000)
            )
        ]
    }

    private static func rtf() throws -> Data {
        let text = NSMutableAttributedString(string: "Quarterly plan\n", attributes: [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.systemIndigo
        ])
        text.append(NSAttributedString(string: "Ship the shelf by Friday.", attributes: [
            .font: NSFont.systemFont(ofSize: 13)
        ]))
        return try text.data(
            from: NSRange(location: 0, length: text.length),
            documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
        )
    }

    private static func png(
        width: Int,
        height: Int,
        hues: (CGFloat, CGFloat),
        isTransparent: Bool = false
    ) throws -> Data {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
            let gradient = CGGradient(colorsSpace: colorSpace, colors: [
                NSColor(hue: hues.0, saturation: 0.7, brightness: 0.9, alpha: 1).cgColor,
                NSColor(hue: hues.1, saturation: 0.6, brightness: 0.5, alpha: 1).cgColor
            ] as CFArray, locations: nil)
        else { throw FixtureError.drawingFailed }
        if isTransparent {
            let inset = CGFloat(min(width, height)) / 8
            context.addEllipse(in: CGRect(x: 0, y: 0, width: width, height: height).insetBy(dx: inset, dy: inset))
            context.clip()
        }
        context.drawLinearGradient(
            gradient,
            start: .zero,
            end: CGPoint(x: width, y: height),
            options: []
        )
        let data = NSMutableData()
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { throw FixtureError.drawingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError.drawingFailed }
        return data as Data
    }

    enum FixtureError: Error {
        case drawingFailed
    }
}
