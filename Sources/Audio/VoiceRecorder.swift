import AVFoundation
import Foundation

/// Запись голоса пользователя в WAV (моно, 16-bit, 22050 Гц).
final class VoiceRecorder: ObservableObject {
    @Published var recording = false

    private var recorder: AVAudioRecorder?

    /// Запрашивает разрешение на микрофон; completion на главном потоке.
    func requestPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission { granted in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func start(to url: URL) -> Bool {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
            try AVAudioSession.sharedInstance().setActive(true)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: PcmStore.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ]
            let r = try AVAudioRecorder(url: url, settings: settings)
            guard r.record() else { return false }
            recorder = r
            recording = true
            return true
        } catch { return false }
    }

    func stop() {
        recorder?.stop()
        recorder = nil
        recording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Длительность файла записи в миллисекундах (по размеру WAV).
    static func durationMs(of url: URL) -> Int64 {
        let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
        let dataBytes = max(0, (size ?? 0) - 44)
        return Int64(dataBytes / 2) * 1000 / Int64(PcmStore.sampleRate)
    }
}
