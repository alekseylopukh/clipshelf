import CoreGraphics

public protocol TextRecognizing: Sendable {
    func recognizeText(in image: CGImage) async throws -> String
}
