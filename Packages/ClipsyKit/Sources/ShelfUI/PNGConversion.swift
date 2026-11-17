import Foundation
import ImageIO
import Store
import UniformTypeIdentifiers

enum PNGConversion {
    static func pngData(from representations: [Representation]) -> Data? {
        if let png = representations.first(where: { $0.uti == UTType.png.identifier }) {
            return png.data
        }
        guard let image = representations.first(where: { UTType($0.uti)?.conforms(to: .image) ?? false }),
              let source = CGImageSourceCreateWithData(image.data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, cgImage, nil)
        return CGImageDestinationFinalize(destination) ? data as Data : nil
    }
}
