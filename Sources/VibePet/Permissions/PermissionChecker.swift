import Foundation
import AppKit

enum PermissionChecker {
    static func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    static func showAccessibilityAlert() {
        NotificationCenter.default.post(name: .collapseNotchPanelForAlert, object: nil)
        NSApplication.shared.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "需要辅助功能权限"
        alert.informativeText = """
        VibePet 需要“辅助功能”权限，才能向现有终端会话发送回复文本。

        未授予该权限时：
        • 仍然可以创建新会话 ✅
        • 不能回复已有会话 ❌

        点击“打开设置”后，请在“系统设置 > 隐私与安全性 > 辅助功能”中允许 VibePet。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "打开设置")
        alert.addButton(withTitle: "稍后")
        alert.window.level = .modalPanel
        alert.window.orderFrontRegardless()

        if alert.runModal() == .alertFirstButtonReturn {
            requestAccessibilityPermission()
        }
    }
}

extension Notification.Name {
    static let collapseNotchPanelForAlert = Notification.Name("VibePet.collapseNotchPanelForAlert")
}
