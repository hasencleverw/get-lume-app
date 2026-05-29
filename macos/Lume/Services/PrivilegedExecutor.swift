import Foundation
import AppKit

/// Asks the user for their admin password ONCE per app session and keeps it
/// in memory only. Subsequent privileged commands run silently via `sudo -S`
/// using the stored password. The password is never persisted to disk and is
/// cleared when the process exits.
///
/// This replaces the old `AuthorizationExecuteWithPrivileges`-based approach
/// (which Apple has been steadily neutering — recent macOS versions prompt
/// every call regardless of the cached AuthorizationRef).
@MainActor
final class PrivilegedExecutor: ObservableObject {
    static let shared = PrivilegedExecutor()

    /// Surfaces whether the user has unlocked maintenance mode this session.
    @Published private(set) var isUnlocked = false

    /// Hold the password in memory only. NEVER persisted.
    private var cachedPassword: String?

    /// Prompts the user once (custom NSAlert with secure field), verifies the
    /// password, and stores it. Returns `true` on success.
    @discardableResult
    func authorize() -> Bool {
        if isUnlocked { return true }
        return promptAndVerify()
    }

    /// Runs `command` as root via `sudo -S`, feeding the cached password to
    /// sudo's stdin. The user is NOT prompted again as long as the password
    /// is unlocked.
    @discardableResult
    func runShell(_ command: String) -> Bool {
        guard authorize(), let password = cachedPassword else { return false }
        return Self.executeSudo(command: command, password: password)
    }

    /// Forget the stored password — next privileged op will re-prompt.
    func lock() {
        cachedPassword = nil
        isUnlocked = false
    }

    // MARK: - Private

    private func promptAndVerify() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Permissão para tarefas de manutenção"
        alert.informativeText = ""
        alert.alertStyle = .informational
        alert.icon = NSApp.applicationIconImage

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "Senha"
        alert.accessoryView = field
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancelar")
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return false }

        let pwd = field.stringValue
        guard !pwd.isEmpty else { return false }

        if Self.verifyPassword(pwd) {
            cachedPassword = pwd
            isUnlocked = true
            return true
        } else {
            let err = NSAlert()
            err.messageText = "Senha incorreta"
            err.alertStyle = .warning
            err.runModal()
            return false
        }
    }

    /// Verify by running `sudo -S -k /usr/bin/true`. `-k` forces sudo to ignore
    /// its own cached credentials so the test really checks the password, not
    /// a previously-cached one from this user's session.
    private static func verifyPassword(_ password: String) -> Bool {
        let proc = Process()
        proc.launchPath = "/usr/bin/sudo"
        proc.arguments = ["-S", "-k", "/usr/bin/true"]
        let inPipe = Pipe()
        proc.standardInput  = inPipe
        proc.standardOutput = Pipe()
        proc.standardError  = Pipe()
        do {
            try proc.run()
            try inPipe.fileHandleForWriting.write(contentsOf: Data("\(password)\n".utf8))
            try inPipe.fileHandleForWriting.close()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }

    /// Runs an arbitrary shell command as root with `sudo -S` reading the
    /// password from stdin. Returns whether the command exited cleanly.
    private static func executeSudo(command: String, password: String) -> Bool {
        let proc = Process()
        proc.launchPath = "/usr/bin/sudo"
        proc.arguments = ["-S", "/bin/sh", "-c", command]
        let inPipe = Pipe()
        proc.standardInput  = inPipe
        proc.standardOutput = Pipe()
        proc.standardError  = Pipe()
        do {
            try proc.run()
            try inPipe.fileHandleForWriting.write(contentsOf: Data("\(password)\n".utf8))
            try inPipe.fileHandleForWriting.close()
            proc.waitUntilExit()
            return proc.terminationStatus == 0
        } catch {
            return false
        }
    }
}
