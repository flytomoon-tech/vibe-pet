import Foundation
import AppKit

enum TerminalJump {
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
            return
        }

        switch bundleId {
        case "com.apple.Terminal":
            sendTextToTerminalApp(tty: session.tty, text: text)
        case "com.googlecode.iterm2":
            sendTextToITerm(tty: session.tty, text: text)
        default:
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
        let escapedText = text.replacingOccurrences(of: "\\", with: "\\\\")
                              .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(tty)" then
                        do script "\(escapedText)" in t
                        set selected tab of w to t
                        set index of w to 1
                        activate
                        return
                    end if
                end repeat
            end repeat
        end tell
        """
        runAppleScript(script)
    }

    private static func sendTextToITerm(tty: String?, text: String) {
        guard let tty else { return }
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
