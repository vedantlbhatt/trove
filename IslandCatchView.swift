// IslandCatchView.swift
// SwiftUI overlay and Dynamic Island vacuum animation
//
// This view renders a full-screen transparent overlay with a top-centered
// capsule that mimics the Dynamic Island. A draggable preview card can be
// pulled toward the island; if released near the island, a vacuum animation
// plays and a callback asks the host controller to import and store the data.

import SwiftUI

// MARK: - ViewModel bridging UIKit <-> SwiftUI
final class IslandCatchViewModel: ObservableObject {
    enum Glyph: String {
        case link
        case doc
    }

    // Preview content derived by ShareViewController
    @Published var previewImage: UIImage?
    @Published var previewGlyph: Glyph? = nil

    // Callbacks supplied by ShareViewController
    var onRequestImport: (@Sendable (_ completion: @escaping (Bool) -> Void) -> Void)?
    var onFinish: (() -> Void)?
}

// MARK: - IslandCatchView
struct IslandCatchView: View {
    @ObservedObject var viewModel: IslandCatchViewModel

    // Island dimensions (approximate Dynamic Island baseline)
    @State private var islandWidth: CGFloat = 110
    @State private var islandHeight: CGFloat = 36

    // Drag state
    @State private var dragOffset: CGSize = .zero
    @State private var cardScale: CGFloat = 1.0
    @State private var cardOpacity: CGFloat = 1.0

    // Animation coordination
    @State private var isAnimatingVacuum: Bool = false

    // Layout constants
    private let standbyIslandSize = CGSize(width: 110, height: 36)
    private let expandedIslandSize = CGSize(width: 180, height: 52)
    private let gulpIslandSize = CGSize(width: 220, height: 60)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Transparent interceptor to catch taps outside
                Color.black.opacity(0.01)
                    .ignoresSafeArea()
                    .onTapGesture {
                        // Optional: tapping outside can cancel; here we simply spring the card back
                        restoreToStandby()
                    }

                // Top island
                VStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .frame(width: islandWidth, height: islandHeight)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 6)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                        )
                        .padding(.top, topInsetForDynamicIsland(proxy: proxy))
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: islandWidth)
                        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: islandHeight)
                    Spacer()
                }
                .allowsHitTesting(false)

                // Center draggable preview card
                previewCard
                    .position(x: proxy.size.width / 2 + dragOffset.width,
                              y: proxy.size.height / 2 + dragOffset.height)
                    .scaleEffect(cardScale)
                    .opacity(cardOpacity)
                    .gesture(dragGesture(in: proxy))
            }
        }
        .ignoresSafeArea()
    }

    // MARK: - Preview card rendering
    @ViewBuilder
    private var previewCard: some View {
        Group {
            if let image = viewModel.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // Fallback glyph when no image preview exists
                ZStack {
                    LinearGradient(colors: [Color.blue.opacity(0.9), Color.purple.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    VStack(spacing: 8) {
                        Image(systemName: viewModel.previewGlyph == .doc ? "doc" : "link")
                            .font(.system(size: 40, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(viewModel.previewGlyph == .doc ? "File" : "Link")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
            }
        }
        .frame(width: 220, height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 10)
    }

    // MARK: - Drag logic
    private func dragGesture(in proxy: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .global)
            .onChanged { value in
                guard !isAnimatingVacuum else { return }
                // Update drag offset
                dragOffset = CGSize(width: value.translation.width, height: value.translation.height)

                // If moving into upper half, expand island proportionally
                let centerY = proxy.size.height / 2
                let progress = max(0, min(1, (centerY - (centerY + dragOffset.height)) / centerY))
                // progress: 0 at center or below, 1 at top
                islandWidth = interpolate(from: standbyIslandSize.width, to: expandedIslandSize.width, progress: progress)
                islandHeight = interpolate(from: standbyIslandSize.height, to: expandedIslandSize.height, progress: progress)

                // Slightly scale card down as it approaches
                cardScale = interpolate(from: 1.0, to: 0.9, progress: progress)
            }
            .onEnded { value in
                guard !isAnimatingVacuum else { return }
                let thresholdY = -(proxy.size.height * 0.25) // must drag upward by 25% of screen height
                if value.translation.height <= thresholdY {
                    triggerVacuumAnimation(in: proxy)
                } else {
                    restoreToStandby()
                }
            }
    }

    private func restoreToStandby() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            dragOffset = .zero
            cardScale = 1.0
            cardOpacity = 1.0
            islandWidth = standbyIslandSize.width
            islandHeight = standbyIslandSize.height
        }
    }

    private func triggerVacuumAnimation(in proxy: GeometryProxy) {
        isAnimatingVacuum = true

        // 1) Animate island to gulp size and move the card behind it while fading out
        let topY = topInsetForDynamicIsland(proxy: proxy) + islandHeight / 2
        let targetPosition = CGPoint(x: proxy.size.width / 2, y: topY)

        withAnimation(.spring(response: 0.28, dampingFraction: 0.7)) {
            islandWidth = gulpIslandSize.width
            islandHeight = gulpIslandSize.height
        }

        withAnimation(.spring(response: 0.36, dampingFraction: 0.75)) {
            // Compute vector from current card center to island center
            dragOffset = CGSize(width: targetPosition.x - proxy.size.width / 2,
                                height: targetPosition.y - proxy.size.height / 2)
            cardScale = 0.01
            cardOpacity = 0.0
        }

        // 2) Ask host to import while we animate back to standby, then finish
        var storageFinished = false
        var animationFinished = false

        func tryFinish() {
            if storageFinished && animationFinished {
                viewModel.onFinish?()
            }
        }

        // Kick off storage
        viewModel.onRequestImport? { _ in
            storageFinished = true
            tryFinish()
        }

        // Animate island back down after a short delay to feel like a gulp
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.8)) {
                islandWidth = standbyIslandSize.width
                islandHeight = standbyIslandSize.height
            }
            // Give the island a moment to settle visually
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                animationFinished = true
                tryFinish()
            }
        }
    }

    // MARK: - Helpers
    private func interpolate(from: CGFloat, to: CGFloat, progress: CGFloat) -> CGFloat {
        from + (to - from) * progress
    }

    private func topInsetForDynamicIsland(proxy: GeometryProxy) -> CGFloat {
        // Approximate placement near the hardware cutout on modern iPhones.
        // Keep a small offset from very top to avoid status bar overlap artifacts.
        // Using safe area inset if available; otherwise default to ~18 points.
        let safeTop = proxy.safeAreaInsets.top
        return max(12, safeTop + 6)
    }
}

#Preview {
    IslandCatchView(viewModel: IslandCatchViewModel())
}
