import SwiftUI

struct ShelfEmptyView: View {
    let state: ShelfEmptyState
    let commands: ShelfCommands

    var body: some View {
        switch state {
        case .history:
            ContentUnavailableView(
                "No Clipboard History",
                systemImage: "clipboard",
                description: Text("Copy something and it shows up here.")
            )
        case .board:
            ContentUnavailableView(
                "This Board Is Empty",
                systemImage: "square.stack",
                description: Text("Drag Cards here or use “Add to Board”.")
            )
        case .noResults:
            ContentUnavailableView(
                "No Results",
                systemImage: "magnifyingglass",
                description: Text("Try a different search or remove a filter.")
            )
        case .paused:
            ContentUnavailableView {
                Label("Capture Paused", systemImage: "pause.circle")
            } actions: {
                Button("Resume Capture") {
                    commands.setCapturePaused?(false)
                }
            }
        }
    }
}
