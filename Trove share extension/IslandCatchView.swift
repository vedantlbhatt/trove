import SwiftUI
import UIKit

struct IslandCatchView: View {
    let sharedImage: UIImage
    let screenBounds: CGRect
    var onSaveData: (Data) -> Void
    var onDismiss: () -> Void

    // The real Dynamic Island lives at y ≈ 11 pt from the top of the screen.
    private static let islandTopY: CGFloat = 11

    @State private var islandWidth: CGFloat = 110
    @State private var islandHeight: CGFloat = 36
    @State private var islandCornerRadius: CGFloat = 20
    @State private var islandGlow: Double = 0

    @State private var thumbPos: CGPoint = .zero
    @State private var thumbScale: CGFloat = 0.6
    @State private var thumbOpacity: Double = 0
    @State private var flightStarted = false

    #if !targetEnvironment(simulator)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .rigid)
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    #endif

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            // With NSExtensionActionWantsFullScreenPresentation the view == full screen,
            // so we can place everything with simple screen-space coordinates.
            let islandCenter = CGPoint(x: size.width / 2,
                                      y: Self.islandTopY + islandHeight / 2)

            ZStack {
                Color.clear.ignoresSafeArea()

                // Fake Dynamic Island pill
                islandPill
                    .position(islandCenter)
                    .zIndex(10)

                // Flying thumbnail
                thumbView
                    .scaleEffect(thumbScale)
                    .opacity(thumbOpacity)
                    .position(thumbPos)
                    .zIndex(20)
            }
            .ignoresSafeArea(.all)
            .onAppear {
                guard !flightStarted, size.width > 1 else { return }
                flightStarted = true
                beginFlight(in: size, islandCenter: islandCenter)
            }
        }
        .ignoresSafeArea(.all)
    }

    // MARK: - Views

    @ViewBuilder
    private var thumbView: some View {
        let isSymbol = sharedImage.size.width < 80 && sharedImage.renderingMode == .alwaysTemplate
        if isSymbol {
            // SF Symbol placeholder — render in a rounded card
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 100, height: 100)
                Image(uiImage: sharedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .foregroundStyle(Color.white)
            }
            .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 6)
        } else {
            Image(uiImage: sharedImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.25), lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 14, x: 0, y: 6)
        }
    }

    // MARK: - Animation

    private func beginFlight(in size: CGSize, islandCenter: CGPoint) {
        // Start from the middle of the screen (where the shared content lives)
        let start = CGPoint(x: size.width / 2, y: size.height * 0.52)
        thumbPos    = start
        thumbScale  = 0.6
        thumbOpacity = 1

        // Arc control point: swing right and upward
        let control = CGPoint(
            x: start.x + 50,
            y: (start.y + islandCenter.y) / 2 - 80
        )

        // Brief pause so the user sees the thumb before it flies
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            #if !targetEnvironment(simulator)
            impactLight.impactOccurred(intensity: 0.5)
            #endif
            fly(from: start, control: control, to: islandCenter, duration: 0.65) {
                absorb(islandCenter: islandCenter)
            }
        }
    }

    private func fly(
        from start: CGPoint,
        control: CGPoint,
        to end: CGPoint,
        duration: TimeInterval,
        completion: @escaping () -> Void
    ) {
        let fps: Double = 60
        let total = Int(duration * fps)
        var frame = 0

        let timer = Timer(timeInterval: 1 / fps, repeats: true) { t in
            frame += 1
            let raw = min(1, CGFloat(frame) / CGFloat(max(total, 1)))
            let ease = raw * raw * (3 - 2 * raw)

            DispatchQueue.main.async {
                thumbPos   = bezier(t: ease, p0: start, p1: control, p2: end)
                thumbScale = max(0.05, 0.6 - 0.55 * ease)

                islandGlow   = Double(min(1, ease * 1.2))
                islandWidth  = 110 + 160 * ease
                islandHeight = 36  + 30  * ease
                islandCornerRadius = 20 + 14 * ease
            }

            if raw >= 1 {
                t.invalidate()
                DispatchQueue.main.async { completion() }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    private func absorb(islandCenter: CGPoint) {
        #if !targetEnvironment(simulator)
        impactHeavy.impactOccurred(intensity: 1.0)
        #endif

        // Island swallows the thumb
        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
            islandWidth        = 280
            islandHeight       = 70
            islandCornerRadius = 35
            islandGlow         = 1
            thumbScale         = 0.02
            thumbOpacity       = 0
        }

        // Save immediately while we still have time
        if let data = sharedImage.jpegData(compressionQuality: 0.85) {
            onSaveData(data)
        }

        // Island shrinks back then we're done
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                islandWidth        = 110
                islandHeight       = 36
                islandCornerRadius = 20
                islandGlow         = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                onDismiss()
            }
        }
    }

    // MARK: - Helpers

    private var islandPill: some View {
        ZStack {
            // Glow halo
            Capsule()
                .fill(Color.cyan.opacity(0.55))
                .blur(radius: 14)
                .frame(width: islandWidth + 12, height: islandHeight + 12)
                .opacity(islandGlow)

            // Pill body
            RoundedRectangle(cornerRadius: islandCornerRadius)
                .fill(Color.black)
                .frame(width: islandWidth, height: islandHeight)
        }
    }

    private func bezier(t: CGFloat, p0: CGPoint, p1: CGPoint, p2: CGPoint) -> CGPoint {
        let u = 1 - t
        return CGPoint(
            x: u * u * p0.x + 2 * u * t * p1.x + t * t * p2.x,
            y: u * u * p0.y + 2 * u * t * p1.y + t * t * p2.y
        )
    }
}
