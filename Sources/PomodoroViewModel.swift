import Foundation
import SwiftUI

@MainActor
final class PomodoroViewModel: ObservableObject {
    @Published private(set) var settings: AppSettings
    @Published private(set) var categories: [Category]
    @Published private(set) var sessions: [FocusSession]

    @Published var configuredMinutes: Int
    @Published var remainingSeconds: Int
    @Published var isRunning: Bool = false
    @Published var isPaused: Bool = false

    @Published var selectedCategoryID: UUID?
    @Published var showCategoryRequiredAlert: Bool = false
    @Published private(set) var isLockedUntilReset: Bool = false
    @Published private(set) var launchAtLoginEnabled: Bool = false
    @Published var launchAtLoginErrorMessage: String?

    @Published var selectedStatsRange: StatsRange = .day
    @Published var selectedStatsCategoryID: UUID?

    private let persistence = PersistenceService()
    private let soundService = SoundService()
    private let launchAtLoginService = LaunchAtLoginService()

    private var ticker: Timer?
    private var runSegmentStartedAt: Date?
    private var runSegmentStartRemainingSeconds: Int = 0
    private var sessionStartedAt: Date?
    private var activeSegmentStart: Date?
    private var activeSegments: [FocusSegment] = []
    private var sessionTargetSeconds: Int = 0
    private var didCompleteCurrentSession: Bool = false
    private var lastWorkCategoryIDBeforeBreak: UUID?
    private var lastWorkMinutesBeforeBreak: Int?
    private var sessionStartedWithCategoryID: UUID?
    private var sessionStartedWithMinutes: Int = 25
    private static let studyCategoryName = "공부하기"
    private static let breakCategoryName = "휴식"

    init() {
        let loadedSettings = persistence.loadSettings()
        self.settings = loadedSettings
        let persistedCategories = persistence.loadCategories()
        let loadedCategories = Self.ensureRequiredCategories(in: persistedCategories)
        if loadedCategories != persistedCategories {
            persistence.saveCategories(loadedCategories)
        }
        self.categories = Self.sortCategories(loadedCategories)
        self.sessions = persistence.loadSessions().sorted { $0.endedAt > $1.endedAt }

        let safeMinutes = Self.clampMinutes(loadedSettings.defaultMinutes)
        self.configuredMinutes = safeMinutes
        self.remainingSeconds = safeMinutes * 60

        self.selectedCategoryID = studyCategoryID ?? categories.first?.id
        persistence.saveSelectedCategoryID(self.selectedCategoryID)

        self.selectedStatsCategoryID = nil
        soundService.updateWhiteNoise(enabled: false, track: settings.whiteNoiseTrack)
        refreshLaunchAtLoginState()
    }

    deinit {
        ticker?.invalidate()
    }

    var selectedCategoryName: String? {
        guard let selectedCategoryID,
              let category = categories.first(where: { $0.id == selectedCategoryID }) else {
            return nil
        }
        return category.name
    }

    func isFixedCategory(_ category: Category) -> Bool {
        Self.isFixedCategoryName(category.name)
    }

    var timerText: String {
        formatDuration(remainingSeconds)
    }

    var dialProgress: Double {
        if isSessionActive {
            let base = max(1, sessionTargetSeconds)
            return Double(remainingSeconds) / Double(base)
        }
        // While configuring time, reflect dial fill by configuredMinutes (1...60).
        return Double(configuredMinutes) / 60.0
    }

    var menuBarProgress: Double {
        if isSessionActive {
            return dialProgress
        }
        // In idle state, show a fully filled icon by default.
        return 1.0
    }

    var isSessionActive: Bool {
        sessionStartedAt != nil || isPaused || isRunning
    }

    var canEditCategory: Bool {
        !isLockedUntilReset
    }

    var canEditSettings: Bool {
        !isLockedUntilReset
    }

    private var studyCategoryID: UUID? {
        categories.first(where: { $0.name.caseInsensitiveCompare(Self.studyCategoryName) == .orderedSame })?.id
    }

    private var breakCategoryID: UUID? {
        categories.first(where: { $0.name.caseInsensitiveCompare(Self.breakCategoryName) == .orderedSame })?.id
    }

    var statsCategoryOptions: [StatsCategoryOption] {
        var options: [StatsCategoryOption] = [StatsCategoryOption(id: nil, label: "전체")]

        let activeSet = Set(categories.map { $0.id })
        for category in categories {
            options.append(StatsCategoryOption(id: category.id, label: category.name))
        }

        let deletedMap = Dictionary(
            grouping: sessions.filter { !activeSet.contains($0.categoryId) },
            by: { $0.categoryId }
        )

        for (id, list) in deletedMap {
            guard let latest = list.max(by: { $0.endedAt < $1.endedAt }) else { continue }
            options.append(StatsCategoryOption(id: id, label: "\(latest.categoryNameSnapshot) (삭제됨)"))
        }

        return options
    }

    func setConfiguredMinutes(_ value: Int) {
        guard !isSessionActive else { return }
        let safe = Self.clampMinutes(value)
        configuredMinutes = safe
        remainingSeconds = safe * 60
        if selectedCategoryID == breakCategoryID {
            settings.breakMinutes = Self.clampBreakMinutes(safe)
        } else {
            settings.defaultMinutes = safe
        }
        saveSettings()
    }

    func updateMinutesFromDial(_ value: Int) {
        setConfiguredMinutes(value)
    }

    func selectCategory(_ id: UUID) {
        guard canEditCategory else { return }
        selectedCategoryID = id
        syncConfiguredMinutesWithSelectedCategory()
        persistence.saveSelectedCategoryID(selectedCategoryID)
    }

    func addCategory(_ name: String) {
        guard canEditCategory else { return }
        _ = ensureCategory(named: name)
    }

    func updateCategory(id: UUID, newName: String) {
        guard canEditCategory else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard let index = categories.firstIndex(where: { $0.id == id }) else { return }
        guard !Self.isFixedCategoryName(categories[index].name) else { return }
        categories[index].name = trimmed
        categories[index].updatedAt = Date()
        categories = Self.sortCategories(categories)
        persistence.saveCategories(categories)
    }

    func deleteCategory(id: UUID) {
        guard canEditCategory else { return }
        guard let target = categories.first(where: { $0.id == id }),
              !Self.isFixedCategoryName(target.name) else { return }
        categories.removeAll { $0.id == id }
        categories = Self.sortCategories(Self.ensureRequiredCategories(in: categories))

        let fallbackCategoryID = studyCategoryID ?? categories.first?.id

        if selectedCategoryID == id {
            selectedCategoryID = fallbackCategoryID
        }
        persistence.saveSelectedCategoryID(selectedCategoryID)
        persistence.saveCategories(categories)
    }

    func playPauseTapped() {
        if isRunning {
            pauseTimer()
        } else {
            startOrResumeTimer()
        }
    }

    func resetTimer() {
        stopTicker()
        closeActiveSegment(at: Date())

        isRunning = false
        isPaused = false
        remainingSeconds = configuredMinutes * 60
        isLockedUntilReset = false

        sessionStartedAt = nil
        runSegmentStartedAt = nil
        activeSegmentStart = nil
        activeSegments = []
        sessionTargetSeconds = 0
        didCompleteCurrentSession = false
        lastWorkCategoryIDBeforeBreak = nil
        lastWorkMinutesBeforeBreak = nil
        sessionStartedWithCategoryID = nil
        sessionStartedWithMinutes = settings.defaultMinutes
        refreshWhiteNoisePlayback()
    }

    func previewNotificationSound(_ option: NotificationSoundOption) {
        soundService.previewCompletion(for: option)
    }

    func previewBGM(_ track: WhiteNoiseTrack) {
        guard !isRunning else { return }
        soundService.previewWhiteNoise(track: track, durationSeconds: 10)
    }

    func stopBGMPreview() {
        soundService.stopWhiteNoisePreview()
    }

    func refreshLaunchAtLoginState() {
        launchAtLoginEnabled = launchAtLoginService.isEnabled
    }

    @discardableResult
    func setLaunchAtLoginEnabled(_ enabled: Bool) -> Bool {
        guard enabled != launchAtLoginEnabled else { return true }

        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLoginEnabled = launchAtLoginService.isEnabled
            launchAtLoginErrorMessage = nil
            if enabled && !launchAtLoginEnabled {
                launchAtLoginErrorMessage = "자동 실행을 완료하지 못했습니다. 시스템 설정 > 로그인 항목에서 PomodoroBuddy를 허용해 주세요."
                return false
            }
            return true
        } catch {
            launchAtLoginErrorMessage = "자동 실행 설정에 실패했습니다: \(error.localizedDescription)"
            launchAtLoginEnabled = launchAtLoginService.isEnabled
            return false
        }
    }

    func clearLaunchAtLoginError() {
        launchAtLoginErrorMessage = nil
    }

    func applySettingsDraft(
        theme: AppTheme,
        notificationSound: NotificationSoundOption,
        breakMinutes: Int,
        breakCycleEnabled: Bool,
        whiteNoiseEnabled: Bool,
        whiteNoiseTrack: WhiteNoiseTrack
    ) {
        guard canEditSettings else { return }
        settings.theme = theme
        settings.notificationSound = notificationSound
        settings.breakMinutes = Self.clampBreakMinutes(breakMinutes)
        settings.breakCycleEnabled = breakCycleEnabled
        settings.whiteNoiseEnabled = whiteNoiseEnabled
        settings.whiteNoiseTrack = whiteNoiseTrack

        if !isSessionActive,
           selectedCategoryID == breakCategoryID {
            configuredMinutes = settings.breakMinutes
            remainingSeconds = configuredMinutes * 60
        }

        saveSettings()
        refreshWhiteNoisePlayback()
    }

    func applyCategoryDraft(categories: [Category], selectedCategoryID: UUID?) {
        guard canEditCategory else { return }

        self.categories = Self.sortCategories(Self.ensureRequiredCategories(in: categories))

        let fallbackSelectedID = self.categories.first(where: {
            $0.name.caseInsensitiveCompare(Self.studyCategoryName) == .orderedSame
        })?.id ?? self.categories.first?.id

        if let selectedCategoryID, self.categories.contains(where: { $0.id == selectedCategoryID }) {
            self.selectedCategoryID = selectedCategoryID
        } else {
            self.selectedCategoryID = fallbackSelectedID
        }

        syncConfiguredMinutesWithSelectedCategory()

        persistence.saveCategories(self.categories)
        persistence.saveSelectedCategoryID(self.selectedCategoryID)
    }

    func statsSummary() -> (focusCount: Int, totalSeconds: Int) {
        let filtered = filteredSessionsForRange()
        return (filtered.count, filtered.reduce(0) { $0 + $1.durationSec })
    }

    func statsBarData() -> [StatsBarDatum] {
        switch selectedStatsRange {
        case .day:
            return dayHourlyBarData()
        case .week:
            return weekWeekdayBarData()
        case .month:
            return monthDailyBarData()
        case .sixMonths:
            return rollingMonthlyBarData(monthCount: 6)
        case .year:
            return rollingMonthlyBarData(monthCount: 12)
        }
    }

    private func startOrResumeTimer() {
        if selectedCategoryID == nil {
            showCategoryRequiredAlert = true
            return
        }

        isLockedUntilReset = true

        if sessionStartedAt == nil {
            sessionStartedAt = Date()
            activeSegments = []
            sessionTargetSeconds = remainingSeconds
            didCompleteCurrentSession = false
            sessionStartedWithCategoryID = selectedCategoryID
            sessionStartedWithMinutes = configuredMinutes
        }

        runSegmentStartedAt = Date()
        runSegmentStartRemainingSeconds = remainingSeconds
        activeSegmentStart = Date()

        isRunning = true
        isPaused = false
        refreshWhiteNoisePlayback()

        startTicker()
    }

    private func pauseTimer() {
        guard isRunning else { return }
        tick()
        closeActiveSegment(at: Date())

        stopTicker()
        isRunning = false
        isPaused = true
        refreshWhiteNoisePlayback()
    }

    private func completeSession() {
        guard isRunning, !didCompleteCurrentSession else { return }
        didCompleteCurrentSession = true

        guard let categoryID = selectedCategoryID,
              let category = categories.first(where: { $0.id == categoryID }),
              let startedAt = sessionStartedAt else {
            resetTimer()
            return
        }

        closeActiveSegment(at: Date())
        stopTicker()
        isRunning = false
        isPaused = false
        refreshWhiteNoisePlayback()

        let endedAt = Date()
        let duration = activeSegments.reduce(0) { partial, segment in
            partial + max(0, Int(segment.end.timeIntervalSince(segment.start)))
        }

        let session = FocusSession(
            id: UUID(),
            startedAt: startedAt,
            endedAt: endedAt,
            durationSec: duration,
            categoryId: categoryID,
            categoryNameSnapshot: category.name,
            segments: activeSegments
        )

        sessions.insert(session, at: 0)
        persistence.saveSessions(sessions)

        let completedCategoryIsBreak = category.name.caseInsensitiveCompare(Self.breakCategoryName) == .orderedSame

        soundService.playCompletion(for: settings.notificationSound)

        if completedCategoryIsBreak {
            let preferredWorkCategoryID: UUID? = {
                guard let lastWorkCategoryIDBeforeBreak else { return nil }
                guard lastWorkCategoryIDBeforeBreak != breakCategoryID else { return nil }
                guard categories.contains(where: { $0.id == lastWorkCategoryIDBeforeBreak }) else { return nil }
                return lastWorkCategoryIDBeforeBreak
            }()

            selectedCategoryID = preferredWorkCategoryID ?? (studyCategoryID ?? categories.first?.id)
            persistence.saveSelectedCategoryID(selectedCategoryID)
            configuredMinutes = clampedMinutes(
                for: selectedCategoryID,
                value: lastWorkMinutesBeforeBreak ?? sessionStartedWithMinutes
            )
            lastWorkCategoryIDBeforeBreak = nil
            lastWorkMinutesBeforeBreak = nil
        } else if settings.breakCycleEnabled, let breakCategoryID {
            lastWorkCategoryIDBeforeBreak = sessionStartedWithCategoryID ?? categoryID
            lastWorkMinutesBeforeBreak = clampedMinutes(
                for: sessionStartedWithCategoryID ?? categoryID,
                value: sessionStartedWithMinutes
            )
            selectedCategoryID = breakCategoryID
            persistence.saveSelectedCategoryID(selectedCategoryID)
            configuredMinutes = settings.breakMinutes
        } else {
            // When break cycle is off, restore the pre-start category/time directly.
            if let startedCategoryID = sessionStartedWithCategoryID,
               categories.contains(where: { $0.id == startedCategoryID }) {
                selectedCategoryID = startedCategoryID
            }
            persistence.saveSelectedCategoryID(selectedCategoryID)
            configuredMinutes = clampedMinutes(for: selectedCategoryID, value: sessionStartedWithMinutes)
        }

        remainingSeconds = configuredMinutes * 60

        sessionStartedAt = nil
        runSegmentStartedAt = nil
        activeSegmentStart = nil
        activeSegments = []
        sessionTargetSeconds = 0
        didCompleteCurrentSession = false
        sessionStartedWithCategoryID = nil
        sessionStartedWithMinutes = settings.defaultMinutes
    }

    private func startTicker() {
        stopTicker()
        ticker = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.tick()
            }
        }
        if let ticker {
            RunLoop.main.add(ticker, forMode: .common)
        }
    }

    private func stopTicker() {
        ticker?.invalidate()
        ticker = nil
    }

    private func tick() {
        guard isRunning, let runSegmentStartedAt else { return }

        let elapsed = Int(Date().timeIntervalSince(runSegmentStartedAt))
        let next = max(0, runSegmentStartRemainingSeconds - elapsed)

        if next != remainingSeconds {
            remainingSeconds = next
        }

        if next == 0 {
            completeSession()
        }
    }

    private func closeActiveSegment(at end: Date) {
        guard let activeSegmentStart else { return }
        if end > activeSegmentStart {
            activeSegments.append(FocusSegment(start: activeSegmentStart, end: end))
        }
        self.activeSegmentStart = nil
    }

    private func ensureCategory(named rawName: String) -> UUID {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = categories.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing.id
        }

        let now = Date()
        let created = Category(id: UUID(), name: name, createdAt: now, updatedAt: now)
        categories.append(created)
        categories = Self.sortCategories(categories)

        persistence.saveCategories(categories)
        return created.id
    }

    private func saveSettings() {
        persistence.saveSettings(settings)
    }

    private func refreshWhiteNoisePlayback() {
        let shouldPlay = isRunning && settings.whiteNoiseEnabled
        soundService.updateWhiteNoise(enabled: shouldPlay, track: settings.whiteNoiseTrack)
    }

    private func syncConfiguredMinutesWithSelectedCategory() {
        if selectedCategoryID == breakCategoryID {
            configuredMinutes = Self.clampBreakMinutes(settings.breakMinutes)
        } else {
            configuredMinutes = Self.clampMinutes(settings.defaultMinutes)
        }
        remainingSeconds = configuredMinutes * 60
    }

    private func clampedMinutes(for categoryID: UUID?, value: Int) -> Int {
        if categoryID == breakCategoryID {
            return Self.clampBreakMinutes(value)
        }
        return Self.clampMinutes(value)
    }

    private func filteredSessionsForRange() -> [FocusSession] {
        let (start, end) = rangeBoundary(for: selectedStatsRange)

        return sessions.filter { session in
            guard session.endedAt >= start && session.endedAt < end else { return false }
            guard let selectedStatsCategoryID else { return true }
            return session.categoryId == selectedStatsCategoryID
        }
    }

    private func sessionsFilteredByCategory() -> [FocusSession] {
        sessions.filter { session in
            guard let selectedStatsCategoryID else { return true }
            return session.categoryId == selectedStatsCategoryID
        }
    }

    private func secondsForSessionsEnded(in start: Date, end: Date, sessions: [FocusSession]) -> Int {
        sessions
            .filter { $0.endedAt >= start && $0.endedAt < end }
            .reduce(0) { $0 + $1.durationSec }
    }

    private func dayHourlyBarData() -> [StatsBarDatum] {
        let calendar = Calendar.current
        let daySessions = filteredSessionsForRange()
        let dayStart = calendar.startOfDay(for: Date())
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart

        var result: [StatsBarDatum] = []

        for hour in 0..<24 {
            guard let slotStart = calendar.date(byAdding: .hour, value: hour, to: dayStart),
                  let slotEnd = calendar.date(byAdding: .hour, value: 1, to: slotStart) else {
                continue
            }

            var seconds = 0
            for session in daySessions {
                for segment in session.segments {
                    let overlapStart = maxDate(slotStart, maxDate(segment.start, dayStart))
                    let overlapEnd = minDate(slotEnd, minDate(segment.end, dayEnd))
                    if overlapEnd > overlapStart {
                        seconds += Int(overlapEnd.timeIntervalSince(overlapStart))
                    }
                }
            }

            result.append(
                StatsBarDatum(order: hour, label: String(format: "%02d", hour), seconds: seconds)
            )
        }

        return result
    }

    private func weekWeekdayBarData() -> [StatsBarDatum] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let source = sessionsFilteredByCategory()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "E"

        var result: [StatsBarDatum] = []

        for index in 0..<7 {
            let offset = index - 6
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: todayStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }

            let seconds = secondsForSessionsEnded(in: dayStart, end: dayEnd, sessions: source)
            result.append(
                StatsBarDatum(order: index, label: formatter.string(from: dayStart), seconds: seconds)
            )
        }

        return result
    }

    private func monthDailyBarData() -> [StatsBarDatum] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
        let source = sessionsFilteredByCategory()
        let dayCount = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30

        var result: [StatsBarDatum] = []

        for day in 1...dayCount {
            guard let dayStart = calendar.date(byAdding: .day, value: day - 1, to: monthStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                continue
            }

            let seconds = secondsForSessionsEnded(in: dayStart, end: dayEnd, sessions: source)
            result.append(StatsBarDatum(order: day, label: "\(day)", seconds: seconds))
        }

        return result
    }

    private func rollingMonthlyBarData(monthCount: Int) -> [StatsBarDatum] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart
        let source = sessionsFilteredByCategory()

        var result: [StatsBarDatum] = []

        for index in 0..<monthCount {
            let offset = index - (monthCount - 1)
            guard let monthStart = calendar.date(byAdding: .month, value: offset, to: currentMonthStart),
                  let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
                continue
            }

            let seconds = secondsForSessionsEnded(in: monthStart, end: monthEnd, sessions: source)
            let month = calendar.component(.month, from: monthStart)
            result.append(StatsBarDatum(order: index, label: "\(month)월", seconds: seconds))
        }

        return result
    }

    private func rangeBoundary(for range: StatsRange) -> (Date, Date) {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: todayStart)) ?? todayStart

        switch range {
        case .day:
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
            return (todayStart, end)
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: todayStart) ?? todayStart
            let end = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? todayStart
            return (start, end)
        case .month:
            let end = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? currentMonthStart
            return (currentMonthStart, end)
        case .sixMonths:
            let start = calendar.date(byAdding: .month, value: -5, to: currentMonthStart) ?? currentMonthStart
            let end = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? currentMonthStart
            return (start, end)
        case .year:
            let start = calendar.date(byAdding: .month, value: -11, to: currentMonthStart) ?? currentMonthStart
            let end = calendar.date(byAdding: .month, value: 1, to: currentMonthStart) ?? currentMonthStart
            return (start, end)
        }
    }

    private static func clampMinutes(_ value: Int) -> Int {
        max(1, min(60, value))
    }

    private static func clampBreakMinutes(_ value: Int) -> Int {
        max(1, min(60, value))
    }

    private static func isFixedCategoryName(_ name: String) -> Bool {
        name.caseInsensitiveCompare(studyCategoryName) == .orderedSame
            || name.caseInsensitiveCompare(breakCategoryName) == .orderedSame
    }

    private static func categoryPriority(_ name: String) -> Int {
        if name.caseInsensitiveCompare(breakCategoryName) == .orderedSame { return 0 }
        if name.caseInsensitiveCompare(studyCategoryName) == .orderedSame { return 1 }
        return 2
    }

    private static func sortCategories(_ categories: [Category]) -> [Category] {
        categories.sorted { lhs, rhs in
            let lp = categoryPriority(lhs.name)
            let rp = categoryPriority(rhs.name)
            if lp != rp { return lp < rp }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private static func ensureRequiredCategories(in categories: [Category]) -> [Category] {
        var result = categories
        let now = Date()

        if !result.contains(where: { $0.name.caseInsensitiveCompare(studyCategoryName) == .orderedSame }) {
            result.append(
                Category(
                    id: UUID(),
                    name: studyCategoryName,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        if !result.contains(where: { $0.name.caseInsensitiveCompare(breakCategoryName) == .orderedSame }) {
            result.append(
                Category(
                    id: UUID(),
                    name: breakCategoryName,
                    createdAt: now,
                    updatedAt: now
                )
            )
        }

        return result
    }
}

private func maxDate(_ lhs: Date, _ rhs: Date) -> Date {
    lhs > rhs ? lhs : rhs
}

private func minDate(_ lhs: Date, _ rhs: Date) -> Date {
    lhs < rhs ? lhs : rhs
}
