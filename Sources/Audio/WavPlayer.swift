import AVFoundation
import Foundation

/// Воспроизведение PCM через AVAudioPlayer: сэмплы пишутся во временный WAV и играются системным плеером.
final class WavPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var playing = false

    var onProgress: ((Int64) -> Void)?
    var onFinished: (() -> Void)?

    private var player: AVAudioPlayer?
    private var timer: Timer?
    private let tmpURL = FileManager.default.temporaryDirectory.appendingPathComponent("play.wav")

    func play(samples: [Int16]) throws {
        stop()
        try WavFile.write(samples, to: tmpURL)
        try AVAudioSession.sharedInstance().setCategory(.playback)
        try AVAudioSession.sharedInstance().setActive(true)
        let p = try AVAudioPlayer(contentsOf: tmpURL)
        p.delegate = self
        p.prepareToPlay()
        p.play()
        player = p
        playing = true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            self.onProgress?(Int64(p.currentTime * 1000))
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        player?.stop()
        player = nil
        playing = false
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        stop()
        onFinished?()
    }
}
