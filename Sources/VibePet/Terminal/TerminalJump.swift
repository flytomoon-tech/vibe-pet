import Foundation
import AppKit

enum TerminalJump {
    private static func logDebug(_ message: String) {
        let logFile = "/tmp/vibe-pet-terminal-jump.log"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)\n"
        if let data = line.data(using: .utf8) {
            if let handle = FileHandle(forWritingAtPath: logFile) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            } else {
                try? data.write(to: URL(fileURLWithPath: logFile))
            }
        }
    }

    static func jump(to session: Session) {
        guard let bundleId = session.terminalBundleId else {
            // Fallback: try Terminal.app
            activateApp(bundleId: "com.apple.Terminal")
            return
        }

        switch bundleId {
        case "com.apple.Terminal":
            jumpToTerminalApp(tty: session.tty)
        case "com.googlecode.iterm2":
            jumpToITerm(tty: session.tty)
        default:
            activateApp(bundleId: bundleId)
        }
    }

    static func sendText(to session: Session, text: String) {
        guard let bundleId = session.terminalBundleId else {
            logDebug("sendText: no bundleId for session \(session.id)")
            return
        }

        logDebug("sendText: session=\(session.id) bundleId=\(bundleId) tty=\(session.tty ?? "nil") text=\(text.prefix(50))")

        switch bundleId {
        case "com.apple.Terminal":
            sendTextToTerminalApp(tty: session.tty, text: text)
        case "com.googlecode.iterm2":
            sendTextToITerm(tty: session.tty, text: text)
        default:
            logDebug("sendText: unsupported bundleId \(bundleId)")
            break
        }
    }

    private static func jumpToTerminalApp(tty: String?) {
        if let tty {
            let script = """
            tell application "Terminal"
                repeat with w in windows
                    repeat with t in tabs of w
                        if tty of t is "\(tty)" then
                            set selected tab of w to t
                            set index of w to 1
                        end if
                    end repeat
                end repeat
                activate
            end tell
            """
            runAppleScript(script)
        } else {
            activateApp(bundleId: "com.apple.Terminal")
        }
    }

    private static func jumpToITerm(tty: String?) {
        if let tty {
            let script = """
            tell application "iTerm2"
                repeat with w in windows
                    repeat with t in tabs of w
                        repeat with s in sessions of t
                            if tty of s is "\(tty)" then
                                select t
                                tell w to select
                            end if
                        end repeat
                    end repeat
                end repeat
                activate
            end tell
            """
            runAppleScript(script)
        } else {
            activateApp(bundleId: "com.googlecode.iterm2")
        }
    }

    private static func sendTextToTerminalApp(tty: String?, text: String) {
        guard let tty else { return }

        // For Terminal.app, we need to use a different approach
        // Write text to a temp file and use pbcopy + paste
        let tempFile = "/tmp/vibe-pet-input-\(UUID().uuidString).txt"
        try? text.write(toFile: tempFile, atomically: true, encoding: .utf8)

        let script = """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(tty)" then
                        set selected tab of w to t
                        set index of w to 1
                        activate
                        delay 0.1
                        tell application "System Events"
                            tell process "Terminal"
                                set the clipboard to "\(text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))"
                                keystroke "v" using command down
                                delay 0.05
                                keystroke return
                            end tell
                        end tell
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        logDebug("Executing AppleScript with paste method for Terminal.app")
        runAppleScript(script)

        // Clean up temp file after a delay
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            try? FileManager.default.removeItem(atPath: tempFile)
        }
    }

    private static func sendTextToITerm(tty: String?, text: String) {
        guard let tty else { return }
        // iTerm2's "write text" automatically sends the text (simulates typing + return)
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
                              .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if tty of s is "\(tty)" then
                            tell s to write text "\(escapedText)"
                            select t
                            tell w to select
                            activate
                            return
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    private static func activateApp(bundleId: String) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleId).first {
            app.activate()
        }
    }

    private static func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }
}
