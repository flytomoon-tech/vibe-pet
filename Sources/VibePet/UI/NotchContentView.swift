import SwiftUI

// MARK: - Notch extension shape

struct NotchExtensionShape: Shape {
    let bottomRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let br = bottomRadius
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - br, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: br, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - br),
            control: CGPoint(x: 0, y: rect.maxY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Root view

struct NotchRootView: View {
    let viewModel: NotchViewModel

    var body: some View {
        NotchContentView(viewModel: viewModel)
    }
}

// MARK: - Content

struct NotchContentView: View {
    let viewModel: NotchViewModel
    @State private var promptText = ""
    @State private var replyToSession: Session?

    private var sessionStore: SessionStore { viewModel.sessionStore }
    private var isExpanded: Bool { viewModel.isExpanded }

    var body: some View {
        VStack(spacing: 0) {
            capsuleBar

            if isExpanded {
                expandedContent
                    .transition(.opacity)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.black)
        .clipShape(NotchExtensionShape(bottomRadius: isExpanded ? 18 : 10))
    }

    // MARK: - Collapsed bar

    private var capsuleBar: some View {
        HStack(spacing: 6) {
            PetView(state: derivePetState())
                .frame(width: 16, height: 16)

            Spacer()

            if !sessionStore.activeSessions.isEmpty {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                Text("\(sessionStore.activeSessions.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
            } else {
                Circle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 33)
    }

    // MARK: - Expanded content

    private var expandedContent: some View {
        VStack(spacing: 0) {
            // Header with pet, title, settings & quit
            expandedHeader

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)

            // Prompt input
            PromptInputView(
                promptText: $promptText,
                workingDirectory: replyToSession?.cwd ?? mostRecentWorkingDirectory,
                onSend: {
                    replyToSession = nil
                }
            )
            .overlay(alignment: .topLeading) {
                if let session = replyToSession {
                    HStack(spacing: 4) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.blue)
                        Text("Reply to \(session.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? session.id.prefix(8).description)")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.blue)
                        Button(action: { replyToSession = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
                }
            }

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 0.5)

            sessionList
        }
    }

    private var expandedHeader: some View {
        HStack(spacing: 8) {
            PetView(state: derivePetState())
                .frame(width: 24, height: 24)

            Text("VibePet")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Spacer()

            // Settings button — opens separate window
            Button(action: {
                SettingsWindowController.show()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            // Quit button
            Button(action: viewModel.onQuit) {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sessionList: some View {
        Group {
            if sessionStore.allSessions.isEmpty {
                Text("No active sessions")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.35))
                    .padding(.vertical, 16)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(sessionStore.allSessions) { session in
                            SessionRowView(
                                session: session,
                                onArchive: {
                                    sessionStore.archiveSession(session)
                                },
                                onReply: {
                                    replyToSession = session
                                }
                            )
                            .onTapGesture { viewModel.onSessionClick(session) }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
    }

    // MARK: - Helpers

    private var statusColor: Color {
        if sessionStore.sessions.values.contains(where: { $0.status == .needsApproval }) {
            return .red
        } else if sessionStore.hasActiveSession {
            return .green
        } else {
            return .yellow
        }
    }

    private func derivePetState() -> PetState {
        if sessionStore.sessions.values.contains(where: { $0.status == .needsApproval }) {
            return .needsAttention
        } else if sessionStore.hasActiveSession {
            return .active
        } else if sessionStore.activeSessions.isEmpty {
            return .sleeping
        } else {
            return .idle
        }
    }

    private var mostRecentWorkingDirectory: String? {
        sessionStore.activeSessions.first?.cwd
    }
}
