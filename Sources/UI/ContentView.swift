import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var player = WavPlayer()
    @StateObject private var recorder = VoiceRecorder()

    @State private var store: PcmStore?
    @State private var recStore: PcmStore?
    @State private var project: Project?
    @State private var segment: Segment?
    @State private var playheadMs: Int64 = -1
    @State private var transform = WaveformView.Transform()

    @State private var showingPicker = false
    @State private var showingProjects = false
    @State private var decoding = false
    @State private var errorMessage: String?
    @State private var playingMode: Mode = .none

    private let projectStore = ProjectStore()

    enum Mode { case none, file, segment, recording, mix }

    var body: some View {
        VStack(spacing: 10) {
            // Верхняя панель
            HStack {
                Button { showingPicker = true } label: {
                    Label("Файл", systemImage: "doc")
                }
                .buttonStyle(.borderedProminent)
                Button { showingProjects = true } label: {
                    Image(systemName: "folder")
                }
                .buttonStyle(.bordered)
                Text(project?.name ?? "Файл не выбран")
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer()
                Button { zoom(1 / 1.4) } label: { Image(systemName: "minus.magnifyingglass") }
                    .buttonStyle(.bordered)
                Button { zoom(1.4) } label: { Image(systemName: "plus.magnifyingglass") }
                    .buttonStyle(.bordered)
            }

            if decoding { ProgressView("Декодирование…") }

            // Дорожки: верхняя (оригинал) крупнее, нижняя (моя запись) меньше
            GeometryReader { geo in
                VStack(spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Оригинал").font(.caption).foregroundStyle(Color(red: 0.55, green: 0.36, blue: 0.96))
                        ZStack {
                            WaveformView(store: store, segment: $segment, playheadMs: $playheadMs,
                                         transform: $transform, editable: true)
                            if store == nil && !decoding {
                                Text("Откройте аудио или видео файл.\nТап — указатель, «Трек» — слушать.\nДолгое нажатие и протягивание — выделить сегмент.")
                                    .multilineTextAlignment(.center)
                                    .foregroundStyle(.secondary)
                                    .font(.footnote)
                            }
                        }
                    }
                    .frame(height: geo.size.height * 0.6)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Моя запись").font(.caption).foregroundStyle(Color(red: 0.96, green: 0.62, blue: 0.04))
                        WaveformView(store: store,
                                     overlays: recordingOverlays(),
                                     segment: $segment, playheadMs: $playheadMs,
                                     transform: $transform, editable: false,
                                     waveColor: Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.35))
                    }
                    .frame(height: geo.size.height * 0.38)
                }
            }
            .frame(maxHeight: .infinity)

            // Инфо о сегменте
            Text(segmentInfo())
                .font(.footnote)
                .foregroundStyle(.secondary)

            // Кнопки транспорта
            HStack {
                transportButton(title: playingMode == .file ? "Стоп" : "Трек",
                                systemImage: playingMode == .file ? "stop.fill" : "play.fill",
                                enabled: store != nil) { togglePlayFile() }
                transportButton(title: playingMode == .segment ? "Стоп" : "Сегмент",
                                systemImage: playingMode == .segment ? "stop.fill" : "play.fill",
                                enabled: segment != nil) { togglePlay(.segment) }
                transportButton(title: recorder.recording ? "Стоп запись" : "Запись",
                                systemImage: recorder.recording ? "stop.fill" : "mic.fill",
                                enabled: segment != nil, prominent: true,
                                tint: recorder.recording ? .red : nil) { toggleRecording() }
            }
            HStack {
                transportButton(title: playingMode == .recording ? "Стоп" : "Моя запись",
                                systemImage: playingMode == .recording ? "stop.fill" : "play.fill",
                                enabled: recStore != nil) { togglePlay(.recording) }
                transportButton(title: playingMode == .mix ? "Стоп" : "Вместе",
                                systemImage: playingMode == .mix ? "stop.fill" : "play.fill",
                                enabled: recStore != nil) { togglePlay(.mix) }
                transportButton(title: "Сброс", systemImage: "xmark",
                                enabled: segment != nil) { clearSegment() }
            }
        }
        .padding()
        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingPicker) {
            DocumentPicker { url in openFile(url) }
        }
        .sheet(isPresented: $showingProjects) {
            ProjectsView(store: projectStore) { openProject($0) }
        }
        .alert("Ошибка", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        ), actions: {
            Button("OK") { errorMessage = nil }
        }, message: { Text(errorMessage ?? "") })
        .onAppear {
            player.onFinished = { playingMode = .none }
            restoreLastProject()
        }
        .onChange(of: segment) { _ in saveProject() }
    }

    // MARK: - Вспомогательное

    @ViewBuilder
    private func transportButton(title: String, systemImage: String, enabled: Bool,
                                 prominent: Bool = false, tint: Color? = nil,
                                 action: @escaping () -> Void) -> some View {
        if prominent {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
            .disabled(!enabled)
        } else {
            Button(action: action) {
                Label(title, systemImage: systemImage)
                    .font(.caption)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(tint)
            .disabled(!enabled)
        }
    }

    private func zoom(_ factor: CGFloat) {
        transform.pxPerMs = max(0.005, min(5, transform.pxPerMs * factor))
    }

    private func segmentInfo() -> String {
        guard let seg = segment else {
            return "Сегмент не выделен — долгое нажатие на волне и протягивание"
        }
        let base = "Сегмент: \(fmt(seg.startMs)) – \(fmt(seg.endMs))"
        return recStore != nil ? base + " · есть запись" : base
    }

    private func fmt(_ ms: Int64) -> String {
        let s = ms / 1000
        return String(format: "%d:%02d.%d", s / 60, s % 60, ms % 1000 / 100)
    }

    private func recordingOverlays() -> [(startMs: Int64, store: PcmStore)] {
        guard let seg = segment, let rec = recStore else { return [] }
        return [(seg.startMs, rec)]
    }

    // MARK: - Файл и проект

    private func openFile(_ url: URL) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard let bookmark = try? url.bookmarkData(options: .minimalBookmark) else {
            errorMessage = "Не удалось открыть файл"
            return
        }
        let name = url.lastPathComponent
        // Проект с таким файлом уже есть? Открываем его.
        if let existing = projectStore.list().first(where: { $0.name == name }) {
            openProject(existing)
            return
        }
        let newProject = Project(id: "p\(Int(Date().timeIntervalSince1970))",
                                 name: name, bookmarkData: bookmark,
                                 updatedAt: Date(), segment: nil)
        decodeAndOpen(project: newProject, sourceURL: url)
    }

    private func openProject(_ p: Project) {
        guard let url = projectStore.resolveURL(p) else {
            errorMessage = "Не удалось найти исходный файл проекта"
            return
        }
        decodeAndOpen(project: p, sourceURL: url)
    }

    private func decodeAndOpen(project p: Project, sourceURL: URL) {
        decoding = true
        let cacheURL = FileManager.default.cachesDirectoryURL()
            .appendingPathComponent("decoded_\(p.id).pcm")
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                if !FileManager.default.fileExists(atPath: cacheURL.path) {
                    try AudioDecoder.decode(assetURL: sourceURL, to: cacheURL)
                }
                let pcm = PcmStore(fileURL: cacheURL)
                guard pcm.sampleCount > 0 else {
                    throw NSError(domain: "VocalSegments", code: 4,
                                  userInfo: [NSLocalizedDescriptionKey: "Пустая аудиодорожка"])
                }
                DispatchQueue.main.async {
                    decoding = false
                    player.stop()
                    playingMode = .none
                    store = pcm
                    project = p
                    segment = p.segment
                    playheadMs = -1
                    loadRecording()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let w = UIApplication.shared.connectedScenes
                            .compactMap({ ($0 as? UIWindowScene)?.keyWindow }).first {
                            // вписываем волну в ширину
                            transform.pxPerMs = (w.frame.width - 32) / CGFloat(max(1, pcm.durationMs))
                            transform.scrollX = 0
                        }
                    }
                    saveProject()
                    projectStore.setLastProjectId(p.id)
                }
            } catch {
                DispatchQueue.main.async {
                    decoding = false
                    errorMessage = "Не удалось прочитать файл: \(error.localizedDescription)"
                }
            }
        }
    }

    private func loadRecording() {
        guard let p = project, let seg = p.segment, seg.recordingFile != nil else {
            recStore = nil
            return
        }
        let url = projectStore.recordingURL(projectId: p.id)
        if FileManager.default.fileExists(atPath: url.path) {
            recStore = PcmStore(fileURL: url, headerBytes: 44)
        } else {
            recStore = nil
            segment?.recordingFile = nil
        }
    }

    private func saveProject() {
        guard var p = project else { return }
        p.segment = segment
        p.updatedAt = Date()
        project = p
        projectStore.save(p)
    }

    private func restoreLastProject() {
        guard let id = projectStore.lastProjectId(),
              let p = projectStore.list().first(where: { $0.id == id }) else { return }
        openProject(p)
    }

    // MARK: - Воспроизведение

    private func togglePlayFile() {
        guard let pcm = store else { return }
        if playingMode == .file { player.stop(); playingMode = .none; return }
        player.stop()
        let from = max(0, min(playheadMs < 0 ? 0 : playheadMs, pcm.durationMs))
        playingMode = .file
        let data = pcm.readRange(startMs: from, endMs: pcm.durationMs)
        startPlayer(samples: data, base: from)
    }

    private func togglePlay(_ mode: Mode) {
        guard let pcm = store, let seg = segment else { return }
        if playingMode == mode { player.stop(); playingMode = .none; return }
        player.stop()
        playingMode = mode
        let samples: [Int16]
        switch mode {
        case .segment:
            samples = pcm.readRange(startMs: seg.startMs, endMs: seg.endMs)
        case .recording:
            guard let rec = recStore else { return }
            samples = rec.readRange(startMs: 0, endMs: rec.durationMs)
        case .mix:
            guard let rec = recStore else { return }
            samples = WavFile.mix(pcm.readRange(startMs: seg.startMs, endMs: seg.endMs),
                                  rec.readRange(startMs: 0, endMs: rec.durationMs))
        default:
            return
        }
        startPlayer(samples: samples, base: seg.startMs)
    }

    private func startPlayer(samples: [Int16], base: Int64) {
        player.onProgress = { pos in playheadMs = base + pos }
        do {
            try player.play(samples: samples)
        } catch {
            playingMode = .none
            errorMessage = "Ошибка воспроизведения: \(error.localizedDescription)"
        }
    }

    // MARK: - Запись

    private func toggleRecording() {
        guard let p = project, segment != nil else { return }
        if recorder.recording {
            recorder.stop()
            let url = projectStore.recordingURL(projectId: p.id)
            if VoiceRecorder.durationMs(of: url) > 50 {
                segment?.recordingFile = url.lastPathComponent
                recStore = PcmStore(fileURL: url, headerBytes: 44)
            } else {
                try? FileManager.default.removeItem(at: url)
                segment?.recordingFile = nil
                recStore = nil
            }
            saveProject()
            return
        }
        recorder.requestPermission { granted in
            guard granted else {
                errorMessage = "Для записи голоса нужно разрешение на микрофон (Настройки → VocalSegments)"
                return
            }
            player.stop()
            playingMode = .none
            if !recorder.start(to: projectStore.recordingURL(projectId: p.id)) {
                errorMessage = "Не удалось начать запись"
            }
        }
    }

    private func clearSegment() {
        if recorder.recording { recorder.stop() }
        if let p = project {
            try? FileManager.default.removeItem(at: projectStore.recordingURL(projectId: p.id))
        }
        segment = nil
        recStore = nil
        saveProject()
    }
}

private extension FileManager {
    func cachesDirectoryURL() -> URL {
        urls(for: .cachesDirectory, in: .userDomainMask)[0]
    }
}
