import SwiftUI

/// Общий масштаб/прокрутка для синхронизации двух дорожек.
struct WaveTransform: Equatable {
    var pxPerMs: CGFloat = 0.05
    var scrollX: CGFloat = 0
}

/// Волна звуковой дорожки: отрисовка, выбор сегмента, ручки, указатель.
struct WaveformView: View {
    let store: PcmStore?
    var overlays: [(startMs: Int64, store: PcmStore)] = []
    @Binding var segment: Segment?
    @Binding var playheadMs: Int64
    @Binding var transform: Transform
    var editable: Bool = true
    var waveColor: Color = Color(red: 0.55, green: 0.36, blue: 0.96)
    var segmentColor: Color = Color(red: 0.55, green: 0.36, blue: 0.96).opacity(0.25)
    var overlayColor: Color = Color(red: 0.96, green: 0.62, blue: 0.04)

    typealias Transform = WaveTransform

    @State private var isSelecting = false
    @State private var selStart: Int64 = -1
    @State private var selEnd: Int64 = -1
    @State private var lastScrollDx: CGFloat = 0
    @State private var lastMagnify: CGFloat = 1

    private var durationMs: Int64 { store?.durationMs ?? 0 }

    private func msToX(_ ms: Int64) -> CGFloat { CGFloat(ms) * transform.pxPerMs - transform.scrollX }
    private func xToMs(_ x: CGFloat) -> Int64 {
        guard durationMs > 0 else { return 0 }
        return max(0, min(Int64((x + transform.scrollX) / max(0.001, transform.pxPerMs)), durationMs))
    }

    private func clampScroll(width: CGFloat) {
        let content = CGFloat(durationMs) * transform.pxPerMs
        transform.scrollX = max(0, min(transform.scrollX, max(0, content - width)))
    }

    func fitToWidth(_ width: CGFloat) {
        guard durationMs > 0, width > 0 else { return }
        transform.pxPerMs = width / CGFloat(durationMs)
        transform.scrollX = 0
    }

    var body: some View {
        GeometryReader { geo in
            Canvas(opaque: false, colorMode: .linear, rendersAsynchronously: true) { ctx, size in
                let mid = size.height / 2
                // центральная линия
                var center = Path()
                center.move(to: CGPoint(x: 0, y: mid))
                center.addLine(to: CGPoint(x: size.width, y: mid))
                ctx.stroke(center, with: .color(.white.opacity(0.15)), lineWidth: 1)

                guard let store, durationMs > 0 else { return }
                let startMs = xToMs(0)
                let endMs = xToMs(size.width)
                drawWave(ctx: &ctx, store: store, startMs: startMs, endMs: endMs,
                         mid: mid, height: size.height, color: waveColor, offsetMs: 0)

                // дорожки записей пользователя
                for ov in overlays {
                    let s = max(0, startMs - ov.startMs)
                    let e = min(ov.store.durationMs, endMs - ov.startMs)
                    if e > s {
                        drawWave(ctx: &ctx, store: ov.store, startMs: s, endMs: e,
                                 mid: mid, height: size.height, color: overlayColor,
                                 offsetMs: ov.startMs)
                    }
                }

                // сегмент
                if let seg = segment {
                    let x0 = msToX(seg.startMs)
                    let x1 = msToX(seg.endMs)
                    ctx.fill(Path(CGRect(x: x0, y: 0, width: x1 - x0, height: size.height)),
                             with: .color(segmentColor))
                }

                // создаваемое выделение
                if isSelecting, selEnd > selStart {
                    let x0 = msToX(selStart)
                    let x1 = msToX(selEnd)
                    ctx.fill(Path(CGRect(x: x0, y: 0, width: x1 - x0, height: size.height)),
                             with: .color(.white.opacity(0.25)))
                }

                // указатель
                if playheadMs >= 0 {
                    let x = msToX(playheadMs)
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                    ctx.stroke(p, with: .color(.white), lineWidth: 2)
                }
            }
            .contentShape(Rectangle())
            .gesture(selectionGesture)
            .simultaneousGesture(tapGesture)
            .simultaneousGesture(scrollGesture(width: geo.size.width))
            .simultaneousGesture(zoomGesture(width: geo.size.width))
            // ручки выбранного сегмента
            .overlay {
                if editable, let seg = segment {
                    handle(at: seg.startMs, width: geo.size.width, isStart: true)
                    handle(at: seg.endMs, width: geo.size.width, isStart: false)
                }
            }
        }
        .clipped()
        .background(Color(red: 0.08, green: 0.08, blue: 0.10))
        .cornerRadius(8)
    }

    // MARK: - Отрисовка волны

    private func drawWave(ctx: inout GraphicsContext, store: PcmStore, startMs: Int64, endMs: Int64,
                          mid: CGFloat, height: CGFloat, color: Color, offsetMs: Int64) {
        guard endMs > startMs else { return }
        let buckets = 480
        let (mins, maxs) = store.peaks(startMs: startMs, endMs: endMs, buckets: buckets)
        let amp = height * 0.46
        var path = Path()
        for b in 0..<buckets {
            let ms = offsetMs + startMs + Int64(b) * (endMs - startMs) / Int64(buckets)
            let x = msToX(ms)
            path.move(to: CGPoint(x: x, y: mid - CGFloat(maxs[b]) * amp))
            path.addLine(to: CGPoint(x: x, y: mid - CGFloat(mins[b]) * amp))
        }
        ctx.stroke(path, with: .color(color), lineWidth: 1.5)
    }

    // MARK: - Ручки сегмента

    private func handle(at ms: Int64, width: CGFloat, isStart: Bool) -> some View {
        GeometryReader { geo in
            Circle()
                .fill(Color.white)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle().size(width: 60, height: 100))
                .position(x: msToX(ms), y: geo.size.height / 2)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            guard var seg = segment else { return }
                            let newMs = xToMs(v.location.x)
                            if isStart {
                                seg.startMs = max(0, min(newMs, seg.endMs - 100))
                            } else {
                                seg.endMs = min(durationMs, max(newMs, seg.startMs + 100))
                            }
                            segment = seg
                        }
                )
        }
        .allowsHitTesting(true)
    }

    // MARK: - Жесты

    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .onEnded { v in
                guard !isSelecting else { return }
                let ms = xToMs(v.location.x)
                if editable, let seg = segment, ms >= seg.startMs, ms <= seg.endMs {
                    return // тап внутри сегмента — ничего (ручки отдельно)
                }
                playheadMs = ms
            }
    }

    private var selectionGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.35)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                guard editable, store != nil else { return }
                switch value {
                case .first:
                    break
                case .second(_, let drag?):
                    let ms = xToMs(drag.startLocation.x)
                    if !isSelecting {
                        // не создаём сегмент поверх существующего
                        if let seg = segment, ms >= seg.startMs, ms <= seg.endMs { return }
                        isSelecting = true
                        selStart = ms
                        selEnd = ms
                    }
                    let cur = xToMs(drag.location.x)
                    selStart = min(ms, cur)
                    selEnd = max(ms, cur)
                default:
                    break
                }
            }
            .onEnded { _ in
                if isSelecting, selEnd - selStart >= 100 {
                    segment = Segment(startMs: selStart, endMs: selEnd, recordingFile: nil)
                }
                isSelecting = false
                selStart = -1
                selEnd = -1
            }
    }

    private func scrollGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { v in
                guard !isSelecting else { return }
                let dx = v.translation.width - lastScrollDx
                lastScrollDx = v.translation.width
                transform.scrollX -= dx
                clampScroll(width: width)
            }
            .onEnded { _ in lastScrollDx = 0 }
    }

    private func zoomGesture(width: CGFloat) -> some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                let delta = scale / lastMagnify
                lastMagnify = scale
                let focusMs = xToMs(width / 2)
                transform.pxPerMs = max(0.005, min(5, transform.pxPerMs * delta))
                transform.scrollX = CGFloat(focusMs) * transform.pxPerMs - width / 2
                clampScroll(width: width)
            }
            .onEnded { _ in lastMagnify = 1 }
    }
}
