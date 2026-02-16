import SwiftUI

struct CategoryManagerView: View {
    @ObservedObject var viewModel: PomodoroViewModel
    let onClose: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    @State private var draftCategories: [Category]
    @State private var draftSelectedCategoryID: UUID?

    @State private var newCategoryName: String = ""
    @State private var editingCategoryID: UUID?
    @State private var editingText: String = ""

    init(viewModel: PomodoroViewModel, onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onClose = onClose
        _draftCategories = State(initialValue: viewModel.categories)
        _draftSelectedCategoryID = State(initialValue: viewModel.selectedCategoryID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("카테고리")
                .font(.title2.bold())

            HStack(spacing: 8) {
                TextField("새 카테고리", text: $newCategoryName)
                    .textFieldStyle(.roundedBorder)
                Button("추가") {
                    appendCategory()
                }
                .buttonStyle(.borderedProminent)
            }
            .disabled(!viewModel.canEditCategory)

            List {
                ForEach(draftCategories) { category in
                    HStack(spacing: 8) {
                        if editingCategoryID == category.id {
                            TextField("이름", text: $editingText)
                                .textFieldStyle(.roundedBorder)
                            Button("적용") {
                                applyEditing(for: category.id)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Text(category.name)
                            if draftSelectedCategoryID == category.id {
                                Text("선택됨")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !isFixedCategory(category) {
                                Button {
                                    editingCategoryID = category.id
                                    editingText = category.name
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.borderless)

                                Button(role: .destructive) {
                                    draftCategories.removeAll { $0.id == category.id }
                                    if draftSelectedCategoryID == category.id {
                                        draftSelectedCategoryID = nil
                                    }
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            } else {
                                Text("고정")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                            Button("선택") {
                                draftSelectedCategoryID = category.id
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .disabled(!viewModel.canEditCategory)
                }
            }
            .frame(maxHeight: .infinity)

            HStack {
                Spacer()
                Button("닫기") {
                    closeView()
                }
                .buttonStyle(.bordered)

                Button("저장") {
                    viewModel.applyCategoryDraft(categories: draftCategories, selectedCategoryID: draftSelectedCategoryID)
                    closeView()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canEditCategory)
            }
        }
        .font(.body)
        .padding(16)
        .onAppear {
            syncDraftFromViewModel()
        }
    }

    private func closeView() {
        if let onClose {
            onClose()
        } else {
            dismiss()
        }
    }

    private func appendCategory() {
        let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let existing = draftCategories.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            draftSelectedCategoryID = existing.id
            newCategoryName = ""
            return
        }

        let now = Date()
        let category = Category(id: UUID(), name: trimmed, createdAt: now, updatedAt: now)
        draftCategories.append(category)
        draftCategories = sortDraftCategories(draftCategories)
        draftSelectedCategoryID = category.id
        newCategoryName = ""
    }

    private func applyEditing(for id: UUID) {
        let trimmed = editingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if draftCategories.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return
        }

        guard let index = draftCategories.firstIndex(where: { $0.id == id }) else { return }
        draftCategories[index].name = trimmed
        draftCategories[index].updatedAt = Date()
        draftCategories = sortDraftCategories(draftCategories)

        editingCategoryID = nil
        editingText = ""
    }

    private func syncDraftFromViewModel() {
        draftCategories = sortDraftCategories(viewModel.categories)
        draftSelectedCategoryID = viewModel.selectedCategoryID
        newCategoryName = ""
        editingCategoryID = nil
        editingText = ""
    }

    private func isFixedCategory(_ category: Category) -> Bool {
        viewModel.isFixedCategory(category)
    }

    private func sortDraftCategories(_ categories: [Category]) -> [Category] {
        categories.sorted { lhs, rhs in
            let lp = categoryPriority(lhs.name)
            let rp = categoryPriority(rhs.name)
            if lp != rp { return lp < rp }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func categoryPriority(_ name: String) -> Int {
        if name.caseInsensitiveCompare("휴식") == .orderedSame { return 0 }
        if name.caseInsensitiveCompare("공부하기") == .orderedSame { return 1 }
        return 2
    }
}
