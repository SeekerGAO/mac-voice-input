import AppKit
import SwiftUI

private final class TransparentHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }
}

@MainActor
final class FloatingPanelController {
    private let viewModel = FloatingPanelViewModel()
    private lazy var hostingView = TransparentHostingView(rootView: FloatingPanelView(viewModel: viewModel))
    private var panel: NSPanel?
    private var isVisible = false

    func setLanguage(_ language: LanguageOption) {
        viewModel.language = language
        updateSize(animated: false)
    }

    func showListening() {
        ensurePanel()
        viewModel.status = .listening
        viewModel.transcript = ""
        updateSize(animated: false)
        presentIfNeeded()
    }

    func updateTranscript(_ transcript: String) {
        guard panel != nil else { return }
        guard viewModel.transcript != transcript || !matches(status: .listening) else { return }
        viewModel.status = .listening
        viewModel.transcript = transcript
        updateSize(animated: true)
    }

    func showRefining(with transcript: String) {
        ensurePanel()
        guard viewModel.transcript != transcript || !matches(status: .refining) else {
            presentIfNeeded()
            return
        }
        viewModel.transcript = transcript
        viewModel.status = .refining
        updateSize(animated: true)
        presentIfNeeded()
    }

    func showMessage(_ message: String) {
        ensurePanel()
        if case .message(let currentMessage) = viewModel.status, currentMessage == message {
            presentIfNeeded()
            return
        }
        viewModel.status = .message(message)
        updateSize(animated: true)
        presentIfNeeded()
    }

    func updateMeter(levels: [CGFloat]) {
        guard levels.count == 5 else { return }
        viewModel.barLevels = levels
    }

    func hide() {
        guard let panel, isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().alphaValue = 0
            panel.contentView?.animator().layer?.setAffineTransform(CGAffineTransform(scaleX: 0.92, y: 0.92))
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.contentView?.layer?.setAffineTransform(.identity)
            }
        }
    }

    private func ensurePanel() {
        guard panel == nil else { return }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 74),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .statusBar
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false

        let containerView = NSView(frame: panel.contentRect(forFrameRect: panel.frame))
        containerView.wantsLayer = true
        containerView.layer?.cornerRadius = 37
        containerView.layer?.masksToBounds = false
        containerView.layer?.backgroundColor = NSColor.clear.cgColor

        hostingView.frame = containerView.bounds
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView.layer?.isOpaque = false
        containerView.addSubview(hostingView)
        panel.contentView = containerView
        panel.alphaValue = 0
        self.panel = panel
    }

    private func presentIfNeeded() {
        guard let panel else { return }
        updateSize(animated: false)
        position(panel: panel)
        if isVisible {
            return
        }
        isVisible = true
        panel.contentView?.layer?.setAffineTransform(CGAffineTransform(scaleX: 0.88, y: 0.88))
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.35
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.2, 1.0)
            panel.animator().alphaValue = 1
            panel.contentView?.animator().layer?.setAffineTransform(.identity)
        }
    }

    private func updateSize(animated: Bool) {
        guard let panel else { return }
        let targetWidth = viewModel.panelWidth
        let targetFrame = NSRect(origin: .zero, size: NSSize(width: targetWidth, height: 74))
        hostingView.frame = targetFrame
        var frame = panel.frame
        frame.size = targetFrame.size
        position(panel: panel, proposedFrame: frame, animated: animated)
    }

    private func matches(status: FloatingPanelViewModel.Status) -> Bool {
        switch (viewModel.status, status) {
        case (.listening, .listening), (.refining, .refining):
            return true
        case (.message(let lhs), .message(let rhs)):
            return lhs == rhs
        default:
            return false
        }
    }

    private func position(panel: NSPanel, proposedFrame: NSRect? = nil, animated: Bool = false) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        var frame = proposedFrame ?? panel.frame
        frame.origin.x = screen.visibleFrame.midX - (frame.width / 2)
        frame.origin.y = screen.visibleFrame.minY + 48
        panel.setFrame(frame, display: true, animate: animated)
    }
}
