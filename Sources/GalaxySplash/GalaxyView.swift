import SwiftUI

/// Галактика с вращающимися элементами
struct GalaxyView: View {
    let elementCount: Int
    let size: CGFloat
    let colors: [Color]
    
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<elementCount, id: \.self) { index in
                Circle()
                    .fill(colors[index % colors.count])
                    .frame(width: 20, height: 20)
                    .offset(x: size * 0.4)
                    .rotationEffect(.degrees(Double(index) * 360.0 / Double(elementCount)))
                    .rotationEffect(.degrees(rotation))
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 5.0).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
