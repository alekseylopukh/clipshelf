import CoreGraphics
import Foundation
import ImageIO
import os
import Store
import UniformTypeIdentifiers

public actor TextRecognitionQueue {
    private let repository: CardRepository
    private let recognizer: any TextRecognizing
    private let logger = Logger(subsystem: "app.gonar.clipsy", category: "TextRecognition")
    private let wakeups: AsyncStream<Void>
    private let wake: AsyncStream<Void>.Continuation
    private var isEnabled = false

    public init(repository: CardRepository, recognizer: any TextRecognizing = VisionTextRecognizer()) {
        self.repository = repository
        self.recognizer = recognizer
        (wakeups, wake) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if enabled {
            wake.yield()
        }
    }

    public func run() async throws {
        try await withThrowingDiscardingTaskGroup { group in
            group.addTask { [repository, wake] in
                for try await _ in repository.observeTextRecognitionBacklog() {
                    wake.yield()
                }
            }
            for await _ in wakeups {
                try await recognizePendingCards()
            }
        }
    }

    func recognizePendingCards() async throws {
        while isEnabled, let id = try await repository.nextCardAwaitingTextRecognition() {
            try Task.checkCancellation()
            do {
                let representations = try await repository.representations(of: id)
                guard let image = await Self.decodedImage(from: representations) else {
                    throw Failure.undecodableImage
                }
                let text = try await recognizer.recognizeText(in: image)
                try await repository.saveRecognizedText(text, ofCard: id)
            } catch {
                if Task.isCancelled {
                    throw CancellationError()
                }
                logger.error(
                    "text recognition failed for card \(id, privacy: .public): \(String(describing: type(of: error)), privacy: .public)"
                )
                try await repository.markTextRecognitionFailed(ofCard: id)
            }
        }
    }

    @concurrent
    private static func decodedImage(from representations: [Representation]) async -> CGImage? {
        for representation in representations {
            guard let type = UTType(representation.uti), type.conforms(to: .image) || type.conforms(to: .pdf),
                  let source = CGImageSourceCreateWithData(representation.data as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else { continue }
            return image
        }
        return nil
    }

    private enum Failure: Error {
        case undecodableImage
    }
}
