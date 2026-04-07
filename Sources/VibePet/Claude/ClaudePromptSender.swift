import Foundation

final class ClaudePromptSender {
    enum SendError: Error {
        case cliNotFound
        case executionFailed(String)
    }

    private static let claudePaths = [
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
        "/usr/bin/claude",
        "~/.local/bin/claude"
    ]

    private static let codexPaths = [
        "/usr/local/bin/codex",
        "/opt/homebrew/bin/codex",
        "/usr/bin/codex",
        "~/.local/bin/codex"
    ]

    static func findCLIPath(for source: SessionSource) -> String? {
        let paths: [String]
        let command: String

        switch source {
        case .codex:
            paths = codexPaths
            command = "codex"
        case .claude, .coco, .unknown:
            paths = claudePaths
            command = "claude"
        }

        for path in paths {
            let expanded = NSString(string: path).expandingTildeInPath
            if FileManager.default.fileExists(atPath: expanded) {
                return expanded
            }
        }

        // Try `which`
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = [command]
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

    static func sendPrompt(_ prompt: String, source: SessionSource = .claude, workingDirectory: String? = nil) throws {
        guard let cliPath = findCLIPath(for: source) else {
            throw SendError.cliNotFound
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: cliPath)
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
