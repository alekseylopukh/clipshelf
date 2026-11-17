import AppKit
import DesignSystem
import SwiftUI

struct RichTextView: NSViewRepresentable {
    let editor: TextCardEditor

    func makeCoordinator() -> Coordinator {
        Coordinator(editor: editor)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSTextView.scrollableTextView()
        scrollView.drawsBackground = false
        guard let textView = scrollView.documentView as? NSTextView else {
            fatalError("scrollableTextView() always wraps an NSTextView")
        }
        textView.isRichText = true
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.font = TextCardEditor.font
        textView.textContainerInset = NSSize(width: DesignTokens.spacingSmall, height: DesignTokens.spacingMedium)
        textView.textStorage?.setAttributedString(editor.initialText)
        textView.setAccessibilityLabel(String(
            localized: "Card Text",
            comment: "Accessibility label of the text editor in the edit sheet"
        ))
        textView.delegate = context.coordinator
        editor.attach(textView)
        context.coordinator.focus(textView)
        return scrollView
    }

    func updateNSView(_: NSScrollView, context _: Context) {}

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        private let editor: TextCardEditor

        init(editor: TextCardEditor) {
            self.editor = editor
        }

        func focus(_ textView: NSTextView) {
            // swiftlint:disable:next no_dispatch_queue
            DispatchQueue.main.async { // the text view has no window until the sheet is on screen
                textView.window?.makeFirstResponder(textView)
            }
        }

        func textDidChange(_: Notification) {
            editor.textDidChange()
        }

        func textViewDidChangeSelection(_: Notification) {
            editor.selectionDidChange()
        }
    }
}
