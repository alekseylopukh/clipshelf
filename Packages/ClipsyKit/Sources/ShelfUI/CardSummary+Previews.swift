import Foundation
import Store

extension CardSummary {
    static let previewCards: [CardSummary] = [
        CardSummary(
            id: 1,
            kind: .text,
            preview: "Remember to pick up the framed print from the gallery on Thursday before six.",
            metadata: #"{"characterCount":79,"lineCount":1,"wordCount":14}"#,
            sourceApp: SourceApp(bundleID: "com.apple.TextEdit", name: "TextEdit"),
            createdAt: .now.addingTimeInterval(-120)
        ),
        CardSummary(
            id: 2,
            kind: .text,
            preview: "func greet(_ name: String) -> String {\n    let greeting = \"Hello, \\(name)\"\n    return greeting\n}",
            metadata: #"{"characterCount":92,"lineCount":4,"wordCount":11}"#,
            sourceApp: SourceApp(bundleID: "com.apple.dt.Xcode", name: "Xcode"),
            createdAt: .now.addingTimeInterval(-900)
        ),
        CardSummary(
            id: 3,
            kind: .link,
            preview: "https://developer.apple.com/design/human-interface-guidelines/materials",
            metadata: #"{"url":"https://developer.apple.com/design/human-interface-guidelines/materials"}"#,
            sourceApp: SourceApp(bundleID: "com.apple.Safari", name: "Safari"),
            createdAt: .now.addingTimeInterval(-3600)
        ),
        CardSummary(
            id: 4,
            kind: .color,
            title: "Accent",
            preview: "#FF9F0A",
            metadata: ##"{"color":"#FF9F0A"}"##,
            sourceApp: SourceApp(bundleID: "com.apple.Notes", name: "Notes"),
            createdAt: .now.addingTimeInterval(-86400)
        ),
        CardSummary(
            id: 5,
            kind: .unknown,
            metadata: #"{"typeIdentifier":"com.example.private-format"}"#,
            createdAt: .now.addingTimeInterval(-172_800)
        )
    ]
}
