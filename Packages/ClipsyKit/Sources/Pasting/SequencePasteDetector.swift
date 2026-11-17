import Foundation
import Store

@MainActor
public final class SequencePasteDetector {
    public enum Mechanism {
        case dataProvider
        case pasteKey(any PasteKeyMonitoring)
    }

    public static let settleDelay = Duration.milliseconds(250)

    public let pastedEntryIDs: AsyncStream<PasteSequence.Entry.ID>

    private let mechanism: Mechanism
    private let writer: PasteboardWriter
    private let settleDelay: Duration
    private let signals: AsyncStream<Int>
    private let signalContinuation: AsyncStream<Int>.Continuation
    private let pastedContinuation: AsyncStream<PasteSequence.Entry.ID>.Continuation
    private var published: (token: Int, entryID: PasteSequence.Entry.ID)?
    private var lastToken = 0

    public init(mechanism: Mechanism, writer: PasteboardWriter, settleDelay: Duration = settleDelay) {
        self.mechanism = mechanism
        self.writer = writer
        self.settleDelay = settleDelay
        (signals, signalContinuation) = AsyncStream.makeStream()
        (pastedEntryIDs, pastedContinuation) = AsyncStream.makeStream()
    }

    deinit {
        signalContinuation.finish()
        pastedContinuation.finish()
    }

    public func publish(
        _ entryID: PasteSequence.Entry.ID,
        representations: [Representation],
        plainTextOnly: Bool
    ) {
        lastToken += 1
        let token = lastToken
        published = (token, entryID)
        switch mechanism {
        case .dataProvider:
            writer.writeLazily(representations, plainTextOnly: plainTextOnly) { [signalContinuation] in
                signalContinuation.yield(token)
            }
        case .pasteKey:
            writer.write(representations, plainTextOnly: plainTextOnly)
        }
    }

    /// whether `entryID` is still published and on the pasteboard, unpasted
    public func holdsPublication(of entryID: PasteSequence.Entry.ID) -> Bool {
        published?.entryID == entryID && writer.holdsLastWrite
    }

    /// stops reporting pastes; the last published entry stays on the pasteboard
    public func stop() {
        published = nil
    }

    /// reports each published entry at most once, until the calling task is cancelled; call it once
    public func run() async throws {
        if case let .pasteKey(monitor) = mechanism {
            monitor.start { [weak self] in
                guard let self, let token = published?.token else { return }
                signalContinuation.yield(token)
            }
        }
        defer {
            if case let .pasteKey(monitor) = mechanism {
                monitor.stop()
            }
        }
        for await token in signals {
            guard published?.token == token else { continue }
            try await Task.sleep(for: settleDelay)
            guard let published, published.token == token else { continue }
            self.published = nil
            pastedContinuation.yield(published.entryID)
        }
        try Task.checkCancellation()
    }
}
