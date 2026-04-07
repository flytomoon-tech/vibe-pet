import Foundation

final class HookInstaller {
    private var bridgeCommand: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return "\(home)/.vibe-pet/bin/vibe-pet-bridge"
    }

    func installAll() {
        do {
            try installClaudeHooks()
            print("[VibePet] Claude Code hooks installed")
        } catch {
            print("[VibePet] Failed to install Claude hooks: \(error)")
        }

        do {
            try installCodexHooks()
            print("[VibePet] Codex hooks installed")
        } catch {
            print("[VibePet] Failed to install Codex hooks: \(error)")
        }

        do {
            try installCocoHooks()
            print("[VibePet] Coco hooks installed")
        } catch {
            print("[VibePet] Failed to install Coco hooks: \(error)")
        }

        UserDefaults.standard.set(true, forKey: "vibepet.hooksInstalled")
    }

    func uninstallAll() {
        do { try uninstallClaudeHooks(); print("[VibePet] Claude hooks removed") }
        catch { print("[VibePet] Failed to remove Claude hooks: \(error)") }

        do { try uninstallCodexHooks(); print("[VibePet] Codex hooks removed") }
        catch { print("[VibePet] Failed to remove Codex hooks: \(error)") }

        do { try uninstallCocoHooks(); print("[VibePet] Coco hooks removed") }
        catch { print("[VibePet] Failed to remove Coco hooks: \(error)") }

        UserDefaults.standard.set(false, forKey: "vibepet.hooksInstalled")
    }

    /// Only install if not explicitly uninstalled by user
    func installIfNeeded() {
        // First launch (key doesn't exist) or previously installed → install
        let key = "vibepet.hooksInstalled"
        if UserDefaults.standard.object(forKey: key) == nil || UserDefaults.standard.bool(forKey: key) {
            installAll()
        } else {
            print("[VibePet] Hooks previously uninstalled by user, skipping auto-install")
        }
    }

    // MARK: - Claude Code (~/.claude/settings.json)

    private func installClaudeHooks() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".claude")
        guard FileManager.default.fileExists(atPath: dir.path) else {
            print("[VibePet] ~/.claude not found, skipping Claude hooks")
            return
        }
        let settingsPath = dir.appendingPathComponent("settings.json")

        var config = readJSON(at: settingsPath) ?? [:]

        // Create backup
        backup(file: settingsPath)

        // Get or create hooks dict
        var hooks = config["hooks"] as? [String: Any] ?? [:]

        let claudeEvents = [
            "SessionStart", "SessionEnd", "Stop", "PermissionRequest",
            "Notification", "UserPromptSubmit", "PreToolUse", "PostToolUse",
        ]

        for event in claudeEvents {
            let timeout: Int = event == "PermissionRequest" ? 86400 : 10
            hooks[event] = mergeHookEntry(
                existing: hooks[event] as? [[String: Any]] ?? [],
                command: "\(bridgeCommand) --source claude",
                timeout: timeout
            )
        }

        config["hooks"] = hooks
        try writeJSON(config, to: settingsPath)
    }

    // MARK: - Codex (~/.codex/hooks.json)

    private func installCodexHooks() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".codex")
        guard FileManager.default.fileExists(atPath: dir.path) else {
            print("[VibePet] ~/.codex not found, skipping Codex hooks")
            return
        }
        let hooksPath = dir.appendingPathComponent("hooks.json")

        var config = readJSON(at: hooksPath) ?? [:]

        backup(file: hooksPath)

        var hooks = config["hooks"] as? [String: Any] ?? [:]

        let codexEvents = ["SessionStart", "UserPromptSubmit", "Stop"]

        for event in codexEvents {
            hooks[event] = mergeHookEntry(
                existing: hooks[event] as? [[String: Any]] ?? [],
                command: "\(bridgeCommand) --source codex",
                timeout: 5
            )
        }

        config["hooks"] = hooks
        try writeJSON(config, to: hooksPath)
    }

    // MARK: - Helpers

    // MARK: - Coco / Trae CLI (~/.trae/traecli.yaml)

    private func installCocoHooks() throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let dir = home.appendingPathComponent(".trae")
        guard FileManager.default.fileExists(atPath: dir.path) else {
            print("[VibePet] ~/.trae not found, skipping Coco hooks")
            return
        }
        let yamlPath = dir.appendingPathComponent("traecli.yaml")

        backup(file: yamlPath)

        let content = (try? String(contentsOf: yamlPath, encoding: .utf8)) ?? ""
        let updated = updateCocoHooks(in: content, includeVibePetHook: true)
        try updated.write(to: yamlPath, atomically: true, encoding: .utf8)
    }

    private func uninstallCocoHooks() throws {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".trae/traecli.yaml")
        guard let content = try? String(contentsOf: path, encoding: .utf8) else { return }
        guard content.contains("vibe-pet-bridge") else { return }
        backup(file: path)

        let cleaned = updateCocoHooks(in: content, includeVibePetHook: false)
        try cleaned.write(to: path, atomically: true, encoding: .utf8)
    }

    private func isVibePetCommand(_ cmd: String?) -> Bool {
        guard let cmd else { return false }
        return cmd.contains("vibe-pet-bridge") || cmd.contains("vibe-cat-bridge")
    }

    private struct CocoHookItem {
        let lines: [String]
        let command: String?
    }

    private struct CocoHooksSection {
        let keyLine: Int
        let bodyEnd: Int
        let indent: Int
        let itemIndent: Int
        let leadingLines: [String]
        let items: [CocoHookItem]
    }

    private func updateCocoHooks(in content: String, includeVibePetHook: Bool) -> String {
        var lines = yamlLines(from: content)
        let vibePetLines = cocoVibePetHookLines(itemIndent: 2)

        if let section = parseCocoHooksSection(in: lines) {
            var items = section.items.filter { !isVibePetCommand($0.command) && !isVibePetHookBlock($0.lines) }

            if includeVibePetHook {
                items.append(
                    CocoHookItem(
                        lines: cocoVibePetHookLines(itemIndent: section.itemIndent),
                        command: "\(bridgeCommand) --source coco"
                    )
                )
            }

            let replacement: [String]
            if items.isEmpty {
                replacement = []
            } else {
                replacement = ["\(String(repeating: " ", count: section.indent))hooks:"]
                    + section.leadingLines
                    + items.flatMap(\.lines)
            }

            lines.replaceSubrange(section.keyLine..<section.bodyEnd, with: replacement)
            return renderYAML(lines)
        }

        guard includeVibePetHook else { return renderYAML(lines) }

        if !lines.isEmpty, lines.last?.trimmingCharacters(in: .whitespaces).isEmpty == false {
            lines.append("")
        }
        lines.append("hooks:")
        lines.append(contentsOf: vibePetLines)
        return renderYAML(lines)
    }

    private func parseCocoHooksSection(in lines: [String]) -> CocoHooksSection? {
        for index in lines.indices {
            let line = lines[index]
            let trimmed = yamlTrimmed(line)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), indentation(of: line) == 0 else { continue }
            guard isHooksKeyLine(trimmed) else { continue }

            let indent = indentation(of: line)
            var bodyEnd = index + 1
            while bodyEnd < lines.count {
                let nextLine = lines[bodyEnd]
                let nextTrimmed = yamlTrimmed(nextLine)
                if !nextTrimmed.isEmpty && !nextTrimmed.hasPrefix("#") && indentation(of: nextLine) <= indent {
                    break
                }
                bodyEnd += 1
            }

            let bodyLines = Array(lines[(index + 1)..<bodyEnd])
            var leadingLines: [String] = []
            var items: [CocoHookItem] = []
            var currentItemLines: [String] = []
            var itemIndent: Int?

            for bodyLine in bodyLines {
                let bodyTrimmed = yamlTrimmed(bodyLine)
                let bodyIndent = indentation(of: bodyLine)
                let isCandidateItem = bodyTrimmed.hasPrefix("- ")
                let isNewItem: Bool

                if isCandidateItem {
                    if let itemIndent {
                        isNewItem = bodyIndent == itemIndent
                    } else {
                        isNewItem = bodyIndent > indent
                    }
                } else {
                    isNewItem = false
                }

                if isNewItem {
                    if !currentItemLines.isEmpty {
                        items.append(CocoHookItem(lines: currentItemLines, command: commandValue(in: currentItemLines)))
                    }
                    currentItemLines = [bodyLine]
                    itemIndent = bodyIndent
                    continue
                }

                if currentItemLines.isEmpty {
                    if bodyTrimmed.isEmpty || bodyTrimmed.hasPrefix("#") {
                        leadingLines.append(bodyLine)
                    }
                } else {
                    currentItemLines.append(bodyLine)
                }
            }

            if !currentItemLines.isEmpty {
                items.append(CocoHookItem(lines: currentItemLines, command: commandValue(in: currentItemLines)))
            }

            return CocoHooksSection(
                keyLine: index,
                bodyEnd: bodyEnd,
                indent: indent,
                itemIndent: itemIndent ?? (indent + 2),
                leadingLines: leadingLines,
                items: items
            )
        }

        return nil
    }

    private func cocoVibePetHookLines(itemIndent: Int) -> [String] {
        let nestedIndent = itemIndent + 2
        return [
            "\(String(repeating: " ", count: itemIndent))- type: command",
            "\(String(repeating: " ", count: nestedIndent))command: '\(bridgeCommand) --source coco'",
            "\(String(repeating: " ", count: nestedIndent))matchers:",
            "\(String(repeating: " ", count: nestedIndent + 2))- event: user_prompt_submit",
            "\(String(repeating: " ", count: nestedIndent + 2))- event: post_tool_use",
            "\(String(repeating: " ", count: nestedIndent + 2))- event: stop",
            "\(String(repeating: " ", count: nestedIndent + 2))- event: subagent_stop",
        ]
    }

    private func isHooksKeyLine(_ trimmedLine: String) -> Bool {
        guard !trimmedLine.hasPrefix("- "), let colon = trimmedLine.firstIndex(of: ":") else { return false }
        return trimmedLine[..<colon] == "hooks"
    }

    private func commandValue(in itemLines: [String]) -> String? {
        for line in itemLines {
            let trimmed = yamlTrimmed(line)
            if let value = yamlValue(for: "command", in: trimmed) {
                return value
            }

            if trimmed.hasPrefix("- "),
               let value = yamlValue(for: "command", in: String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)) {
                return value
            }
        }
        return nil
    }

    private func yamlValue(for key: String, in trimmedLine: String) -> String? {
        guard trimmedLine.hasPrefix("\(key):") else { return nil }
        let rawValue = trimmedLine.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces)
        guard !rawValue.isEmpty else { return nil }
        if rawValue.hasPrefix("'"), rawValue.hasSuffix("'"), rawValue.count >= 2 {
            return String(rawValue.dropFirst().dropLast())
        }
        if rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), rawValue.count >= 2 {
            return String(rawValue.dropFirst().dropLast())
        }
        return String(rawValue)
    }

    private func isVibePetHookBlock(_ lines: [String]) -> Bool {
        lines.contains { isVibePetCommand(commandValue(in: [$0])) || $0.contains("vibe-pet-bridge") || $0.contains("vibe-cat-bridge") }
    }

    private func yamlLines(from content: String) -> [String] {
        content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    private func renderYAML(_ lines: [String]) -> String {
        let rendered = lines.joined(separator: "\n").trimmingCharacters(in: CharacterSet(charactersIn: "\n"))
        return rendered.isEmpty ? "" : rendered + "\n"
    }

    private func indentation(of line: String) -> Int {
        line.prefix(while: { $0 == " " }).count
    }

    private func yamlTrimmed(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespaces)
    }

    private func uninstallClaudeHooks() throws {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/settings.json")
        guard var config = readJSON(at: path) else { return }
        guard var hooks = config["hooks"] as? [String: Any] else { return }
        backup(file: path)
        for key in hooks.keys {
            if var entries = hooks[key] as? [[String: Any]] {
                entries.removeAll { entry in
                    guard let h = entry["hooks"] as? [[String: Any]] else { return false }
                    return h.contains { isVibePetCommand($0["command"] as? String) }
                }
                hooks[key] = entries.isEmpty ? nil : entries
            }
        }
        config["hooks"] = hooks.isEmpty ? nil : hooks
        try writeJSON(config, to: path)
    }

    private func uninstallCodexHooks() throws {
        let path = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".codex/hooks.json")
        guard var config = readJSON(at: path) else { return }
        guard var hooks = config["hooks"] as? [String: Any] else { return }
        backup(file: path)
        for key in hooks.keys {
            if var entries = hooks[key] as? [[String: Any]] {
                entries.removeAll { entry in
                    guard let h = entry["hooks"] as? [[String: Any]] else { return false }
                    return h.contains { isVibePetCommand($0["command"] as? String) }
                }
                hooks[key] = entries.isEmpty ? nil : entries
            }
        }
        config["hooks"] = hooks.isEmpty ? nil : hooks
        try writeJSON(config, to: path)
    }

    // MARK: - Helpers (JSON)

    /// Merge our hook entry into existing entries without removing others
    private func mergeHookEntry(existing: [[String: Any]], command: String, timeout: Int) -> [[String: Any]] {
        let vibePetHook: [String: Any] = [
            "type": "command",
            "command": command,
            "timeout": timeout,
        ]

        let vibePetEntry: [String: Any] = [
            "matcher": "*",
            "hooks": [vibePetHook],
        ]

        // Check if we already have a vibe-pet entry
        var entries = existing
        if let idx = entries.firstIndex(where: { entry in
            guard let hooks = entry["hooks"] as? [[String: Any]] else { return false }
            return hooks.contains { hook in
                (hook["command"] as? String)?.contains("vibe-pet-bridge") == true
            }
        }) {
            entries[idx] = vibePetEntry
        } else {
            entries.append(vibePetEntry)
        }

        return entries
    }

    private func readJSON(at url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }

    private func writeJSON(_ dict: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: url, options: .atomic)
    }

    private func backup(file url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let backupURL = url.appendingPathExtension("vibe-pet-backup")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.copyItem(at: url, to: backupURL)
    }
}
