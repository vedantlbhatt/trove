import SwiftUI
import UIKit

struct IslandCatchView: View {
    let sharedImage: UIImage
    let screenBounds: CGRect
    var onDismiss: () -> Void
    var onSaveData: (Data) -> Void

    private static let islandTopOnScreen: CGFloat = 11

    @State private var islandWidth: CGFloat = 110
    @State private var islandHeight: CGFloat = 36
    @State private var islandCornerRadius: CGFloat = 18
    @State private var islandGlowOpacity: Double = 0.0

    @State private var flyPosition: CGPoint = .zero
    @State private var mediaScale: CGFloat = 0.55
    @State private var mediaOpacity: Double = 1.0
    @State private var didStartFlight = false
    @State private var showFlyingImage = false

    #if !targetEnvironment(simulator)
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .rigid)
    #endif

    var body: some View {
        GeometryReader { geometry in
            let globalFrame = geometry.frame(in: .global)
            let islandCenter = computeIslandCenter(in: globalFrame, viewSize: geometry.size)

            ZStack {
                Color.clear.ignoresSafeArea()

                islandPill
                    .position(islandCenter)
                    .zIndex(100)

                if showFlyingImage, mediaOpacity > 0 {
                    Image(uiImage: sharedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 16, x: 0, y: 8)
                        .scaleEffect(mediaScale)
                        .opacity(mediaOpacity)
                        .position(flyPosition)
                        .zIndex(50)
                }
            }
            .ignoresSafeArea(.all)
            .onAppear {
                beginFlightWhenLaidOut(globalFrame: globalFrame, viewSize: geometry.size, islandCenter: islandCenter)
            }
            .onChange(of: geometry.size) { _, newSize in
                guard newSize.width > 1, newSize.height > 1 else { return }
                beginFlightWhenLaidOut(
                    globalFrame: geometry.frame(in: .global),
                    viewSize: newSize,
                    islandCenter: computeIslandCenter(in: geometry.frame(in: .global), viewSize: newSize)
                )
            }
        }
        .ignoresSafeArea(.all)
    }

    private func computeIslandCenter(in globalFrame: CGRect, viewSize: CGSize) -> CGPoint {
        let screenY = Self.islandTopOnScreen + (islandHeight / 2)
        if globalFrame.height >= screenBounds.height * 0.85 {
            return CGPoint(
                x: screenBounds.midX - globalFrame.minX,
                y: screenY - globalFrame.minY
            )
        }
        return CGPoint(x: viewSize.width / 2, y: screenY - globalFrame.minY)
    }

    private func flightStart(in globalFrame: CGRect, viewSize: CGSize) -> CGPoint {
        if globalFrame.height >= screenBounds.height * 0.85 {
            return CGPoint(
                x: screenBounds.midX - globalFrame.minX,
                y: screenBounds.height * 0.50 - globalFrame.minY
            )
        }
        return CGPoint(x: viewSize.width / 2, y: viewSize.height * 0.52)
    }

    private func beginFlightWhenLaidOut(
        globalFrame: CGRect,
        viewSize: CGSize,
        islandCenter: CGPoint
    ) {
        guard !didStartFlight else { return }
        guard viewSize.width > 1, viewSize.height > 1 else { return }
        didStartFlight = true

        let start = flightStart(in: globalFrame, viewSize: viewSize)
        flyPosition = start
        showFlyingImage = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            startFlyToIslandAnimation(start: start, islandCenter: islandCenter)
        }
    }

    private var islandPill: some View {
        ZStack {
            Capsule()
                .fill(Color.cyan.opacity(0.6))
                .blur(radius: 12)
                .frame(width: islandWidth + 10, height: islandHeight + 10)
                .opacity(islandGlowOpacity)

            RoundedRectangle(cornerRadius: islandCornerRadius)
                .fill(Color.black)
                .frame(width: islandWidth, height: islandHeight)
        }
    }

    private func startFlyToIslandAnimation(start: CGPoint, islandCenter: CGPoint) {
        let end = islandCenter
        let control = CGPoint(
            x: (start.x + end.x) / 2 + 48,
            y: (start.y + end.y) / 2 - 110
        )

        Self.lightImpact(intensity: 0.4)
        runBezierFlight(from: start, control: control, to: end, duration: 0.72) {
            absorbIntoIsland()
        }
    }

    private func runBezierFlight(
        from start: CGPoint,
        control: CGPoint,
        to end: CGPoint,
        duration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        let frameInterval = 1.0 / 60.0
        let totalFrames = Int(duration / frameInterval)
        var frame = 0

        let timer = Timer(timeInterval: frameInterval, repeats: true) { timer in
            frame += 1
            let rawT = min(1, CGFloat(frame) / CGFloat(max(totalFrames, 1)))
            let t = easeInOut(rawT)

            DispatchQueue.main.async {
                flyPosition = quadraticBezier(t: t, start: start, control: control, end: end)
                mediaScale = max(0.06, 0.55 - (0.49 * t))

                let approach = Double(min(1, t * 1.15))
                islandGlowOpacity = approach
                islandWidth = 110 + (150 * t)
                islandHeight = 36 + (32 * t)
                islandCornerRadius = 18 + (16 * t)
            }

            if rawT >= 1 {
                timer.invalidate()
                DispatchQueue.main.async { completion() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func absorbIntoIsland() {
        #if !targetEnvironment(simulator)
        hapticGenerator.prepare()
        hapticGenerator.impactOccurred(intensity: 1.0)
        #endif

        withAnimation(.spring(response: 0.28, dampingFraction: 0.62)) {
            islandWidth = 260
            islandHeight = 68
            islandCornerRadius = 34
            islandGlowOpacity = 1.0
            mediaScale = 0.02
            mediaOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if let data = sharedImage.jpegData(compressionQuality: 0.85) {
                onSaveData(data)
            }

            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                islandWidth = 110
                islandHeight = 36
                islandCornerRadius = 18
                islandGlowOpacity = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                onDismiss()
            }
        }
    }

    private func quadraticBezier(t: CGFloat, start: CGPoint, control: CGPoint, end: CGPoint) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * start.x + 2 * u * t * control.x + t * t * end.x,
            y: u * u * start.y + 2 * u * t * control.y + t * t * end.y
        )
    }

    private func easeInOut(_ t: CGFloat) -> CGFloat {
        t * t * (3 - 2 * t)
    }

    private static func lightImpact(intensity: CGFloat) {
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: intensity)
        #endif
    }
}
