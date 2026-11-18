import AppKit

extension ShelfController {
    func beginClosing() {
        let duration = slide.close(reduceMotion: reduceMotion)
        closeTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(duration))
            } catch {
                return
            }
            // a reopen can cancel this task after the sleep has already returned
            guard !Task.isCancelled else { return }
            self?.closeNow()
        }
    }

    func cancelClosing() {
        closeTask?.cancel()
        closeTask = nil
    }

    func closeNow() {
        cancelClosing()
        presentation.isVisible = false
        panel.orderOut(nil)
        slide.reset()
    }
}
