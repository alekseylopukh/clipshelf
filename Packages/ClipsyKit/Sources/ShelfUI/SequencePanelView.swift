import DesignSystem
import Pasting
import Store
import SwiftUI

struct SequencePanelView: View {
    let model: SequencePanelModel

    @State private var selection: Set<PasteSequence.Entry.ID> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 0) {
                SequencePanelHeader(model: model)
                if model.sequence.entries.isEmpty {
                    Text("Copy something, or drag cards here from the shelf.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: DesignTokens.sequenceRowHeight * 2)
                        .padding(.horizontal, DesignTokens.spacingLarge)
                } else {
                    List(selection: $selection) {
                        ForEach(model.rows) { row in
                            SequenceRow(row: row) {
                                model.remove([row.id])
                            }
                            .listRowInsets(DesignTokens.sequenceRowInsets)
                        }
                        .onMove { model.sequence.move(fromOffsets: $0, toOffset: $1) }
                    }
                    .listStyle(.plain)
                    .frame(height: DesignTokens.sequenceRowHeight * CGFloat(min(
                        model.sequence.entries.count,
                        DesignTokens.sequenceMaximumVisibleRows
                    )))
                    .clipShape(.rect(cornerRadius: DesignTokens.sequenceListCornerRadius))
                    .padding([.horizontal, .bottom], DesignTokens.spacingMedium)
                    .onDeleteCommand {
                        model.remove(selection)
                    }
                    .animation(reduceMotion ? nil : DesignTokens.Motion.standard, value: model.sequence.entries)
                }
            }
            .frame(width: DesignTokens.sequencePanelWidth)
            .background {
                GlassPanelBackground(cornerRadius: DesignTokens.sequencePanelCornerRadius)
            }
        }
        .dropDestination(for: CardReference.self) { references, _ in
            model.sequence.add(references.cardIDs)
            return true
        }
        .task(id: model.cardIDs) {
            await model.refreshCards()
        }
    }
}

private struct SequencePanelHeader: View {
    let model: SequencePanelModel

    var body: some View {
        @Bindable var sequence = model.sequence
        HStack(spacing: DesignTokens.spacingSmall) {
            Label("Sequence", systemImage: "list.number")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Undo", systemImage: "arrow.uturn.backward") {
                sequence.undo()
            }
            .buttonStyle(.borderlessIcon)
            .keyboardShortcut("z", modifiers: .command)
            .disabled(sequence.canUndo == false)
            Menu("More", systemImage: "ellipsis") {
                Toggle("Reverse Order", isOn: $sequence.isReverseOrder)
                Button("Paste All") {
                    model.pasteAll()
                }
                .disabled(sequence.entries.isEmpty)
                Toggle("Paste as Plain Text", isOn: $sequence.isPlainText)
                Divider()
                Button("Clear") {
                    sequence.clear()
                }
                .disabled(sequence.entries.isEmpty)
            }
            .menuStyle(.borderlessIcon)
            Button("Close", systemImage: "xmark") {
                sequence.close()
            }
            .buttonStyle(.borderlessIcon)
        }
        .padding(.horizontal, DesignTokens.spacingLarge)
        .padding(.vertical, DesignTokens.spacingMedium)
        .contentShape(.rect)
        .gesture(WindowDragGesture())
    }
}

private struct SequenceRow: View {
    let row: SequencePanelModel.Row
    let onRemove: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.spacingMedium) {
            Circle()
                .fill(.tint)
                .frame(width: DesignTokens.sequenceNextMarkerSize, height: DesignTokens.sequenceNextMarkerSize)
                .opacity(row.isNext ? 1 : 0)
                .accessibilityHidden(true)
            Text(row.card.map(\.displayText) ?? "")
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if isHovered {
                Button("Remove", systemImage: "xmark.circle.fill", action: onRemove)
                    .buttonStyle(.accessoryIcon)
            } else {
                Image(systemName: row.card?.kind.symbolName ?? CardKind.unknown.symbolName)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: DesignTokens.sequenceRowHeight)
        .onHover { isHovered = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityValue(row.isNext ? Text("Next") : Text(verbatim: ""))
        .accessibilityAction(named: "Remove", onRemove)
    }
}

private extension CardSummary {
    var displayText: String {
        if let title, title.isEmpty == false {
            return title
        }
        if let preview, preview.isEmpty == false {
            return preview
        }
        return kind.name
    }
}

#Preview {
    let sequence = PasteSequence(defaults: UserDefaults(suiteName: "SequencePanelPreview") ?? .standard)
    sequence.add([1, 2, 3])
    let model = SequencePanelModel(sequence: sequence, loadCards: { ids in
        ids.map { CardSummary(id: $0, kind: .text, preview: "Line \($0)", createdAt: .now) }
    }, onPasteAll: { _ in })
    return SequencePanelView(model: model)
        .padding()
}
