import Foundation
import Store
import Testing
@testable import Pasting

@MainActor
final class PasteSequenceTests {
    private let suiteName = "PasteSequenceTests-\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: suiteName)
    }

    private func pasteHead(of sequence: PasteSequence) throws -> Int64 {
        let head = try #require(sequence.head)
        sequence.didPaste(head.id)
        return head.cardID
    }

    @Test func `copy order pastes first copied first`() throws {
        let sequence = PasteSequence(defaults: defaults)
        for cardID: Int64 in [1, 2, 3] {
            sequence.add([cardID])
        }

        #expect(try (0 ..< 3).map { _ in try pasteHead(of: sequence) } == [1, 2, 3])
    }

    @Test func `reverse order inserts at head`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1])
        sequence.isReverseOrder = true
        sequence.add([2])
        sequence.add([3, 4])

        #expect(sequence.entries.map(\.cardID) == [3, 4, 2, 1])
    }

    @Test func `seed keeps shelf order and opens`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([30, 10, 20])

        #expect(sequence.isOpen)
        #expect(sequence.entries.map(\.cardID) == [30, 10, 20])
    }

    @Test func `same card can be queued twice`() throws {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2, 1])

        #expect(try (0 ..< 3).map { _ in try pasteHead(of: sequence) } == [1, 2, 1])
    }

    @Test func `undo restores position`() throws {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2, 3, 4])

        sequence.remove(sequence.entries[2].id)
        _ = try pasteHead(of: sequence)
        #expect(sequence.entries.map(\.cardID) == [2, 4])

        sequence.undo()
        #expect(sequence.entries.map(\.cardID) == [1, 2, 4])
        sequence.undo()
        #expect(sequence.entries.map(\.cardID) == [1, 2, 3, 4])
        #expect(sequence.canUndo == false)
    }

    @Test func `undo after the list shrank appends at the end`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2, 3])
        let last = sequence.entries[2].id
        sequence.remove(sequence.entries[0].id)
        sequence.remove(sequence.entries[0].id)
        sequence.remove(last)

        sequence.undo()
        #expect(sequence.entries.map(\.cardID) == [3])
    }

    @Test func `last paste closes`() throws {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2])

        _ = try pasteHead(of: sequence)
        #expect(sequence.isOpen)
        _ = try pasteHead(of: sequence)
        #expect(sequence.isOpen == false)
        #expect(sequence.canUndo == false)
    }

    @Test func `removing the last card keeps the panel open`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1])
        sequence.remove(sequence.entries[0].id)

        #expect(sequence.isOpen)
        #expect(sequence.entries.isEmpty)
        #expect(sequence.canUndo)
    }

    @Test func `paste out of order removes that card`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2, 3])
        sequence.didPaste(sequence.entries[1].id)

        #expect(sequence.entries.map(\.cardID) == [1, 3])
    }

    @Test func `stale paste does nothing`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1])
        let entry = sequence.entries[0].id
        sequence.didPaste(entry)
        sequence.add([2])
        sequence.didPaste(entry)

        #expect(sequence.entries.map(\.cardID) == [2])
    }

    @Test(arguments: [
        (IndexSet(integer: 0), 3, [2, 3, 1, 4]),
        (IndexSet(integer: 3), 0, [4, 1, 2, 3]),
        (IndexSet([0, 2]), 4, [2, 4, 1, 3]),
        (IndexSet(integer: 1), 1, [1, 2, 3, 4])
    ])
    func `reorder moves entries`(offsets: IndexSet, destination: Int, expected: [Int64]) {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2, 3, 4])
        sequence.move(fromOffsets: offsets, toOffset: destination)

        #expect(sequence.entries.map(\.cardID) == expected)
    }

    @Test func `paste all returns queue order and closes`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2, 3])

        #expect(sequence.pasteAll() == [1, 2, 3])
        #expect(sequence.isOpen == false)
        #expect(sequence.entries.isEmpty)
    }

    @Test func `paste all joins text`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2, 3])
        let texts: [Int64: (CardKind, String)] = [
            1: (.text, "one"),
            2: (.link, "https://example.com"),
            3: (.color, "#1A2B3C")
        ]
        let cards = sequence.pasteAll().compactMap { texts[$0] }.map { kind, text in
            (kind: kind, representations: [
                Representation(itemIndex: 0, uti: "public.rtf", data: Data([0])),
                Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data(text.utf8))
            ])
        }

        #expect(CombinedPayload.representations(of: cards) == [
            Representation(
                itemIndex: 0,
                uti: "public.utf8-plain-text",
                data: Data("one\nhttps://example.com\n#1A2B3C".utf8)
            )
        ])
    }

    @Test func `paste all with an image writes one item per card`() {
        let text = Representation(itemIndex: 0, uti: "public.utf8-plain-text", data: Data([1]))
        let image = Representation(itemIndex: 0, uti: "public.png", data: Data([2]))
        let files = [
            Representation(itemIndex: 0, uti: "public.file-url", data: Data([3])),
            Representation(itemIndex: 1, uti: "public.file-url", data: Data([4]))
        ]

        let payload = CombinedPayload.representations(of: [
            (kind: .text, representations: [text]),
            (kind: .image, representations: [image]),
            (kind: .file, representations: files)
        ])

        #expect(payload.map(\.itemIndex) == [0, 1, 2, 3])
        #expect(payload.map(\.data) == [Data([1]), Data([2]), Data([3]), Data([4])])
    }

    @Test func `close clears entries and undo`() {
        let sequence = PasteSequence(defaults: defaults)
        sequence.add([1, 2])
        sequence.remove(sequence.entries[0].id)
        sequence.close()

        #expect(sequence.isOpen == false)
        #expect(sequence.entries.isEmpty)
        #expect(sequence.canUndo == false)
    }

    @Test func `plain text flag persists across sequences`() {
        let sequence = PasteSequence(defaults: defaults)
        #expect(sequence.isPlainText == false)
        sequence.isPlainText = true
        sequence.close()

        #expect(sequence.isPlainText)
        #expect(PasteSequence(defaults: defaults).isPlainText)
    }
}
