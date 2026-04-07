import SwiftUI
import AppKit

// Custom panel that can become key to accept text input
class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

class NotchWindowController: NSWindowController {
    private let sessionStore: SessionStore
    private var isExpanded = false
    private var hostingView: NSHostingView<NotchRootView>?
    private var viewModel: NotchViewModel?

    private var collapsedWidth: CGFloat = 260
    private var collapsedHeight: CGFloat = 33
    private var expandedWidth: CGFloat = 340
    private let sidePadding: CGFloat = 40

    init(sessionStore: SessionStore) {
        self.sessionStore = sessionStore

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame
        let safe = screen.safeAreaInsets

        let leftArea = screen.auxiliaryTopLeftArea ?? .zero
        let rightArea = screen.auxiliaryTopRightArea ?? .zero
        let notchWidth = screenFrame.width - leftArea.width - rightArea.width
        let menuBarHeight = safe.top > 0 ? safe.top : 24

        let hasNotch = safe.top > 0 && notchWidth > 0
        let cw = hasNotch ? (notchWidth + sidePadding * 2) : 220
        let ch = hasNotch ? (menuBarHeight + 1) : 25
        let ew = max(cw + 80, 340)

        let x = screenFrame.midX - cw / 2
        let y = screenFrame.maxY - ch

        let panel = KeyablePanel(
            contentRect: NSRect(x: x, y: y, width: cw, height: ch),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )

        panel.level = NSWindow.Level(Int(CGShieldingWindowLevel()))
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false

        // Allow text input
        panel.acceptsMouseMovedEvents = true

        super.init(window: panel)

        self.collapsedWidth = cw
        self.collapsedHeight = ch
        self.expandedWidth = ew

        setupContent()

        let trackingArea = NSTrackingArea(
            rect: panel.contentView!.bounds,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        panel.contentView?.addTrackingArea(trackingArea)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setupContent() {
        guard let panel = window else { return }
        let vm = NotchViewModel(
            sessionStore: sessionStore,
            notchWidth: collapsedWidth,
            notchHeight: collapsedHeight,
            onSessionClick: { [weak self] session in self?.jumpToSession(session) },
            onQuit: { NSApplication.shared.terminate(nil) }
        )
        self.viewModel = vm

        let hosting = NSHostingView(rootView: NotchRootView(viewModel: vm))
        hosting.frame = panel.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        panel.contentView?.addSubview(hosting)
        self.hostingView = hosting
    }

    func toggleExpanded() {
        isExpanded.toggle()
        guard let panel = window as? NSPanel, let viewModel else { return }

        // Close settings when collapsing
        if !isExpanded { viewModel.showSettings = false }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame

        let sessionCount = sessionStore.allSessions.count
        let expandedContentHeight: CGFloat
        if sessionCount == 0 {
            expandedContentHeight = 80
        } else {
            // Estimate: header(44) + rows + padding
            let perRow: CGFloat = 70
            expandedContentHeight = min(44 + CGFloat(sessionCount) * perRow + 12, 420)
        }
        let w = isExpanded ? expandedWidth : collapsedWidth
        let height = isExpanded ? (collapsedHeight + expandedContentHeight) : collapsedHeight

        let x = screenFrame.midX - w / 2
        let y = screenFrame.maxY - height

        panel.setFrame(NSRect(x: x, y: y, width: w, height: height), display: true)

        withAnimation(.easeOut(duration: 0.15)) {
            viewModel.isExpanded = isExpanded
        }
    }

    /// Resize panel when switching to/from settings
    func updatePanelSize() {
        guard let panel = window as? NSPanel, let viewModel, isExpanded else { return }

        let screen = NSScreen.main ?? NSScreen.screens[0]
        let screenFrame = screen.frame

        let contentHeight: CGFloat = viewModel.showSettings ? 320 : min(CGFloat(max(sessionStore.allSessions.count, 1) * 52 + 60), 400)
        let height = collapsedHeight + contentHeight
        let w = expandedWidth

        let x = screenFrame.midX - w / 2
        let y = screenFrame.maxY - height

        panel.setFrame(NSRect(x: x, y: y, width: w, height: height), display: true)
    }

    override func mouseEntered(with event: NSEvent) {
        if !isExpanded { toggleExpanded() }
    }

    override func mouseExited(with event: NSEvent) {
        if isExpanded { toggleExpanded() }
    }

    private func jumpToSession(_ session: Session) {
        TerminalJump.jump(to: session)
    }
}

@Observable
class NotchViewModel {
    let sessionStore: SessionStore
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let onSessionClick: (Session) -> Void
    let onQuit: () -> Void
    var isExpanded: Bool = false
    var showSettings: Bool = false

    init(sessionStore: SessionStore, notchWidth: CGFloat, notchHeight: CGFloat, onSessionClick: @escaping (Session) -> Void, onQuit: @escaping () -> Void) {
        self.sessionStore = sessionStore
        self.notchWidth = notchWidth
        self.notchHeight = notchHeight
        self.onSessionClick = onSessionClick
        self.onQuit = onQuit
    }
}
