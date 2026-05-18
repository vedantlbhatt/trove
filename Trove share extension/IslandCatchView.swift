import SwiftUI

struct IslandCatchView: View {
    let sharedImage: UIImage
    var onDismiss: () -> Void
    var onSaveData: (Data) -> Void
    
    @State private var islandWidth: CGFloat = 110
    @State private var islandHeight: CGFloat = 36
    @State private var islandCornerRadius: CGFloat = 18
    @State private var islandYOffset: CGFloat = 11
    @State private var islandGlowOpacity: Double = 0.0
    
    @State private var currentPosition = CGSize.zero
    @State private var mediaScale: CGFloat = 1.0
    @State private var mediaOpacity: Double = 1.0
    @State private var isLockingToVortex = false
    
    #if !targetEnvironment(simulator)
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .rigid)
    #endif

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        if !isLockingToVortex { onDismiss() }
                    }
                
                VStack {
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
                    .padding(.top, islandYOffset)
                    Spacer()
                }
                .edgesIgnoringSafeArea(.top)
                
                if mediaOpacity > 0 {
                    Image(uiImage: sharedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                        .offset(currentPosition)
                        .scaleEffect(mediaScale)
                        .opacity(mediaOpacity)
                        .gesture(
                            DragGesture(coordinateSpace: .global)
                                .onChanged { value in
                                    guard !isLockingToVortex else { return }
                                    self.currentPosition = CGSize(width: value.translation.width, height: value.translation.height)
                                    
                                    let dragY = value.location.y
                                    let islandThreshold: CGFloat = 350
                                    
                                    if dragY < islandThreshold {
                                        let approachIntensity = max(0, min(1, (islandThreshold - dragY) / (islandThreshold - 40)))
                                        withAnimation(.interactiveSpring(response: 0.25, dampingFraction: 0.6)) {
                                            islandWidth = 110 + (approachIntensity * 130)
                                            islandHeight = 36 + (approachIntensity * 28)
                                            islandCornerRadius = 18 + (approachIntensity * 8)
                                            islandGlowOpacity = Double(approachIntensity)
                                        }
                                        if value.translation.height.truncatingRemainder(dividingBy: 25) == 0 {
                                            Self.lightImpact(intensity: approachIntensity)
                                        }
                                    } else {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            islandWidth = 110
                                            islandHeight = 36
                                            islandCornerRadius = 18
                                            islandGlowOpacity = 0.0
                                        }
                                    }
                                }
                                .onEnded { value in
                                    let triggerZoneY: CGFloat = 180
                                    if value.location.y < triggerZoneY || value.predictedEndLocation.y < triggerZoneY {
                                        triggerVacuumSequence(screenSize: geometry.size)
                                    } else {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                                            currentPosition = .zero
                                            islandWidth = 110
                                            islandHeight = 36
                                            islandCornerRadius = 18
                                            islandGlowOpacity = 0.0
                                            mediaScale = 1.0
                                        }
                                    }
                                }
                        )
                }
            }
        }
    }
    
    private static func lightImpact(intensity: CGFloat) {
        #if !targetEnvironment(simulator)
        UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: intensity)
        #endif
    }

    private func triggerVacuumSequence(screenSize: CGSize) {
        isLockingToVortex = true
        #if !targetEnvironment(simulator)
        hapticGenerator.prepare()
        #endif
        
        let targetYCoordinate = -((screenSize.height / 2) - (islandYOffset + (islandHeight / 2)))
        
        withAnimation(.timingCurve(0.42, 0.0, 0.58, 1.0, duration: 0.24)) {
            currentPosition = CGSize(width: 0, height: targetYCoordinate)
            mediaScale = 0.02
            mediaOpacity = 0.0
            islandWidth = 260
            islandHeight = 68
            islandCornerRadius = 34
            islandGlowOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            #if !targetEnvironment(simulator)
            hapticGenerator.impactOccurred(intensity: 1.0)
            #endif
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if let data = sharedImage.jpegData(compressionQuality: 0.85) {
                onSaveData(data)
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                islandWidth = 110
                islandHeight = 36
                islandCornerRadius = 18
                islandGlowOpacity = 0.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                onDismiss()
            }
        }
    }
}
