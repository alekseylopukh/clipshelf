import SwiftUI

struct OpenWithItems: View {
    let cardID: Int64
    let applications: [OpenWithApplication]

    @Environment(CardActions.self) private var actions

    var body: some View {
        ForEach(applications) { application in
            Button {
                actions.openWith(application.url, cardID)
            } label: {
                Label {
                    if application.isDefault {
                        Text(
                            "\(application.name) (default)",
                            comment: "Open With menu item of the app that opens the file by default"
                        )
                    } else {
                        Text(verbatim: application.name)
                    }
                } icon: {
                    Image(nsImage: application.icon)
                }
            }
            if application.isDefault, applications.count > 1 {
                Divider()
            }
        }
    }
}
