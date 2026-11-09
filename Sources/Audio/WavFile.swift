import Foundation

enum WavFile {
    /// Пишет моно WAV 16-bit little endian.
    static func write(_ samples: [Int16], to url: URL, sampleRate: Int = PcmStore.sampleRate) throws {
        let dataLen = UInt32(samples.count * 2)
        var d = Data()
        d.append("RIFF".data(using: .ascii)!)
        d.append(UInt32(36 + dataLen).littleEndianData)
        d.append("WAVE".data(using: .ascii)!)
        d.append("fmt ".data(using: .ascii)!)
        d.append(UInt32(16).littleEndianData)
        d.append(UInt16(1).littleEndianData)          // PCM
        d.append(UInt16(1).littleEndianData)          // моно
        d.append(UInt32(sampleRate).littleEndianData)
        d.append(UInt32(sampleRate * 2).littleEndianData)
        d.append(UInt16(2).littleEndianData)          // байт на сэмпл
        d.append(UInt16(16).littleEndianData)         // бит
        d.append("data".data(using: .ascii)!)
        d.append(dataLen.littleEndianData)
        samples.withUnsafeBytes { d.append(contentsOf: $0) }
        try d.write(to: url)
    }

    /// Суммирует оригинал и запись голоса (с ограничением амплитуды).
    static func mix(_ a: [Int16], _ b: [Int16]) -> [Int16] {
        let n = max(a.count, b.count)
        var out = [Int16](repeating: 0, count: n)
        for i in 0..<n {
            let va = i < a.count ? Int(a[i]) : 0
            let vb = i < b.count ? Int(b[i]) : 0
            out[i] = Int16(max(-32768, min(32767, va + vb)))
        }
        return out
    }
}

private extension FixedWidthInteger {
    var littleEndianData: Data {
        withUnsafeBytes(of: littleEndian) { Data($0) }
    }
}
