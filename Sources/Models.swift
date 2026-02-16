import Foundation
import SwiftUI

struct Category: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    let createdAt: Date
    var updatedAt: Date
}

struct FocusSegment: Codable, Hashable {
    let start: Date
    let end: Date
}

struct FocusSession: Identifiable, Codable, Hashable {
    let id: UUID
    let startedAt: Date
    let endedAt: Date
    let durationSec: Int
    let categoryId: UUID
    let categoryNameSnapshot: String
    let segments: [FocusSegment]
}

enum AppTheme: String, CaseIterable, Codable, Identifiable {
    case tomato
    case ocean
    case forest
    case brown
    case white
    case black
    case pastelLilac
    case pastelPink
    case pastelRose
    case pastelButter
    case skyBlue

    var id: String { rawValue }

    var label: String {
        switch self {
        case .tomato: return "토마토"
        case .ocean: return "오션"
        case .forest: return "포레스트"
        case .brown: return "브라운"
        case .white: return "화이트"
        case .black: return "블랙"
        case .pastelLilac: return "라일락"
        case .pastelPink: return "핑크"
        case .pastelRose: return "로즈"
        case .pastelButter: return "버터"
        case .skyBlue: return "하늘색"
        }
    }

    var color: Color {
        switch self {
        case .tomato: return Color(red: 0.89, green: 0.24, blue: 0.20)
        case .ocean: return Color(red: 0.18, green: 0.36, blue: 0.87) // #2D5BDE
        case .forest: return Color(red: 0.12, green: 0.36, blue: 0.23) // #1F5C3B
        case .brown: return Color(red: 0.56, green: 0.36, blue: 0.24) // #8F5B3D
        case .white: return Color(red: 0.96, green: 0.96, blue: 0.96)
        case .black: return Color(red: 0.10, green: 0.10, blue: 0.10)
        case .pastelLilac: return Color(red: 0.80, green: 0.67, blue: 1.00) // #CCA9FF
        case .pastelPink: return Color(red: 1.00, green: 0.66, blue: 0.92) // #FFA8EB
        case .pastelRose: return Color(red: 1.00, green: 0.63, blue: 0.76) // #FFA0C2
        case .pastelButter: return Color(red: 1.00, green: 0.72, blue: 0.22) // #FFB839
        case .skyBlue: return Color(red: 0.55, green: 0.82, blue: 1.00) // #8CD1FF
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        switch raw {
        case "tomato":
            self = .tomato
        case "ocean":
            self = .ocean
        case "forest":
            self = .forest
        case "brown":
            self = .brown
        case "white":
            self = .white
        case "black":
            self = .black
        case "pastelLilac":
            self = .pastelLilac
        case "pastelPink":
            self = .pastelPink
        case "pastelRose":
            self = .pastelRose
        case "pastelButter":
            self = .pastelButter
        case "skyBlue":
            self = .skyBlue
        case "pastelPeach":
            // Backward compatibility: migrate removed peach theme to butter.
            self = .pastelButter
        case "pastelLime":
            // Backward compatibility: migrate removed lime theme to sky blue.
            self = .skyBlue
        default:
            self = .tomato
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    var controlForegroundColor: Color {
        switch self {
        case .white:
            return .black
        default:
            return .white
        }
    }

    var selectionStrokeColor: Color {
        switch self {
        case .white:
            return Color.secondary
        default:
            return color
        }
    }
}

enum NotificationSoundOption: String, CaseIterable, Codable, Identifiable {
    case clearBell
    case piano
    case cuckoo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .clearBell: return "수업종1"
        case .piano: return "수업종2"
        case .cuckoo: return "수업종3"
        }
    }
}

enum WhiteNoiseTrack: String, CaseIterable, Codable, Identifiable {
    case rain
    case fire

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rain: return "비 소리"
        case .fire: return "장작 타는 소리"
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)

        switch raw {
        case "rain", "bgm-rain":
            self = .rain
        case "fire", "bgm-fire", "cafe":
            // Backward compatibility: migrate old "cafe" selection to "fire".
            self = .fire
        default:
            self = .rain
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum StatsRange: String, CaseIterable, Codable, Identifiable {
    case day
    case week
    case month
    case sixMonths
    case year

    var id: String { rawValue }

    var label: String {
        switch self {
        case .day: return "1일"
        case .week: return "1주"
        case .month: return "1개월"
        case .sixMonths: return "6개월"
        case .year: return "1년"
        }
    }
}

struct AppSettings: Codable {
    var defaultMinutes: Int
    var breakMinutes: Int
    var breakCycleEnabled: Bool
    var theme: AppTheme
    var notificationSound: NotificationSoundOption
    var whiteNoiseEnabled: Bool
    var whiteNoiseTrack: WhiteNoiseTrack

    private enum CodingKeys: String, CodingKey {
        case defaultMinutes
        case breakMinutes
        case breakCycleEnabled
        case theme
        case notificationSound
        case whiteNoiseEnabled
        case whiteNoiseTrack
    }

    init(
        defaultMinutes: Int,
        breakMinutes: Int,
        breakCycleEnabled: Bool,
        theme: AppTheme,
        notificationSound: NotificationSoundOption,
        whiteNoiseEnabled: Bool,
        whiteNoiseTrack: WhiteNoiseTrack
    ) {
        self.defaultMinutes = max(1, min(60, defaultMinutes))
        self.breakMinutes = max(1, min(60, breakMinutes))
        self.breakCycleEnabled = breakCycleEnabled
        self.theme = theme
        self.notificationSound = notificationSound
        self.whiteNoiseEnabled = whiteNoiseEnabled
        self.whiteNoiseTrack = whiteNoiseTrack
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.defaultMinutes = max(1, min(60, try container.decodeIfPresent(Int.self, forKey: .defaultMinutes) ?? 25))
        self.breakMinutes = max(1, min(60, try container.decodeIfPresent(Int.self, forKey: .breakMinutes) ?? 5))
        self.breakCycleEnabled = try container.decodeIfPresent(Bool.self, forKey: .breakCycleEnabled) ?? true
        self.theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .tomato
        self.notificationSound = try container.decodeIfPresent(NotificationSoundOption.self, forKey: .notificationSound) ?? .clearBell
        self.whiteNoiseEnabled = try container.decodeIfPresent(Bool.self, forKey: .whiteNoiseEnabled) ?? false
        self.whiteNoiseTrack = try container.decodeIfPresent(WhiteNoiseTrack.self, forKey: .whiteNoiseTrack) ?? .rain
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(defaultMinutes, forKey: .defaultMinutes)
        try container.encode(breakMinutes, forKey: .breakMinutes)
        try container.encode(breakCycleEnabled, forKey: .breakCycleEnabled)
        try container.encode(theme, forKey: .theme)
        try container.encode(notificationSound, forKey: .notificationSound)
        try container.encode(whiteNoiseEnabled, forKey: .whiteNoiseEnabled)
        try container.encode(whiteNoiseTrack, forKey: .whiteNoiseTrack)
    }

    static let `default` = AppSettings(
        defaultMinutes: 25,
        breakMinutes: 5,
        breakCycleEnabled: true,
        theme: .tomato,
        notificationSound: .clearBell,
        whiteNoiseEnabled: false,
        whiteNoiseTrack: .rain
    )
}

struct StatsCategoryOption: Identifiable, Hashable {
    let id: UUID?
    let label: String
}

struct StatsBarDatum: Identifiable {
    let id = UUID()
    let order: Int
    let label: String
    let seconds: Int
}
