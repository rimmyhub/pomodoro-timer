import SwiftUI
import Charts

struct StatsView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    init(viewModel: PomodoroViewModel, onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("학습 통계")
                        .font(.title2.bold())

                    categorySection
                    rangeSection
                    summarySection
                    chartSection
                }
                .padding(20)
            }

            Divider()

            HStack {
                Spacer()
                Button("닫기") {
                    closeView()
                }
                .buttonStyle(.bordered)
            }
            .padding(14)
        }
        .font(.body)
    }

    private var rangeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("기간")
                .font(.headline)

            Picker("기간", selection: $viewModel.selectedStatsRange) {
                ForEach(StatsRange.allCases) { range in
                    Text(range.label).tag(range)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("카테고리")
                .font(.headline)

            statsInputRow(title: "선택") {
                Picker("", selection: $viewModel.selectedStatsCategoryID) {
                    ForEach(viewModel.statsCategoryOptions) { option in
                        Text(option.label).tag(option.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var summarySection: some View {
        let summary = viewModel.statsSummary()
        return HStack(spacing: 16) {
            Label("집중 횟수: \(summary.focusCount)", systemImage: "bolt.fill")
            Label("합계 시간: \(formatDuration(summary.totalSeconds))", systemImage: "clock")
        }
        .font(.callout)
        .foregroundStyle(.secondary)
    }

    private var chartSection: some View {
        let data = viewModel.statsBarData().sorted { $0.order < $1.order }

        return VStack(alignment: .leading, spacing: 8) {
            Chart(data) { item in
                BarMark(
                    x: .value("구간", item.label),
                    y: .value("초", item.seconds)
                )
                .foregroundStyle(viewModel.settings.theme.color)
            }
            .frame(height: 220)
        }
    }

    private func closeView() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func statsInputRow<Content: View>(title: String, @ViewBuilder control: () -> Content) -> some View {
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
}
