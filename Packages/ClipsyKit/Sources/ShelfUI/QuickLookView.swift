import QuickLookUI
import SwiftUI

struct QuickLookView: NSViewRepresentable {
    let url: URL

    func makeNSView(context _: Context) -> QLPreviewView {
        guard let view = QLPreviewView(frame: .zero, style: .normal) else {
            fatalError("QLPreviewView always initializes with the normal style")
        }
        // the popover window closes and reopens around the same view, so it is closed in dismantleNSView instead
        view.shouldCloseWithWindow = false
        view.previewItem = url as NSURL
        return view
    }

    func updateNSView(_ view: QLPreviewView, context _: Context) {
        if (view.previewItem as? NSURL) as URL? != url {
            view.previewItem = url as NSURL
        }
    }

    static func dismantleNSView(_ view: QLPreviewView, coordinator _: Void) {
        view.close()
    }
}
