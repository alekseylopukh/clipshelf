import Foundation

enum ColorFormat: CaseIterable, Identifiable {
    case hex
    case rgb
    case hsl

    var id: Self {
        self
    }

    var label: LocalizedStringResource {
        switch self {
        case .hex: LocalizedStringResource("Hex", comment: "Label of a color's hexadecimal value in the preview")
        case .rgb: LocalizedStringResource(
                "RGB",
                comment: "Label of a color's red, green and blue value in the preview"
            )
        case .hsl: LocalizedStringResource(
                "HSL",
                comment: "Label of a color's hue, saturation and lightness value in the preview"
            )
        }
    }
}
