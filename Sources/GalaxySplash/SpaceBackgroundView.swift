import SwiftUI

/// Космический фон с движущимися звездами
struct SpaceBackgroundView: View {
    let starCount: Int
    let speed: Double
    
    @State private var stars: [Star] = []
    
    struct Star: Identifiable {
        let id = UUID()
        let x: CGFloat
        let y: CGFloat
        let size: CGFloat
        let opacity: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                
                ForEach(stars) { star in
                    Circle()
                        .fill(Color.white)
                        .frame(width: star.size, height: star.size)
                        .opacity(star.opacity)
                        .position(x: star.x, y: star.y)
                }
            }
            .onAppear {
                generateStars(in: geometry.size)
                animateStars()
            }
        }
    }
    
    private func generateStars(in size: CGSize) {
        stars = (0..<starCount).map { _ in
            Star(
                x: CGFloat.random(in: 0...size.width),
                y: CGFloat.random(in: 0...size.height),
                size: CGFloat.random(in: 1...3),
                opacity: Double.random(in: 0.3...1.0)
            )
        }
    }
    
    private func animateStars() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            withAnimation(.linear(duration: 0.1)) {
                for i in stars.indices {
                    stars[i] = Star(
                        x: stars[i].x + CGFloat(speed),
                        y: stars[i].y,
                        size: stars[i].size,
                        opacity: stars[i].opacity
                    )
                    
                    // Перемещаем звезды, которые вышли за границы экрана
                    // Используем большое значение для кроссплатформенности
                    if stars[i].x > 1000 {
                        stars[i] = Star(
                            x: -10,
                            y: stars[i].y,
                            size: stars[i].size,
                            opacity: stars[i].opacity
                        )
                    }
                }
            }
        }
    }
}
