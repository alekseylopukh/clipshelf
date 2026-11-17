import Foundation
import os
import ShelfUI

extension ClipsyApp {
    private static let urlSchemeLogger = Logger(subsystem: "app.gonar.clipsy", category: "URLScheme")

    static func open(_ urls: [URL], shelf: ShelfController) {
        for url in urls {
            switch URLRoute(url) {
            case .openShelf: shelf.show()
            case let .search(text): shelf.showSearch(for: text)
            case let .newTextCard(text): shelf.showNewTextCard(text: text)
            case .openSettings: SettingsWindow.open()
            case nil: urlSchemeLogger.error("ignored a URL with an unknown route")
            }
        }
    }
}
