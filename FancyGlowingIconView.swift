import SwiftUI

struct FancyGlowingIconView: View {
    @State private var animateGlow = false
    @State private var sparkles: [GlowingSparkle] = []

    let iconSize: CGFloat
    let glowGradient: Gradient
    let showSparkles: Bool

    init(
        iconSize: CGFloat = 120,
        glowGradient: Gradient = Gradient(
            colors: [.blue, .teal, .white]
        ),
        showSparkles: Bool = true
    ) {
        self.iconSize = iconSize
        self.glowGradient = glowGradient
        self.showSparkles = showSparkles
    }
    
    var body: some View {
        ZStack(alignment: .center) {
            
            if #available(iOS 18.0, *) {
                ForEach(0..<3) { index in
                    RoundedRectangle(cornerRadius: iconSize * 0.225)
                        .fill(
                            RadialGradient(
                                gradient: glowGradient,
                                center: .center,
                                startRadius: 0,
                                endRadius: iconSize * 0.8
                            )
                        )
                        .frame(width: iconSize, height: iconSize)
                        .blur(radius: CGFloat(index + 1) * 15)
                        .opacity(animateGlow ? 0.6 : 0.3)
                        .scaleEffect(animateGlow ? 1.2 + CGFloat(index) * 0.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 2.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                            value: animateGlow
                        )
                }
            }

            if showSparkles {
                
                ZStack {
                    ForEach(sparkles) { sparkle in
                        SparkleView(sparkle: sparkle)
                    }
                }
                .frame(width: iconSize * 2.5, height: iconSize * 2.5)
                .transition(.opacity.combined(with: .scale))
            }

            
            Image("AppIcon-2019-1024")
                .resizable()
                .frame(width: iconSize, height: iconSize)
                .foregroundStyle(
                    LinearGradient(
                        gradient: glowGradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: iconSize * 1.5, height: iconSize * 1.5)
        .onAppear {
            animateGlow = true
            generateSparkles()
            
            
            Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { _ in
                if sparkles.count < 20 {
                    addSparkle()
                }
            }
        }
        .animation(.smooth, value: showSparkles)
    }
    
    private func generateSparkles() {
        for _ in 0..<12 {
            addSparkle()
        }
    }
    
    private func addSparkle() {
        let sparkle = GlowingSparkle(
            position: randomSparklePosition(),
            size: CGFloat.random(in: 8...18),
            opacity: Double.random(in: 0.5...0.9),
            animationDuration: Double.random(in: 1.5...3)
        )
        sparkles.append(sparkle)
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + sparkle.animationDuration) {
            sparkles.removeAll { $0.id == sparkle.id }
        }
    }
    
    private func randomSparklePosition() -> CGPoint {
        let angle = Double.random(in: 0...(2 * .pi))
        
        let distance = CGFloat.random(in: (iconSize * 0.4)...(iconSize * 0.6))
        
        let x = cos(angle) * distance
        let y = sin(angle) * distance
        
        return CGPoint(x: x, y: y)
    }
}


struct GlowingSparkle: Identifiable {
    let id = UUID()
    let position: CGPoint
    let size: CGFloat
    let opacity: Double
    let animationDuration: Double
}


struct SparkleView: View {
    let sparkle: GlowingSparkle
    @State private var animate = false
    
    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: sparkle.size, height: sparkle.size)
            .opacity(animate ? 0 : sparkle.opacity)
            .scaleEffect(animate ? 0.1 : 1.0)
            .blur(radius: animate ? 2 : 0)
            .offset(
                x: animate ? sparkle.position.x * 1.5 : sparkle.position.x,
                y: animate ? sparkle.position.y * 1.5 : sparkle.position.y
            )
            .onAppear {
                withAnimation(.easeOut(duration: sparkle.animationDuration)) {
                    animate = true
                }
            }
    }
}

struct FancyGlowingIconDemo: View {
    let showSparkles: Bool

    var body: some View {
        ZStack {
            
            Rectangle()
                .foregroundStyle(Design.glowyGradient)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                
                FancyGlowingIconView(
                    showSparkles: showSparkles
                )
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview {
    @Previewable @State var showSparkles: Bool = false
    FancyGlowingIconDemo(
        showSparkles: showSparkles
    )
    .onTapGesture {
        showSparkles.toggle()
    }
}

enum Design {
    static var glowyGradient: LinearGradient {
        #if os(iOS)
        if #available(iOS 18.0, *) {
            return LinearGradient(colors: [
                Color.blue.mix(with: Color(UIColor.systemBackground), by: 0.5),
                Color.blue.mix(with: Color(UIColor.systemBackground), by: 0.8),
                Color.blue.mix(with: Color(UIColor.systemBackground), by: 0.9),
                Color(UIColor.systemBackground),
                Color(UIColor.systemBackground),
                Color(UIColor.systemBackground)
            ], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [
                Color.blue,
                Color(UIColor.systemBackground),
                Color(UIColor.systemBackground),
                Color(UIColor.systemBackground)
            ], startPoint: .top, endPoint: .bottom)
        }
        #elseif os(macOS)
        return LinearGradient(colors: [
            Color.blue,
            Color(NSColor.windowBackgroundColor),
            Color(NSColor.windowBackgroundColor),
            Color(NSColor.windowBackgroundColor)
        ], startPoint: .top, endPoint: .bottom)
        #endif
    }
}
