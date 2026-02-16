import Foundation
import AppKit

enum DefaultsKey {
    static let settings = "app.settings"
    static let categories = "app.categories"
    static let sessions = "app.sessions"
    static let selectedCategoryID = "app.selectedCategoryID"
}

struct PersistenceService {
    let defaults: UserDefaults = .standard

    func loadSettings() -> AppSettings {
        guard let data = defaults.data(forKey: DefaultsKey.settings),
              let value = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return value
    }

    func saveSettings(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: DefaultsKey.settings)
    }

    func loadCategories() -> [Category] {
        guard let data = defaults.data(forKey: DefaultsKey.categories),
              let value = try? JSONDecoder().decode([Category].self, from: data) else {
            return []
        }
        return value
    }

    func saveCategories(_ categories: [Category]) {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        defaults.set(data, forKey: DefaultsKey.categories)
    }

    func loadSessions() -> [FocusSession] {
        guard let data = defaults.data(forKey: DefaultsKey.sessions),
              let value = try? JSONDecoder().decode([FocusSession].self, from: data) else {
            return []
        }
        return value
    }

    func saveSessions(_ sessions: [FocusSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        defaults.set(data, forKey: DefaultsKey.sessions)
    }

    func loadSelectedCategoryID() -> UUID? {
        guard let text = defaults.string(forKey: DefaultsKey.selectedCategoryID) else { return nil }
        return UUID(uuidString: text)
    }

    func saveSelectedCategoryID(_ id: UUID?) {
        defaults.set(id?.uuidString, forKey: DefaultsKey.selectedCategoryID)
    }
}

final class SoundService {
    private var whiteNoisePlayer: NSSound?
    private var completionPlayer: NSSound?
    private var whiteNoisePreviewPlayer: NSSound?
    private var whiteNoisePreviewStopWorkItem: DispatchWorkItem?
    private var lastCompletionPlayedAt: Date = .distantPast
    private let supportedAudioExtensions = ["wav", "m4a", "mp3", "aiff"]

    func playCompletion(for option: NotificationSoundOption) {
        // Guard against accidental duplicate triggers in a short interval.
        let now = Date()
        guard now.timeIntervalSince(lastCompletionPlayedAt) > 1.2 else { return }
        lastCompletionPlayedAt = now

        completionPlayer?.stop()
        completionPlayer = nil

        playResolvedCompletionSound(for: option)
    }

    func previewCompletion(for option: NotificationSoundOption) {
        completionPlayer?.stop()
        completionPlayer = nil
        playResolvedCompletionSound(for: option)
    }

    func updateWhiteNoise(enabled: Bool, track: WhiteNoiseTrack) {
        stopWhiteNoisePreview()
        whiteNoisePlayer?.stop()
        whiteNoisePlayer = nil

        guard enabled else { return }

        let fileBaseName: String = (track == .rain) ? "bgm-rain" : "bgm-fire"
        guard let soundURL = audioURL(fileBaseName: fileBaseName),
              let sound = NSSound(contentsOf: soundURL, byReference: false) else { return }
        sound.loops = true
        sound.volume = 1.0
        sound.play()
        whiteNoisePlayer = sound
    }

    func previewWhiteNoise(track: WhiteNoiseTrack, durationSeconds: TimeInterval = 10) {
        stopWhiteNoisePreview()

        let fileBaseName: String = (track == .rain) ? "bgm-rain" : "bgm-fire"
        guard let soundURL = audioURL(fileBaseName: fileBaseName),
              let sound = NSSound(contentsOf: soundURL, byReference: false) else { return }

        sound.loops = true
        sound.volume = 1.0
        guard sound.play() else { return }

        whiteNoisePreviewPlayer = sound

        let stopWork = DispatchWorkItem { [weak self] in
            self?.stopWhiteNoisePreview()
        }
        whiteNoisePreviewStopWorkItem = stopWork
        DispatchQueue.main.asyncAfter(deadline: .now() + durationSeconds, execute: stopWork)
    }

    func stopWhiteNoisePreview() {
        whiteNoisePreviewStopWorkItem?.cancel()
        whiteNoisePreviewStopWorkItem = nil

        whiteNoisePreviewPlayer?.stop()
        whiteNoisePreviewPlayer = nil
    }

    private func audioURL(fileBaseName: String) -> URL? {
        for ext in supportedAudioExtensions {
            if let url = Bundle.module.url(forResource: fileBaseName, withExtension: ext, subdirectory: "Sounds") {
                return url
            }
            // SwiftPM resource processing may place files at the bundle root.
            if let url = Bundle.module.url(forResource: fileBaseName, withExtension: ext) {
                return url
            }
        }
        return nil
    }

    private func completionSound(for option: NotificationSoundOption) -> NSSound? {
        switch option {
        case .clearBell:
            return bundledSound(fileBaseName: "end-bell-01")
                ?? NSSound(named: NSSound.Name("Glass"))
                ?? NSSound(named: NSSound.Name("Ping"))
        case .piano:
            return bundledSound(fileBaseName: "end-bell-02")
                ?? NSSound(named: NSSound.Name("Hero"))
        case .cuckoo:
            return bundledSound(fileBaseName: "end-bell-03")
                ?? NSSound(named: NSSound.Name("Frog"))
        }
    }

    private func bundledSound(fileBaseName: String) -> NSSound? {
        guard let url = audioURL(fileBaseName: fileBaseName) else { return nil }
        return NSSound(contentsOf: url, byReference: false)
    }

    private func playResolvedCompletionSound(for option: NotificationSoundOption) {
        if let sound = completionSound(for: option) {
            sound.loops = false
            sound.volume = 1.0
            if sound.play() {
                completionPlayer = sound
                return
            }
        }

        // Final fallback so completion is never silent.
        NSSound.beep()
    }
}

func formatDuration(_ seconds: Int) -> String {
    let safe = max(0, seconds)
    let mm = safe / 60
    let ss = safe % 60
    return String(format: "%02d:%02d", mm, ss)
}
