import SwiftUI

/// Список сохранённых проектов.
struct ProjectsView: View {
    let store: ProjectStore
    let onOpen: (Project) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var projects: [Project] = []

    var body: some View {
        NavigationStack {
            Group {
                if projects.isEmpty {
                    Text("Сохранённых проектов пока нет")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(projects) { p in
                            VStack(alignment: .leading) {
                                Text(p.name).lineLimit(1)
                                Text(p.updatedAt.formatted(date: .numeric, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                dismiss()
                                onOpen(p)
                            }
                        }
                        .onDelete { idx in
                            idx.forEach { store.delete(projects[$0]) }
                            projects.remove(atOffsets: idx)
                        }
                    }
                }
            }
            .navigationTitle("Проекты")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .onAppear { projects = store.list() }
    }
}
