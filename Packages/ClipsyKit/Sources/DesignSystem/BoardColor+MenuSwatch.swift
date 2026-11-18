import AppKit

public extension BoardColor {
    /// a palette symbol, because menus draw SwiftUI symbols as monochrome templates
    var menuSwatch: NSImage {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [nsColor])
        guard let image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)
        else { fatalError("circle.fill is a built-in SF Symbol") }
        return image
    }
}
