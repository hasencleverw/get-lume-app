import AVFoundation
import Foundation

@MainActor
final class SoundManager {
    static let shared = SoundManager()
    private var player: AVAudioPlayer?

    func playCompletion() {
        guard let url = soundURL() else { return }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 0.7
            player?.play()
        } catch {
            // Sound playback is best-effort
        }
    }

    private func soundURL() -> URL? {
        if let url = Bundle.main.url(forResource: "mainaudio", withExtension: "mp3") {
            return url
        }
        // Fallback: beside the binary (dev builds via swift run)
        let dir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        let candidate = dir.appendingPathComponent("mainaudio.mp3")
        return FileManager.default.fileExists(atPath: candidate.path) ? candidate : nil
    }

    private init() {}
}
