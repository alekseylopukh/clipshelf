import SwiftUI

struct OpenWithMenu: View {
    let cardID: Int64
    let applications: [OpenWithApplication]

    var body: some View {
        if !applications.isEmpty {
            Menu("Open With") {
                OpenWithItems(cardID: cardID, applications: applications)
            }
        }
    }
}
