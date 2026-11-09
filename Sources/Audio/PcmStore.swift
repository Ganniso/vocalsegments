import Foundation

/// Чтение PCM-файла (моно, 16-bit little endian, 22050 Гц) по диапазонам.
final class PcmStore {
    static let sampleRate = 22050

    let fileURL: URL
    let headerBytes: Int
    let sampleCount: Int
    var durationMs: Int64 { Int64(sampleCount) * 1000 / Int64(Self.sampleRate) }

    /// headerBytes — пропустить заголовок (например, 44 байта у WAV-записи).
    init(fileURL: URL, headerBytes: Int = 0) {
        self.fileURL = fileURL
        self.headerBytes = headerBytes
        let size = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        self.sampleCount = max(0, size - headerBytes) / 2
    }

    private func msToSample(_ ms: Int64) -> Int { Int(ms) * Self.sampleRate / 1000 }

    /// Читает диапазон [startMs, endMs) в массив сэмплов.
    func readRange(startMs: Int64, endMs: Int64) -> [Int16] {
        let s0 = max(0, min(msToSample(startMs), sampleCount))
        let s1 = max(s0, min(msToSample(endMs), sampleCount))
        guard s1 > s0, let h = try? FileHandle(forReadingFrom: fileURL) else { return [] }
        defer { try? h.close() }
        do {
            try h.seek(toOffset: UInt64(s0 * 2 + headerBytes))
            let data = try h.read(upToCount: (s1 - s0) * 2) ?? Data()
            var out = [Int16](repeating: 0, count: data.count / 2)
            _ = out.withUnsafeMutableBytes { ptr in
                data.copyBytes(to: ptr)
            }
            // На little-endian платформах (все iPhone) порядок уже корректный.
            return out
        } catch { return [] }
    }

    /// Мин/макс амплитуды по корзинам для отрисовки волны видимого диапазона.
    func peaks(startMs: Int64, endMs: Int64, buckets: Int) -> (min: [Float], max: [Float]) {
        var minOut = [Float](repeating: 0, count: buckets)
        var maxOut = [Float](repeating: 0, count: buckets)
        let s0 = max(0, min(msToSample(startMs), sampleCount))
        let s1 = max(s0, min(msToSample(endMs), sampleCount))
        guard s1 > s0, buckets > 0, let h = try? FileHandle(forReadingFrom: fileURL) else {
            return (minOut, maxOut)
        }
        defer { try? h.close() }
        do {
            try h.seek(toOffset: UInt64(s0 * 2 + headerBytes))
            let data = try h.read(upToCount: (s1 - s0) * 2) ?? Data()
            let total = data.count / 2
            guard total > 0 else { return (minOut, maxOut) }
            data.withUnsafeBytes { raw in
                let samples = raw.bindMemory(to: Int16.self)
                for i in 0..<total {
                    let v = Float(samples[i]) / 32768.0
                    let b = min(buckets - 1, i * buckets / total)
                    if v < minOut[b] { minOut[b] = v }
                    if v > maxOut[b] { maxOut[b] = v }
                }
            }
        } catch {}
        return (minOut, maxOut)
    }
}
