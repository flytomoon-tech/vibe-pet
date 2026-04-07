import SwiftUI

struct PromptInputView: View {
    @Binding var promptText: String
    let session: Session?
    let onSend: () -> Void
    @State private var isSending = false
    @State private var errorMessage: String?
    @AppStorage("vibepet.defaultCLI") private var defaultCLI = "claude"

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                // Source badge
                sourceBadge

                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundColor(.orange.opacity(0.7))

                TextField("Send to Claude Code...", text: $promptText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .disabled(isSending)
                    .onSubmit {
                        sendPrompt()
                    }

                if isSending {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Button(action: sendPrompt) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 10))
                            .foregroundColor(promptText.isEmpty ? .gray : .blue)
                    }
                    .buttonStyle(.plain)
                    .disabled(promptText.isEmpty)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            if let error = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 9))
                        .foregroundColor(.red.opacity(0.8))
                }
                .padding(.horizontal, 4)
            }

            if let cwd = session?.cwd {
                HStack(spacing: 4) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.gray)
                    Text(URL(fileURLWithPath: cwd).lastPathComponent)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var sourceBadge: some View {
        let source: SessionSource
        if let sessionSource = session?.source {
            source = sessionSource
        } else {
            source = SessionSource(rawValue: defaultCLI) ?? .claude
        }

        let badge: String
        let color: Color

        switch source {
        case .claude:
            badge = "CC"
            color = .orange
        case .codex:
            badge = "CX"
            color = .green
        case .coco:
            badge = "CO"
            color = .blue
        case .unknown:
            badge = "?"
            color = .gray
        }

        return Text(badge)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(.black)
            .frame(width: 22, height: 18)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .id(defaultCLI) // Force refresh when defaultCLI changes
    }

    private func sendPrompt() {
        guard !promptText.isEmpty, !isSending else { return }

        isSending = true
        errorMessage = nil

        if let session = session {
            // Reply to existing session
            let textToSend = promptText
            promptText = ""

            DispatchQueue.global(qos: .userInitiated).async {
                TerminalJump.sendText(to: session, text: textToSend)
                DispatchQueue.main.async {
                    isSending = false
                    onSend()
                }
            }
        } else {
            // Start new session with CLI
            let textToSend = promptText
            promptText = ""
            let source = SessionSource(rawValue: defaultCLI) ?? .claude

            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try ClaudePromptSender.sendPrompt(textToSend, source: source, workingDirectory: nil)
                    DispatchQueue.main.async {
                        isSending = false
                        onSend()
                    }
                } catch ClaudePromptSender.SendError.cliNotFound {
                    DispatchQueue.main.async {
                        errorMessage = "CLI not found"
                        isSending = false
                    }
                } catch ClaudePromptSender.SendError.executionFailed(let msg) {
                    DispatchQueue.main.async {
                        errorMessage = "Failed: \(msg)"
                        isSending = false
                    }
                } catch {
                    DispatchQueue.main.async {
                        errorMessage = "Unknown error"
                        isSending = false
                    }
                }
            }
        }
    }
}
