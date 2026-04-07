import SwiftUI

struct SessionRowView: View {
    let session: Session
    var onArchive: (() -> Void)?
    var onReply: (() -> Void)?
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row: source badge, status, cwd, time, archive
            HStack(spacing: 6) {
                Text(sourceBadge)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 18)
                    .background(sourceColor)
                    .clipShape(RoundedRectangle(cornerRadius: 3))

                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)

                Text(cwdLabel)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Text(timeAgo)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)

                if let onReply {
                    Button(action: onReply) {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }

                if let onArchive, session.status != .archived {
                    Button(action: onArchive) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Status line
            Text(statusLabel)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.gray)
                .lineLimit(1)

            // User prompt
            if let prompt = session.lastPrompt, !prompt.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.cyan.opacity(0.6))
                    Text(prompt)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }
            }

            // Assistant response
            if let response = session.lastAssistantMessage, !response.isEmpty {
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 8))
                        .foregroundColor(.orange.opacity(0.6))
                    Text(response)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(2)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.05))
        )
        .contentShape(Rectangle())
        .onReceive(timer) { now = $0 }
    }

    private var sourceBadge: String {
        switch session.source {
        case .claude: return "CC"
        case .codex: return "CX"
        case .coco: return "CO"
        case .unknown: return "?"
        }
    }

    private var sourceColor: Color {
        switch session.source {
        case .claude: return .orange
        case .codex: return .green
        case .coco: return .blue
        case .unknown: return .gray
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .starting: return .blue
        case .active: return .green
        case .waitingForInput: return .yellow
        case .needsApproval: return .red
        case .ended: return .gray
        case .archived: return .gray.opacity(0.5)
        }
    }

    private var cwdLabel: String {
        if let cwd = session.cwd {
            return URL(fileURLWithPath: cwd).lastPathComponent
        }
        return session.id.prefix(8).description
    }

    private var statusLabel: String {
        switch session.status {
        case .starting: return "starting..."
        case .active:
            if let tool = session.lastToolName {
                return "using \(tool)"
            }
            return "working..."
        case .waitingForInput: return "waiting for input"
        case .needsApproval: return "needs approval!"
        case .ended: return "ended"
        case .archived: return "archived"
        }
    }

    private var timeAgo: String {
        let interval = now.timeIntervalSince(session.lastEventAt)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        return "\(Int(interval / 3600))h"
    }
}
