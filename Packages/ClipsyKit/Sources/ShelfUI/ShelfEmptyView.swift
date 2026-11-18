import DesignSystem
import SwiftUI

struct ShelfEmptyView: View {
    let state: ShelfEmptyState
    let commands: ShelfCommands

    var body: some View {
        switch state {
        case .history:
            EmptyStateView(
                Text("No Clipboard History"),
                systemImage: "clipboard",
                description: Text("Copy something and it shows up here.")
            )
        case .board:
            EmptyStateView(
                Text("This Board Is Empty"),
                systemImage: "square.stack",
                description: Text("Drag Cards here or use “Add to Board”.")
            )
        case .noResults:
            EmptyStateView(
                Text("No Results"),
                systemImage: "magnifyingglass",
                description: Text("Try a different search or remove a filter.")
            )
        case .paused:
            EmptyStateView(Text("Capture Paused"), systemImage: "pause.circle") {
                Button("Resume Capture") {
                    commands.setCapturePaused?(false)
                }
            }
        }
    }
}
