import CoreGraphics
import Vision

public struct VisionTextRecognizer: TextRecognizing {
    public init() {}

    @concurrent
    public func recognizeText(in image: CGImage) async throws -> String {
        var request = RecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.automaticallyDetectsLanguage = true
        return try await request.perform(on: image).map(\.transcript).joined(separator: "\n")
    }
}
