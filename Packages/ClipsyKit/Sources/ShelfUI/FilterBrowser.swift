import DesignSystem
import Store
import SwiftUI

struct FilterBrowser: View {
    let model: ShelfModel

    @State private var selection: FilterBrowserItem?
    @State private var isEditingCustomRange = false
    @State private var customFrom = Date.now
    @State private var customThrough = Date.now
    @FocusState private var isListFocused: Bool

    var body: some View {
        List(selection: $selection) {
            Section(SearchToken.Category.kind.name) {
                ForEach(SearchToken.kinds, id: \.self) { kind in
                    FilterBrowserRow(token: .kind(kind), model: model)
                }
            }
            if !model.apps.isEmpty {
                Section(SearchToken.Category.app.name) {
                    ForEach(model.apps, id: \.bundleID) { app in
                        FilterBrowserRow(token: .app(app), model: model)
                    }
                }
            }
            Section(SearchToken.Category.date.name) {
                ForEach(SearchToken.dateRanges, id: \.self) { range in
                    FilterBrowserRow(token: .date(range), model: model)
                }
                Button {
                    isEditingCustomRange.toggle()
                } label: {
                    Label(
                        String(localized: "Custom Range…", comment: "Filter browser row that shows the date pickers"),
                        systemImage: SearchToken.Category.date.symbolName
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .tag(FilterBrowserItem.customRange)
                if isEditingCustomRange {
                    DatePicker(
                        String(localized: "From", comment: "Start day of a custom date filter"),
                        selection: $customFrom,
                        displayedComponents: .date
                    )
                    DatePicker(
                        String(localized: "Through", comment: "Last day of a custom date filter"),
                        selection: $customThrough,
                        displayedComponents: .date
                    )
                    Button(String(
                        localized: "Apply Range",
                        comment: "Filter browser button that adds the custom date filter"
                    )) {
                        model.addToken(.date(.custom(from: customFrom, through: customThrough)))
                        isEditingCustomRange = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            if !model.boards.isEmpty {
                Section(SearchToken.Category.board.name) {
                    ForEach(model.boards) { board in
                        FilterBrowserRow(token: .board(id: board.id), model: model)
                    }
                }
            }
        }
        .focused($isListFocused)
        .contextMenu(forSelectionType: FilterBrowserItem.self) { _ in
        } primaryAction: { items in
            switch items.first {
            case let .token(token): model.toggleToken(token)
            case .customRange: isEditingCustomRange.toggle()
            case nil: break
            }
        }
        .frame(width: DesignTokens.filterBrowserWidth, height: DesignTokens.filterBrowserHeight)
        .onAppear {
            isListFocused = true
        }
    }
}

private struct FilterBrowserRow: View {
    let token: SearchToken
    let model: ShelfModel

    var body: some View {
        let isActive = model.tokens.contains(token)
        Button {
            model.toggleToken(token)
        } label: {
            HStack {
                SearchTokenLabel(token: token, title: model.title(of: token), boards: model.boards)
                Spacer()
                if isActive {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .tag(FilterBrowserItem.token(token))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

private enum FilterBrowserItem: Hashable {
    case token(SearchToken)
    case customRange
}
