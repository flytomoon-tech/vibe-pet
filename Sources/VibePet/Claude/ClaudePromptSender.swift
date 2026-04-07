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

        // Create a temporary script that runs the CLI with the prompt
        let tempScript = "/tmp/vibe-pet-launch-\(UUID().uuidString).sh"
        let escapedPrompt = prompt.replacingOccurrences(of: "'", with: "'\\''")
        let scriptContent: String

        if let cwd = workingDirectory {
            scriptContent = """
            #!/bin/bash
            cd '\(cwd.replacingOccurrences(of: "'", with: "'\\''"))'
            '\(cliPath.replacingOccurrences(of: "'", with: "'\\''"))' '\(escapedPrompt)'
            """
        } else {
            scriptContent = """
            #!/bin/bash
            '\(cliPath.replacingOccurrences(of: "'", with: "'\\''"))' '\(escapedPrompt)'
            """
        }

        try scriptContent.write(toFile: tempScript, atomically: true, encoding: .utf8)
        chmod(tempScript, 0o755)

        // Use open to launch Terminal with the script
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", "Terminal", tempScript]

        do {
            try process.run()
            process.waitUntilExit()

            // Clean up temp script after a delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                try? FileManager.default.removeItem(atPath: tempScript)
            }

            if process.terminationStatus != 0 {
                throw SendError.executionFailed("open command failed")
            }
        } catch {
            throw SendError.executionFailed(error.localizedDescription)
        }
    }
}
