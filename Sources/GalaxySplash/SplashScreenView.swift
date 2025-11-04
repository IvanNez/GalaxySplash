import SwiftUI

/// Красивый splash screen с градиентом и анимированным лоадером
struct SplashScreenView: View {
    let gradientColors: [Color]
    let textColor: Color
    let loaderColor: Color
    let loadingText: String
    
    @State private var rotation: Double = 0
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8
    
    var body: some View {
        ZStack {
            // Градиентный фон
            LinearGradient(
                gradient: Gradient(colors: gradientColors),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                Spacer()
                
                // Анимированный лоадер
                ZStack {
                    // Внешний круг
                    Circle()
                        .stroke(loaderColor.opacity(0.3), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    // Внутренний круг с анимацией
                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(
                            loaderColor,
                            style: StrokeStyle(
                                lineWidth: 8,
                                lineCap: .round
                            )
                        )
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(rotation))
                        .scaleEffect(scale)
                }
                
                // Текст загрузки
                Text(loadingText)
                    .font(.system(size: 24, weight: .medium, design: .rounded))
                    .foregroundColor(textColor)
                    .opacity(opacity)
                
                Spacer()
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Анимация вращения лоадера
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            rotation = 360
        }
        
        // Анимация пульсации лоадера
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            scale = 1.2
        }
        
        // Анимация мигания текста
        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
            opacity = 0.3
        }
    }
}
