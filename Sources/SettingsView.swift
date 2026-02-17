import SwiftUI
import AppKit

struct SettingsView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var draftTheme: AppTheme
    @State private var draftNotificationSound: NotificationSoundOption
    @State private var draftBreakMinutes: Int
    @State private var draftBreakCycleEnabled: Bool
    @State private var draftWhiteNoiseEnabled: Bool
    @State private var draftWhiteNoiseTrack: WhiteNoiseTrack
    @State private var isHydratingDrafts: Bool = false

    init(viewModel: PomodoroViewModel, onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onClose = onClose
        _draftTheme = State(initialValue: viewModel.settings.theme)
        _draftNotificationSound = State(initialValue: viewModel.settings.notificationSound)
        _draftBreakMinutes = State(initialValue: viewModel.settings.breakMinutes)
        _draftBreakCycleEnabled = State(initialValue: viewModel.settings.breakCycleEnabled)
        _draftWhiteNoiseEnabled = State(initialValue: viewModel.settings.whiteNoiseEnabled)
        _draftWhiteNoiseTrack = State(initialValue: viewModel.settings.whiteNoiseTrack)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("설정")
                        .font(.title2.bold())

                    breakSection
                    soundSection
                    themeSection
                }
                .padding(20)
            }

            Divider()

            HStack {
                Button("앱 종료") {
                    terminateApp()
                }
                .buttonStyle(.bordered)

                Spacer()
                Button("닫기") {
                    closeView()
                }
                .buttonStyle(.bordered)

                Button("저장") {
                    viewModel.applySettingsDraft(
                        theme: draftTheme,
                        notificationSound: draftNotificationSound,
                        breakMinutes: draftBreakMinutes,
                        breakCycleEnabled: draftBreakCycleEnabled,
                        whiteNoiseEnabled: draftWhiteNoiseEnabled,
                        whiteNoiseTrack: draftWhiteNoiseTrack
                    )
                    closeView()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canEditSettings)
            }
            .padding(14)
        }
        .font(.body)
        .onAppear {
            syncDraftFromSettings()
        }
        .onChange(of: draftNotificationSound) { next in
            guard !isHydratingDrafts else { return }
            viewModel.previewNotificationSound(next)
        }
        .onChange(of: draftWhiteNoiseEnabled) { enabled in
            guard !isHydratingDrafts else { return }
            if enabled {
                viewModel.previewBGM(draftWhiteNoiseTrack)
            } else {
                viewModel.stopBGMPreview()
            }
        }
        .onChange(of: draftWhiteNoiseTrack) { next in
            guard !isHydratingDrafts else { return }
            guard draftWhiteNoiseEnabled else { return }
            viewModel.previewBGM(next)
        }
        .onChange(of: draftBreakMinutes) { next in
            let clamped = max(1, min(60, next))
            if clamped != next {
                draftBreakMinutes = clamped
            }
        }
    }

    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("색상 테마")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 118), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(AppTheme.allCases) { theme in
                    Button {
                        draftTheme = theme
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(theme.color)
                                .frame(width: 14, height: 14)
                            Text(theme.label)
                                .font(.body)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(draftTheme == theme ? theme.selectionStrokeColor : Color.secondary.opacity(0.25), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .disabled(!viewModel.canEditSettings)
    }

    private var soundSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("사운드")
                .font(.headline)

            soundRow(title: "알림음") {
                Picker("", selection: $draftNotificationSound) {
                    ForEach(NotificationSoundOption.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .labelsHidden()
            }

            soundRow(title: "BGM") {
                Picker("", selection: Binding(
                    get: {
                        if !draftWhiteNoiseEnabled { return BGMSelection.none }
                        return draftWhiteNoiseTrack == .rain ? .rain : .fire
                    },
                    set: { next in
                        switch next {
                        case .none:
                            draftWhiteNoiseEnabled = false
                        case .rain:
                            draftWhiteNoiseEnabled = true
                            draftWhiteNoiseTrack = .rain
                        case .fire:
                            draftWhiteNoiseEnabled = true
                            draftWhiteNoiseTrack = .fire
                        }
                    }
                )) {
                    ForEach(BGMSelection.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                .labelsHidden()
            }
        }
        .disabled(!viewModel.canEditSettings)
    }

    private var breakSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("휴식 시간")
                .font(.headline)

            Toggle("휴식 시간 주기", isOn: $draftBreakCycleEnabled)
                .toggleStyle(.switch)

            Text("켜져 있으면 업무가 끝난 뒤 휴식 카테고리로 전환됩니다.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Text("분")
                    .font(.body)
                    .frame(width: 48, alignment: .leading)

                TextField("", value: $draftBreakMinutes, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 90)

                Text("(1~60)")
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)
            }
        }
        .disabled(!viewModel.canEditSettings)
    }

    private func soundRow<Content: View>(title: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.body)
                .frame(width: 48, alignment: .leading)

            control()
                .frame(width: 230, alignment: .leading)

            Spacer(minLength: 0)
        }
        .font(.body)
    }

    private func closeView() {
        viewModel.stopBGMPreview()
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func terminateApp() {
        viewModel.stopBGMPreview()
        NSApplication.shared.terminate(nil)
    }

    private func syncDraftFromSettings() {
        isHydratingDrafts = true
        let current = viewModel.settings
        draftTheme = current.theme
        draftNotificationSound = current.notificationSound
        draftBreakMinutes = current.breakMinutes
        draftBreakCycleEnabled = current.breakCycleEnabled
        draftWhiteNoiseEnabled = current.whiteNoiseEnabled
        draftWhiteNoiseTrack = current.whiteNoiseTrack
        viewModel.stopBGMPreview()
        DispatchQueue.main.async {
            isHydratingDrafts = false
        }
    }

}

private enum BGMSelection: String, CaseIterable, Identifiable {
    case none
    case rain
    case fire

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "없음"
        case .rain: return "비 소리"
        case .fire: return "장작 타는 소리"
        }
    }
}
