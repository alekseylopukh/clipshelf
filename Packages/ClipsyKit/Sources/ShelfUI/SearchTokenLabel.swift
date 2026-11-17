import DesignSystem
import Store
import SwiftUI

struct SearchTokenLabel: View {
    let token: SearchToken
    let title: String
    let boards: [Board]

    var body: some View {
        Label {
            Text(title)
        } icon: {
            switch token {
            case let .kind(kind):
                Image(systemName: kind.symbolName)
            case let .app(app):
                AppIconView(
                    bundleID: app.bundleID,
                    fallbackSymbol: SearchToken.Category.app.symbolName,
                    size: DesignTokens.menuIconSize
                )
            case .date:
                Image(systemName: SearchToken.Category.date.symbolName)
            case let .board(id):
                Circle()
                    .fill((boards.first { $0.id == id }.flatMap { BoardColor(rawValue: $0.color) } ?? .gray).color)
                    .frame(width: DesignTokens.boardDotSize, height: DesignTokens.boardDotSize)
            }
        }
        .lineLimit(1)
    }
}
