import SwiftUI

/// Анимированная звезда с пульсирующим эффектом
struct AnimatedStarView: View {
    let size: CGFloat
    let color: Color
    let duration: Double
    
    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0
    
    var body: some View {
        Image(systemName: "star.fill")
            .font(.system(size: size))
            .foregroundColor(color)
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                    scale = 1.3
                }
                withAnimation(.linear(duration: duration * 2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
