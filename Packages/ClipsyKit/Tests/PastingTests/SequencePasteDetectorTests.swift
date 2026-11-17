import AppKit
import Store
import Testing
@testable import Pasting

@MainActor
private final class FakePasteKeyMonitor: PasteKeyMonitoring {
    private var onPress: (@MainActor () -> Void)?

    var isStarted: Bool {
        onPress != nil
    }

    func start(onPress: @escaping @MainActor () -> Void) {
        self.onPress = onPress
    }

    func stop() {
        onPress = nil
    }

    func press() {
        onPress?()
    }
}

@MainActor
struct SequencePasteDetectorTests {
    private static let rtf = NSPasteboard.PasteboardType.rtf
    private static let plain = NSPasteboard.PasteboardType.string

    private let pasteboard = NSPasteboard.withUniqueName()
    private let representations = [
        Representation(itemIndex: 0, uti: rtf.rawValue, data: Data([1])),
        Representation(itemIndex: 0, uti: plain.rawValue, data: Data([2]))
    ]

    private func detector(_ mechanism: SequencePasteDetector.Mechanism) -> SequencePasteDetector {
        SequencePasteDetector(
            mechanism: mechanism,
            writer: PasteboardWriter(pasteboard: pasteboard),
            settleDelay: .zero
        )
    }

    private func readEveryType() -> [Data?] {
        [pasteboard.data(forType: Self.rtf), pasteboard.data(forType: Self.plain), pasteboard.data(forType: Self.rtf)]
    }

    @Test func `provider read advances once`() async {
        defer { pasteboard.releaseGlobally() }
        let detector = detector(.dataProvider)
        let run = Task { try await detector.run() }
        defer { run.cancel() }
        let head = UUID()
        let next = UUID()
        var pasted = detector.pastedEntryIDs.makeAsyncIterator()

        detector.publish(head, representations: representations, plainTextOnly: false)
        #expect(readEveryType() == [Data([1]), Data([2]), Data([1])])
        #expect(await pasted.next() == head)

        detector.publish(next, representations: representations, plainTextOnly: false)
        _ = readEveryType()
        #expect(await pasted.next() == next)
    }

    @Test func `checking types does not advance`() async {
        defer { pasteboard.releaseGlobally() }
        let detector = detector(.dataProvider)
        let run = Task { try await detector.run() }
        defer { run.cancel() }
        let head = UUID()
        let next = UUID()
        var pasted = detector.pastedEntryIDs.makeAsyncIterator()

        detector.publish(head, representations: representations, plainTextOnly: false)
        #expect(pasteboard.types?.contains(Self.plain) == true)
        #expect(pasteboard.types?.contains(NSPasteboard.PasteboardType(PasteboardMarker.ownWrite)) == true)
        #expect(pasteboard.availableType(from: [Self.rtf]) == Self.rtf)
        #expect(pasteboard.canReadItem(withDataConformingToTypes: [Self.plain.rawValue]))

        detector.publish(next, representations: representations, plainTextOnly: false)
        _ = readEveryType()
        #expect(await pasted.next() == next)
    }

    @Test func `plain text promises only the string`() {
        defer { pasteboard.releaseGlobally() }
        let detector = detector(.dataProvider)

        detector.publish(UUID(), representations: representations, plainTextOnly: true)

        #expect(pasteboard.data(forType: Self.rtf) == nil)
        #expect(pasteboard.data(forType: Self.plain) == Data([2]))
    }

    @Test func `stopped detector serves data without reporting`() async {
        defer { pasteboard.releaseGlobally() }
        let detector = detector(.dataProvider)
        let run = Task { try await detector.run() }
        defer { run.cancel() }
        let next = UUID()
        var pasted = detector.pastedEntryIDs.makeAsyncIterator()

        detector.publish(UUID(), representations: representations, plainTextOnly: false)
        detector.stop()
        #expect(readEveryType() == [Data([1]), Data([2]), Data([1])])

        detector.publish(next, representations: representations, plainTextOnly: false)
        _ = readEveryType()
        #expect(await pasted.next() == next)
    }

    @Test func `paste key advances the published entry`() async {
        defer { pasteboard.releaseGlobally() }
        let monitor = FakePasteKeyMonitor()
        let detector = detector(.pasteKey(monitor))
        let run = Task { try await detector.run() }
        defer { run.cancel() }
        let head = UUID()
        var pasted = detector.pastedEntryIDs.makeAsyncIterator()
        while monitor.isStarted == false {
            await Task.yield()
        }

        detector.publish(head, representations: representations, plainTextOnly: false)
        #expect(pasteboard.data(forType: Self.plain) == Data([2]))
        monitor.press()

        #expect(await pasted.next() == head)
    }

    @Test(arguments: [
        (NSEvent.ModifierFlags.command, true),
        (NSEvent.ModifierFlags([.command, .shift, .option]), true),
        (NSEvent.ModifierFlags([.command, .control]), false),
        (NSEvent.ModifierFlags(), false)
    ])
    func `paste keystroke needs command without control`(flags: NSEvent.ModifierFlags, isPaste: Bool) {
        #expect(PasteKeyMonitor.isPasteKeystroke(keyCode: 9, modifierFlags: flags, commandVKeyCode: 9) == isPaste)
    }

    @Test func `paste keystroke needs the layout's V key`() {
        #expect(PasteKeyMonitor.isPasteKeystroke(keyCode: 47, modifierFlags: .command, commandVKeyCode: 9) == false)
    }
}
