import AVFoundation
import Foundation

/// Декодирует аудиодорожку из аудио- или видеофайла в моно PCM 16-bit, 22050 Гц.
enum AudioDecoder {

    static func decode(assetURL: URL, to outURL: URL) throws {
        let accessing = assetURL.startAccessingSecurityScopedResource()
        defer { if accessing { assetURL.stopAccessingSecurityScopedResource() } }

        let asset = AVURLAsset(url: assetURL)
        guard let track = try? asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "VocalSegments", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "В файле нет аудиодорожки"])
        }
        let reader = try AVAssetReader(asset: asset)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: PcmStore.sampleRate,
        ]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? NSError(domain: "VocalSegments", code: 2)
        }

        FileManager.default.createFile(atPath: outURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: outURL)
        defer { try? handle.close() }
        while reader.status == .reading {
            autoreleasepool {
                if let buffer = output.copyNextSampleBuffer(),
                   let block = CMSampleBufferGetDataBuffer(buffer) {
                    var length = 0
                    var pointer: UnsafeMutablePointer<Int8>?
                    CMBlockBufferGetDataPointer(block, atOffset: 0, lengthAtOffsetOut: nil,
                                                totalLengthOut: &length, dataPointerOut: &pointer)
                    if let p = pointer, length > 0 {
                        let data = Data(bytes: p, count: length)
                        try? handle.write(contentsOf: data)
                    }
                }
            }
        }
        if reader.status == .failed {
            throw reader.error ?? NSError(domain: "VocalSegments", code: 3)
        }
    }
}
