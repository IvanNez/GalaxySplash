import SwiftUI
import WebKit
import UIKit
import StoreKit

/// Конфигурация для отображения веб-контента
public struct ContentDisplayView: UIViewRepresentable {
    let urlString: String
    let allowsGestures: Bool
    let enableRefresh: Bool
    
    public init(urlString: String, allowsGestures: Bool = true, enableRefresh: Bool = true) {
        self.urlString = urlString
        self.allowsGestures = allowsGestures
        self.enableRefresh = enableRefresh
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        let galaxyConfig = WKWebViewConfiguration()
        let galaxyPreferences = WKWebpagePreferences()
        
        // Настройка JavaScript
        galaxyPreferences.allowsContentJavaScript = true
        galaxyConfig.defaultWebpagePreferences = galaxyPreferences
        galaxyConfig.preferences.javaScriptCanOpenWindowsAutomatically = true
        // Настройка медиа
        galaxyConfig.allowsInlineMediaPlayback = true
        galaxyConfig.mediaTypesRequiringUserActionForPlayback = []
        galaxyConfig.allowsAirPlayForMediaPlayback = true
        galaxyConfig.allowsPictureInPictureMediaPlayback = true
        
        // Настройка данных сайта
        galaxyConfig.websiteDataStore = WKWebsiteDataStore.default()
        
        // Создание WebView
        let galaxyView = WKWebView(frame: .zero, configuration: galaxyConfig)
        
        // Настройка фона (черный)
        galaxyView.backgroundColor = .black
        galaxyView.scrollView.backgroundColor = .black
        galaxyView.isOpaque = false
        
        // Настройка жестов
        galaxyView.allowsBackForwardNavigationGestures = allowsGestures
        
        // Используем Desktop Safari User Agent для прохождения Google OAuth
        // Desktop версия обходит блокировку "embedded browsers"
        galaxyView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
        
        // Настройка координатора
        galaxyView.navigationDelegate = context.coordinator
        galaxyView.uiDelegate = context.coordinator
        
        // Настройка refresh control
        let galaxyRefreshControl = UIRefreshControl()
        galaxyRefreshControl.tintColor = .white
        galaxyRefreshControl.addTarget(context.coordinator, action: #selector(context.coordinator.refreshContent(_:)), for: .valueChanged)
        galaxyView.scrollView.refreshControl = galaxyRefreshControl
        
        // Сохраняем ссылки в координаторе
        context.coordinator.galaxyWVView = galaxyView
        context.coordinator.galaxyRefreshControl = galaxyRefreshControl
        
        if let url = URL(string: urlString) {
            galaxyView.load(URLRequest(url: url))
        }
        
        return galaxyView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // ⚠️ НЕ перезагружаем на каждый апдейт SwiftUI
        // Загружаем только если реально сменился URL
        if uiView.url?.absoluteString != urlString, let url = URL(string: urlString) {
            uiView.load(URLRequest(url: url))
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: ContentDisplayView
        weak var galaxyWVView: WKWebView?
        weak var galaxyRefreshControl: UIRefreshControl?
        var oauthWebView: WKWebView? // Временный WebView для OAuth
        
        init(_ parent: ContentDisplayView) {
            self.parent = parent
            super.init()
            
            // Настройка observers для всех событий клавиатуры
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillShowGalaxy),
                name: UIResponder.keyboardWillShowNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardDidShowGalaxy),
                name: UIResponder.keyboardDidShowNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardWillHideGalaxy),
                name: UIResponder.keyboardWillHideNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(keyboardDidHideGalaxy),
                name: UIResponder.keyboardDidHideNotification,
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc func refreshContent(_ sender: UIRefreshControl) {
            galaxyWVView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.galaxyRefreshControl?.endRefreshing()
            }
        }
        
        // MARK: - Keyboard Handling
        
        // Мягкий viewport refresh без изменения DOM
        private func softViewportRefreshGalaxy() {
            guard let galaxyWebView = galaxyWVView else { return }
            
            // Легкий JavaScript - только события, без изменения DOM
            let galaxyJavaScript = """
            (function() {
                // Триггер viewport и window resize событий
                if (window.visualViewport) {
                    window.dispatchEvent(new Event('resize'));
                }
                window.dispatchEvent(new Event('resize'));
                
                // Легкий scroll для триггера reflow
                window.scrollBy(0, 1);
                window.scrollBy(0, -1);
            })();
            """
            
            galaxyWebView.evaluateJavaScript(galaxyJavaScript, completionHandler: nil)
            
            // Легкий нативный scroll
            let currentOffset = galaxyWebView.scrollView.contentOffset
            galaxyWebView.scrollView.setContentOffset(
                CGPoint(x: currentOffset.x, y: currentOffset.y + 1),
                animated: false
            )
            galaxyWebView.scrollView.setContentOffset(currentOffset, animated: false)
        }
        
        @objc private func keyboardWillShowGalaxy(_ notification: Notification) {
            softViewportRefreshGalaxy()
        }
        
        @objc private func keyboardDidShowGalaxy(_ notification: Notification) {
            // Отложенный refresh после полного показа клавиатуры
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.softViewportRefreshGalaxy()
            }
        }
        
        @objc private func keyboardWillHideGalaxy(_ notification: Notification) {
            softViewportRefreshGalaxy()
        }
        
        @objc private func keyboardDidHideGalaxy(_ notification: Notification) {
            // Немедленный refresh
            softViewportRefreshGalaxy()
            
            // Вторая попытка после задержки
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.softViewportRefreshGalaxy()
            }
            
            // Третья попытка после длинной задержки для упорных случаев
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.softViewportRefreshGalaxy()
            }
        }
        
        // Обработка навигации
        public func webView(_ webView: WKWebView,
                            decidePolicyFor action: WKNavigationAction,
                            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            
            if let url = action.request.url {
                print("🔵 [MAIN] decidePolicyFor: \(url.absoluteString)")
                
                let scheme = url.scheme?.lowercased()
                
                // Открываем внешние схемы в системе
                if let scheme = scheme,
                   scheme != "http", scheme != "https", scheme != "about" {
                    print("🔵 Открываем внешнюю схему: \(scheme)")
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
                
                // OAuth popup - загружаем в том же WebView (со свайпом назад)
                if action.targetFrame == nil {
                    print("🔵 targetFrame == nil (OAuth), загружаем в текущий WebView")
                    webView.load(URLRequest(url: url))
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        // Обработка дочерних окон - перехватываем URL для основного WebView
        public func webView(_ webView: WKWebView,
                            createWebViewWith configuration: WKWebViewConfiguration,
                            for navAction: WKNavigationAction,
                            windowFeatures: WKWindowFeatures) -> WKWebView? {
            
            print("🟢 createWebViewWith вызван!")
            print("   URL: \(navAction.request.url?.absoluteString ?? "nil")")
            
            // Если URL есть - загружаем в текущий WebView
            if let url = navAction.request.url, 
               !url.absoluteString.isEmpty,
               url.absoluteString != "about:blank" {
                print("✅ URL есть - загружаем OAuth в основной WebView")
                webView.load(URLRequest(url: url))
                return nil
            }
            
            // Если URL пустой - создаем СКРЫТЫЙ временный WebView
            // Он перехватит URL, который загрузит JavaScript, и передаст в основной WebView
            print("⚠️ URL пустой - создаем временный WebView для перехвата URL")
            
            let tempView = WKWebView(frame: .zero, configuration: configuration)
            tempView.navigationDelegate = self
            tempView.uiDelegate = self
            tempView.isHidden = true // Скрываем! Нужен только для перехвата URL
            
            // НЕ добавляем на экран, только сохраняем ссылку
            self.oauthWebView = tempView
            
            print("✅ Временный WebView создан (скрытый)")
            return tempView
        }
        
        // Закрытие временного WebView
        public func webViewDidClose(_ webView: WKWebView) {
            print("🟡 webViewDidClose вызван")
            if webView == oauthWebView {
                oauthWebView = nil
                print("✅ Временный WebView очищен")
            }
        }
        
        // Обработка начала навигации
        public func webView(_ galaxyWebView: WKWebView, didStartProvisionalNavigation galaxyNavigation: WKNavigation!) {
            let url = galaxyWebView.url?.absoluteString ?? "nil"
            
            // Если это временный WebView - перехватываем URL и загружаем в основной
            if galaxyWebView == oauthWebView, let realUrl = galaxyWebView.url {
                print("🎯 Перехватили URL из временного WebView: \(realUrl.absoluteString)")
                
                // Загружаем в основной WebView
                if let mainWebView = galaxyWVView {
                    print("✅ Загружаем в основной WebView")
                    mainWebView.load(URLRequest(url: realUrl))
                    
                    // Очищаем временный WebView
                    oauthWebView = nil
                }
                return
            }
            
            print("🔵 didStartProvisionalNavigation: \(url)")
        }
        
        // Обработка завершения загрузки
        public func webView(_ galaxyWebView: WKWebView, didFinish galaxyNavigation: WKNavigation!) {
            galaxyRefreshControl?.endRefreshing()
            print("🔵 didFinish: \(galaxyWebView.url?.absoluteString ?? "nil")")
        }
        
        // Обработка ошибок загрузки
        public func webView(_ galaxyWebView: WKWebView, didFail galaxyNavigation: WKNavigation!, withError galaxyError: Error) {
            galaxyRefreshControl?.endRefreshing()
            print("🔵 didFail: \(galaxyError.localizedDescription)")
        }
        
        // Обработка ошибок загрузки (провизорная навигация)
        public func webView(_ galaxyWebView: WKWebView, didFailProvisionalNavigation galaxyNavigation: WKNavigation!, withError galaxyError: Error) {
            print("🔵 didFailProvisionalNavigation: \(galaxyError.localizedDescription)")
        }
    }
}

/// SwiftUI обертка для ContentDisplayView с отступами от safe area
public struct SafeContentDisplayView: View {
    let urlString: String
    let allowsGestures: Bool
    let enableRefresh: Bool
    
    public init(urlString: String, allowsGestures: Bool = true, enableRefresh: Bool = true) {
        self.urlString = urlString
        self.allowsGestures = allowsGestures
        self.enableRefresh = enableRefresh
    }
    
    public var body: some View {
        ZStack {
            // Черный фон
            Color.black
                .ignoresSafeArea()
            
            // WebView с отступами от safe area
            ContentDisplayView(
                urlString: urlString,
                allowsGestures: allowsGestures,
                enableRefresh: enableRefresh
            )
            .ignoresSafeArea(.keyboard)
            .onAppear {
               
                
                // Запрос оценки при третьем запуске
                let launchCount = UserDefaults.standard.integer(forKey: "animationGalaxyLaunchCount")
                if launchCount == 2 {
                    if let scene = UIApplication.shared
                        .connectedScenes
                        .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                        SKStoreReviewController.requestReview(in: scene)
                    }
                }
            }
        }
    }
}
