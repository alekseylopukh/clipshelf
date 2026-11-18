import DesignSystem
import SwiftUI
import Testing

/// renders every DesignSystem component offscreen to .build/snapshots; run with scripts/snapshots.sh
@MainActor
@Suite(.enabled(if: snapshotDirectory != nil), .serialized)
struct ComponentGallerySnapshotTests {
    @Test(arguments: SnapshotRenderer.Appearance.allCases)
    func `render the component gallery`(appearance: SnapshotRenderer.Appearance) async throws {
        try await SnapshotRenderer.render(
            ComponentGallery().background(.windowBackground),
            named: "components",
            appearance: appearance
        )
    }
}

private struct ComponentGallery: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.shelfPadding) {
            GalleryRow("Glass controls (glass itself does not render offscreen)") {
                GlassEffectContainer(spacing: DesignTokens.spacingMedium) {
                    HStack(spacing: DesignTokens.spacingMedium) {
                        Button("New Board", systemImage: "plus") {}
                            .buttonStyle(.glassIcon)
                        Button("Disabled", systemImage: "plus") {}
                            .buttonStyle(.glassIcon)
                            .disabled(true)
                        Button("More", systemImage: "ellipsis") {}
                            .buttonStyle(.glassIcon)
                            .popUpMenuAnchor(PopUpMenuAnchor())
                    }
                }
                .padding(DesignTokens.spacingMedium)
                .background(SnapshotWallpaper())
                .clipShape(.rect(cornerRadius: DesignTokens.cardInnerCornerRadius))
            }
            GalleryRow("Search field, removable chip, accessory icon") {
                HStack(spacing: DesignTokens.spacingMedium) {
                    GlassSearchField {
                        TextField("Search", text: .constant(""))
                            .textFieldStyle(.plain)
                            .frame(minWidth: DesignTokens.searchTextMinimumWidth)
                    }
                    GlassSearchField {
                        Button {} label: {
                            Label("Images", systemImage: "photo")
                                .fixedSize()
                        }
                        .buttonStyle(.removableChip)
                        TextField("Search", text: .constant("invoice"))
                            .textFieldStyle(.plain)
                            .frame(minWidth: DesignTokens.searchTextMinimumWidth)
                        Button("Clear Search", systemImage: "xmark.circle.fill") {}
                            .buttonStyle(.accessoryIcon)
                    }
                }
            }
            GalleryRow("Borderless icon buttons and menu") {
                HStack(spacing: DesignTokens.spacingMedium) {
                    Button("Undo", systemImage: "arrow.uturn.backward") {}
                        .buttonStyle(.borderlessIcon)
                    Menu("More", systemImage: "ellipsis") {
                        Button("Item") {}
                    }
                    .menuStyle(.borderlessIcon)
                    Button("Close", systemImage: "xmark") {}
                        .buttonStyle(.borderlessIcon)
                    Button("Add", systemImage: "plus") {}
                        .buttonStyle(.borderlessIcon)
                        .disabled(true)
                }
            }
            GalleryRow("Card surface: rest, selected") {
                HStack(spacing: DesignTokens.cardSpacing * 2) {
                    GalleryCard(isSelected: false)
                    GalleryCard(isSelected: true)
                }
                .padding(DesignTokens.spacingMedium)
            }
            GalleryRow("Tab track: selected, board tabs, drop target, long name") {
                GalleryTabTrack()
                    .fixedSize()
                    .padding(DesignTokens.spacingMedium)
            }
            GalleryRow("Media caption and swatch value labels") {
                HStack(spacing: DesignTokens.spacingLarge) {
                    LinearGradient(colors: [.orange, .purple], startPoint: .leading, endPoint: .trailing)
                        .frame(width: 160, height: 100)
                        .overlay(alignment: .bottomLeading) {
                            MediaCaption(Text(verbatim: "1600 × 1000"))
                                .padding(DesignTokens.mediaCaptionInset)
                        }
                        .clipShape(.rect(cornerRadius: DesignTokens.cardInnerCornerRadius))
                    ForEach(["#FAB700", "#0088FF", "#1C1C1E"], id: \.self) { value in
                        GallerySwatch(value: value)
                    }
                }
            }
            GalleryRow("Badges and board dots") {
                HStack(spacing: DesignTokens.spacingLarge) {
                    GlassBadge(count: 3)
                    GlassBadge(count: 12)
                    ForEach(BoardColor.allCases, id: \.self) { color in
                        BoardDot(color)
                    }
                    HStack(spacing: DesignTokens.spacingSmall) {
                        ForEach(BoardColor.allCases, id: \.self) { color in
                            BoardDot(color, isOutlined: true)
                        }
                    }
                    .padding(DesignTokens.spacingSmall)
                    .background(.indigo, in: .capsule)
                    HStack(spacing: DesignTokens.spacingSmall) {
                        ForEach(BoardColor.allCases, id: \.self) { color in
                            Image(nsImage: color.menuSwatch)
                        }
                    }
                }
            }
            GalleryRow("Empty state, placeholder symbol, metadata") {
                HStack(alignment: .top, spacing: DesignTokens.shelfPadding) {
                    EmptyStateView(
                        Text(verbatim: "No Results"),
                        systemImage: "magnifyingglass",
                        description: Text(verbatim: "Try a different search.")
                    )
                    .frame(width: 220, height: 160)
                    EmptyStateView(Text(verbatim: "Capture Paused"), systemImage: "pause.circle") {
                        Button("Resume Capture") {}
                    }
                    .frame(width: 220, height: 160)
                    VStack(spacing: DesignTokens.spacingMedium) {
                        PlaceholderSymbol("link")
                        Text(verbatim: "1,234 characters · 1600 × 1000")
                            .metadataStyle()
                    }
                }
            }
            GalleryRow("Form rows, footnote, sheet header and button bar") {
                VStack(spacing: 0) {
                    Form {
                        Section {
                            Toggle(isOn: .constant(true)) {
                                LabelWithNote(
                                    Text(verbatim: "Recognize text in images"),
                                    note: Text(verbatim: "Text is recognized on this Mac.")
                                )
                            }
                            LabeledContent {
                                Button("Open System Settings…") {}
                            } label: {
                                LabelWithNote(
                                    Text(verbatim: "Accessibility"),
                                    note: Text(verbatim: "Not allowed.")
                                )
                            }
                        } header: {
                            SheetHeader(Text(verbatim: "Edit Board"))
                        } footer: {
                            FormFootnote(Text(verbatim: "A section footnote in secondary color."))
                        }
                    }
                    .formStyle(.grouped)
                    .scrollDisabled(true)
                    .fixedSize(horizontal: false, vertical: true)
                    SheetButtonBar(errorMessage: "The value is not a color.") {
                        Button("Cancel", role: .cancel) {}
                        Button("Save") {}
                            .keyboardShortcut(.defaultAction)
                    }
                    .padding([.horizontal, .bottom], DesignTokens.sheetPadding)
                }
                .frame(width: DesignTokens.cardFormSheetWidth)
            }
            GalleryRow("Glass panel background (stand-in outline only)") {
                GlassPanelBackground(cornerRadius: DesignTokens.sequencePanelCornerRadius)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.sequencePanelCornerRadius)
                            .strokeBorder(.secondary, style: StrokeStyle(lineWidth: 1, dash: [4]))
                    }
                    .frame(width: DesignTokens.sequencePanelWidth, height: DesignTokens.sequenceRowHeight)
            }
        }
        .padding(DesignTokens.sheetPadding)
        .frame(width: 900, alignment: .leading)
    }
}

private struct GalleryRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSmall) {
            Text(verbatim: title)
                .font(.headline)
            content
        }
    }
}

private struct GalleryTabTrack: View {
    private enum Tab: Hashable {
        case history
        case board(String)
    }

    var body: some View {
        TabTrack(selection: Tab.history, label: Text(verbatim: "Boards")) { namespace in
            Label("History", systemImage: "clock")
                .tabTrackSegment(id: Tab.history, in: namespace, isSelected: true)
            Label {
                Text(verbatim: "Work")
            } icon: {
                BoardDot(.blue)
            }
            .tabTrackSegment(id: Tab.board("Work"), in: namespace, isSelected: false)
            Label {
                Text(verbatim: "Design")
            } icon: {
                BoardDot(.orange)
            }
            .tabTrackSegment(id: Tab.board("Design"), in: namespace, isSelected: false, isTargeted: true)
            Label {
                Text(verbatim: "Quarterly Planning and Research Notes")
            } icon: {
                BoardDot(.green)
            }
            .tabTrackSegment(id: Tab.board("Notes"), in: namespace, isSelected: false)
        }
    }
}

private struct GallerySwatch: View {
    let value: String

    private var swatch: Color {
        let hex = Int(value.dropFirst(), radix: 16) ?? 0
        return Color(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    var body: some View {
        Rectangle()
            .fill(swatch)
            .overlay(alignment: .bottomLeading) {
                SwatchValueLabel(value, on: swatch)
                    .padding(DesignTokens.swatchValueInset)
            }
            .frame(width: 120, height: 100)
            .clipShape(.rect(cornerRadius: DesignTokens.cardInnerCornerRadius))
    }
}

private struct GalleryCard: View {
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading) {
            Text(verbatim: "Card")
                .font(.headline)
            Spacer()
            Text(verbatim: "42 characters")
                .metadataStyle()
        }
        .padding(DesignTokens.cardContentInset)
        .frame(width: 120, height: 120, alignment: .leading)
        .cardSurface(isSelected: isSelected)
    }
}
