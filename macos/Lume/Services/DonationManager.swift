import Foundation
import CryptoKit
import SwiftUI

@MainActor
final class DonationManager: ObservableObject {
    @Published var showPopup = false
    @Published var hasDonated: Bool
    @Published var remindersDisabled: Bool

    // ───────────────────────────────────────────────────────────────
    // Crypto for the donation key.
    //
    // The user-facing valid donor key is kept off the repository.
    // It is NEVER stored in the binary — only its HMAC-SHA256 digest
    // (with a per-app pepper) is. The pepper itself is stored as raw
    // bytes (no plaintext string literal) so a quick `strings` of the
    // binary does not reveal it. Reversing the digest requires breaking
    // SHA-256, which is computationally infeasible.
    //
    // Developer workflow: when a user emails proof of donation, send them
    // the literal donor key. The app validates
    // by recomputing the HMAC and comparing.
    // ───────────────────────────────────────────────────────────────

    /// Pepper as raw bytes — not a UTF-8 string in the source.
    /// Decodes back to "lume-2026-hasen-borges-protect-secret-pepper-v2".
    private static let pepperBytes: [UInt8] = [
        0x6c, 0x75, 0x6d, 0x65, 0x2d, 0x32, 0x30, 0x32, 0x36, 0x2d, 0x68, 0x61,
        0x73, 0x65, 0x6e, 0x2d, 0x62, 0x6f, 0x72, 0x67, 0x65, 0x73, 0x2d, 0x70,
        0x72, 0x6f, 0x74, 0x65, 0x63, 0x74, 0x2d, 0x73, 0x65, 0x63, 0x72, 0x65,
        0x74, 0x2d, 0x70, 0x65, 0x70, 0x70, 0x65, 0x72, 0x2d, 0x76, 0x32
    ]

    /// HMAC-SHA256 of the donor key with the pepper above.
    private static let expectedHMAC: [UInt8] = [
        0x3f, 0x5d, 0x8f, 0x1c, 0x61, 0x73, 0x3d, 0x69,
        0x38, 0x08, 0x07, 0x26, 0xff, 0x31, 0x0b, 0x89,
        0x7b, 0x07, 0x50, 0x57, 0x4d, 0x7d, 0x8c, 0x90,
        0xfd, 0x2e, 0x42, 0xf6, 0x6c, 0x0b, 0xb9, 0x39
    ]

    private static let thirtyDays: TimeInterval = 30 * 24 * 60 * 60

    init() {
        hasDonated = UserDefaults.standard.bool(forKey: "lume.hasDonated")
        remindersDisabled = UserDefaults.standard.bool(forKey: "lume.remindersDisabled")
    }

    func checkShouldShow() {
        guard !hasDonated, !remindersDisabled else { return }
        let last = UserDefaults.standard.object(forKey: "lume.lastDonationReminder") as? Date
        guard last == nil || Date().timeIntervalSince(last!) >= Self.thirtyDays else { return }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            showPopup = true
        }
    }

    func dismissRemindLater() {
        UserDefaults.standard.set(Date(), forKey: "lume.lastDonationReminder")
        showPopup = false
    }

    func disableReminders() {
        remindersDisabled = true
        UserDefaults.standard.set(true, forKey: "lume.remindersDisabled")
        showPopup = false
    }

    func validateKey(_ key: String) -> Bool {
        let trimmed = key
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
        let pepperKey = SymmetricKey(data: Data(Self.pepperBytes))
        let digest = HMAC<SHA256>.authenticationCode(
            for: Data(trimmed.utf8),
            using: pepperKey
        )
        // Constant-time comparison to avoid timing leaks (overkill here, but cheap).
        let computed = Array(digest)
        guard computed.count == Self.expectedHMAC.count else { return false }
        var match: UInt8 = 0
        for i in 0..<computed.count { match |= computed[i] ^ Self.expectedHMAC[i] }
        return match == 0
    }

    @discardableResult
    func applyKey(_ key: String) -> Bool {
        guard validateKey(key) else { return false }
        hasDonated = true
        remindersDisabled = true
        UserDefaults.standard.set(true, forKey: "lume.hasDonated")
        UserDefaults.standard.set(true, forKey: "lume.remindersDisabled")
        showPopup = false
        return true
    }
}
