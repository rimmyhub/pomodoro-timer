import SwiftUI
import AppKit

struct MainTimerView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                HStack {
                    Button {
                        viewModel.resetTimer()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("초기화")

                    Button {
                        openManagedWindow(id: "category-manager")
                    } label: {
                        Image(systemName: "tag")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("카테고리")
                    .disabled(!viewModel.canEditCategory)

                    Spacer()

                    Button {
                        openManagedWindow(id: "stats")
                    } label: {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("통계")

                    Button {
                        openManagedWindow(id: "settings")
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .help("설정")
                    .disabled(!viewModel.canEditSettings)
                }
                .frame(height: 18)
                .padding(.bottom, 0)
                .frame(maxWidth: .infinity)

                VStack(spacing: 11) {
                    if let selectedCategoryName = viewModel.selectedCategoryName {
                        Text(selectedCategoryName)
                            .font(.body.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(viewModel.settings.theme.color.opacity(0.14))
                            .clipShape(Capsule())
                    }

                    CircularDialView(
                        progress: viewModel.dialProgress,
                        color: viewModel.settings.theme.color,
                        isLocked: viewModel.isSessionActive,
                        onChangedMinutes: { viewModel.updateMinutesFromDial($0) }
                    )
                    .frame(width: 212, height: 212)
                    .padding(.top, 4)

                    Text(viewModel.timerText)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .padding(.top, 4)

                    Button {
                        viewModel.playPauseTapped()
                    } label: {
                        Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 22, weight: .bold))
                            .frame(width: 54, height: 54)
                            .background(viewModel.settings.theme.color)
                            .foregroundStyle(viewModel.settings.theme.controlForegroundColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .font(.body)
            .padding(.horizontal, 18)
            .padding(.top, 0)
            .padding(.bottom, 8)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .alert("카테고리를 먼저 선택해 주세요", isPresented: $viewModel.showCategoryRequiredAlert) {
            Button("카테고리 열기") {
                openManagedWindow(id: "category-manager")
            }
            Button("확인", role: .cancel) { }
        }
    }

    private func openManagedWindow(id: String) {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: id)
    }
}
