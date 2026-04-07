import SwiftUI

struct PromptInputView: View {
    @Binding var promptText: String
    let session: Session?
    let onSend: () -> Void
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
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

    private func sendPrompt() {
        guard !promptText.isEmpty else { return }

        isSending = true
        errorMessage = nil

        if let session = session {
            // Reply to existing session
            TerminalJump.sendText(to: session, text: promptText)
            promptText = ""
            isSending = false
            onSend()
        } else {
            // Start new session with CLI
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let source = session?.source ?? .claude
                    try ClaudePromptSender.sendPrompt(promptText, source: source, workingDirectory: session?.cwd)
                    DispatchQueue.main.async {
                        promptText = ""
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
