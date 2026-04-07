import Foundation

final class ClaudePromptSender {
    enum SendError: Error {
        case claudeNotFound
        case executionFailed(String)
    }

    private static let possibleClaudePaths = [
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "/usr/bin/claude",
        "~/.local/bin/claude"
    ]

    static func findClaudePath() -> String? {
        for path in possibleClaudePaths {
            let expanded = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return expanded
            }
        }

        // Try `which claude`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["claude"]
        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    return path
                }
            }
        } catch {
            return nil
        }

        return nil
    }

    static func sendPrompt(_ prompt: String, workingDirectory: String? = nil) throws {
        guard let claudePath = findClaudePath() else {
            throw SendError.claudeNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        process.arguments = [prompt]

        if let cwd = workingDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        // Capture output for debugging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            // Don't wait - let it run in background
        } catch {
            throw SendError.executionFailed(error.localizedDescription)
        }
    }
}
