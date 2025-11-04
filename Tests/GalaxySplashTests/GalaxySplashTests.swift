import XCTest
@testable import GalaxySplash

final class GalaxySplashTests: XCTestCase {
    
    func testSplashScreenCreation() throws {
        // Тест проверяет создание splash screen с настройками по умолчанию
        let splashScreen = GalaxySplash.createSplashScreen()
        XCTAssertNotNil(splashScreen)
        
        // Тест с кастомными цветами
        let customSplashScreen = GalaxySplash.createSplashScreen(
            gradientColors: [.red, .orange, .yellow],
            textColor: .black,
            loaderColor: .blue,
            loadingText: "Загрузка..."
        )
        XCTAssertNotNil(customSplashScreen)
    }
    
    func testGalaxySplashInitialization() throws {
        // Тест проверяет, что пакет может быть импортирован и использован
        let starView = GalaxySplash.createAnimatedStar()
        XCTAssertNotNil(starView)
        
        let galaxyView = GalaxySplash.createGalaxy()
        XCTAssertNotNil(galaxyView)
        
        let spaceBackground = GalaxySplash.createSpaceBackground()
        XCTAssertNotNil(spaceBackground)
    }
    
    func testAnimatedStarWithCustomParameters() throws {
        let customStar = GalaxySplash.createAnimatedStar(
            size: 100,
            color: .red,
            duration: 2.0
        )
        XCTAssertNotNil(customStar)
    }
    
    func testGalaxyWithCustomParameters() throws {
        let customGalaxy = GalaxySplash.createGalaxy(
            elementCount: 12,
            size: 300,
            colors: [.green, .orange, .cyan]
        )
        XCTAssertNotNil(customGalaxy)
    }
    
    func testSpaceBackgroundWithCustomParameters() throws {
        let customBackground = GalaxySplash.createSpaceBackground(
            starCount: 100,
            speed: 3.0
        )
        XCTAssertNotNil(customBackground)
    }
}
