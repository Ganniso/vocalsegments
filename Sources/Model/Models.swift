import Foundation

/// Один выбранный пользователем фрагмент композиции.
struct Segment: Codable, Equatable {
    var startMs: Int64
    var endMs: Int64
    /// Имя файла записи голоса (в папке проекта), nil — записи нет.
    var recordingFile: String?

    var durationMs: Int64 { endMs - startMs }
}

/// Сохранённый проект: исходный файл (security-scoped bookmark) + сегмент + запись.
struct Project: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var bookmarkData: Data
    var updatedAt: Date
    var segment: Segment?
}
