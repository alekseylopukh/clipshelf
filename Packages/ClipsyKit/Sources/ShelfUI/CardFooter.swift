import DesignSystem
import Store
import SwiftUI

struct CardFooter: View {
    let kind: CardKind
    let content: CardContent

    var body: some View {
        Group {
            switch kind {
            case .text:
                if content.isCodeLike, let lines = content.metadata.lineCount {
                    Text("\(lines) lines", comment: "Card footer: number of lines in a code-like text card")
                } else if let characters = content.metadata.characterCount {
                    Text("\(characters) characters", comment: "Card footer: number of characters in a text card")
                }
            case .link:
                if let url = content.metadata.url {
                    Text(verbatim: url)
                        .truncationMode(.head)
                }
            case .image:
                if let width = content.metadata.pixelWidth, let height = content.metadata.pixelHeight {
                    Text(
                        "\(width.formatted(.number.grouping(.never))) × \(height.formatted(.number.grouping(.never)))",
                        comment: "Card footer: pixel width and height of an image card"
                    )
                }
            case .file:
                if let names = content.metadata.fileNames, names.count > 1 {
                    if let size = content.metadata.totalFileSize {
                        Text(
                            "\(names.count) files, \(Int64(size), format: .byteCount(style: .file))",
                            comment: "Card footer: number of files and their total size"
                        )
                    } else {
                        Text("\(names.count) files", comment: "Card footer: number of files in a card")
                    }
                } else if let name = content.metadata.fileNames?.first {
                    Text(verbatim: name)
                        .truncationMode(.middle)
                }
            case .color:
                if let color = content.metadata.color {
                    Text(verbatim: color)
                }
            case .unknown:
                if let type = content.metadata.typeIdentifier {
                    Text(verbatim: type)
                        .truncationMode(.middle)
                }
            }
        }
        .metadataStyle()
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
