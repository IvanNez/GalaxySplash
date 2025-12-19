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
        print("🔵 [ContentDisplayView] makeUIView called with URL: \(urlString)")
        
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
        galaxyView.customUserAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        
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
            print("🟢 [ContentDisplayView] Loading initial URL in makeUIView: \(url.absoluteString)")
            galaxyView.load(URLRequest(url: url))
        } else {
            print("🔴 [ContentDisplayView] Failed to create URL from string: \(urlString)")
        }
        
        return galaxyView
    }
    
    public func updateUIView(_ uiView: WKWebView, context: Context) {
        // ⚠️ НЕ перезагружаем на каждый апдейт SwiftUI
        // Загружаем только если реально сменился URL
        let currentUrl = uiView.url?.absoluteString ?? "nil"
        print("🔄 [ContentDisplayView] updateUIView called")
        print("   Current WebView URL: \(currentUrl)")
        print("   New URL string: \(urlString)")
        
        if uiView.url?.absoluteString != urlString, let url = URL(string: urlString) {
            print("🟡 [ContentDisplayView] URL changed! Loading new URL in updateUIView: \(url.absoluteString)")
            uiView.load(URLRequest(url: url))
        } else {
            print("⚪️ [ContentDisplayView] URL unchanged, skipping reload")
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
            print("🔄 [ContentDisplayView] Manual refresh triggered")
            if let currentUrl = galaxyWVView?.url?.absoluteString {
                print("   Reloading URL: \(currentUrl)")
            }
            galaxyWVView?.reload()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.galaxyRefreshControl?.endRefreshing()
                print("✅ [ContentDisplayView] Refresh completed")
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
            
            let isOAuthWebView = webView == oauthWebView
            let webViewType = isOAuthWebView ? "OAuth WebView" : "Main WebView"
            
            print("\n🔵 [decidePolicyFor] Called on \(webViewType)")
            
            if let url = action.request.url {
                let urlString = url.absoluteString
                print("   URL: \(urlString)")
                print("   Target frame: \(action.targetFrame != nil ? "exists" : "nil (popup/new window)")")
                print("   Navigation type: \(action.navigationType.rawValue)")
                
                // Если это временный WebView - перехватываем РЕАЛЬНЫЙ URL здесь!
                if webView == oauthWebView {
                    print("   🟠 [decidePolicyFor] Processing in OAuth WebView")
                    if !urlString.isEmpty && 
                       urlString != "about:blank" &&
                       !urlString.hasPrefix("about:") {
                        print("   ✅ [decidePolicyFor] Valid OAuth URL detected, loading in main WebView")
                        // Загружаем в основной WebView
                        if let mainWebView = galaxyWVView {
                            print("   📤 [decidePolicyFor] LOADING URL IN MAIN WEBVIEW: \(urlString)")
                            mainWebView.load(URLRequest(url: url))
                            oauthWebView = nil
                            print("   🗑️ [decidePolicyFor] OAuth WebView destroyed")
                        }
                        decisionHandler(.cancel)
                        print("   ⛔️ [decidePolicyFor] Navigation CANCELLED in OAuth WebView\n")
                        return
                    } else {
                        print("   ⚪️ [decidePolicyFor] Ignoring empty/about:blank URL in OAuth WebView")
                    }
                }
                
                let scheme = url.scheme?.lowercased()
                
                // Открываем внешние схемы в системе
                if let scheme = scheme,
                   scheme != "http", scheme != "https", scheme != "about" {
                    print("   🌐 [decidePolicyFor] External scheme detected: \(scheme)")
                    print("   📱 [decidePolicyFor] Opening in system: \(urlString)")
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    print("   ⛔️ [decidePolicyFor] Navigation CANCELLED (external scheme)\n")
                    return
                }
                
                // OAuth popup - загружаем в том же WebView (со свайпом назад)
                if action.targetFrame == nil {
                    print("   🟣 [decidePolicyFor] Popup detected (targetFrame = nil)")
                    print("   📤 [decidePolicyFor] LOADING URL IN SAME WEBVIEW: \(urlString)")
                    webView.load(URLRequest(url: url))
                    decisionHandler(.cancel)
                    print("   ⛔️ [decidePolicyFor] Navigation CANCELLED (loading in same WebView)\n")
                    return
                }
            } else {
                print("   ⚠️ [decidePolicyFor] URL is nil")
            }
            
            print("   ✅ [decidePolicyFor] Navigation ALLOWED\n")
            decisionHandler(.allow)
        }
        
        // Обработка дочерних окон - перехватываем URL для основного WebView
        public func webView(_ webView: WKWebView,
                            createWebViewWith configuration: WKWebViewConfiguration,
                            for navAction: WKNavigationAction,
                            windowFeatures: WKWindowFeatures) -> WKWebView? {
            
            print("\n🟣 [createWebViewWith] Called")
            
            if let url = navAction.request.url {
                print("   Request URL: \(url.absoluteString)")
            } else {
                print("   Request URL: nil")
            }
            
            // Если URL есть - загружаем в текущий WebView
            if let url = navAction.request.url, 
               !url.absoluteString.isEmpty,
               url.absoluteString != "about:blank" {
                print("   ✅ [createWebViewWith] Valid URL detected")
                print("   📤 [createWebViewWith] LOADING URL IN CURRENT WEBVIEW: \(url.absoluteString)")
                webView.load(URLRequest(url: url))
                print("   ↩️ [createWebViewWith] Returning nil (no new WebView created)\n")
                return nil
            }
            
            // Если URL пустой - создаем СКРЫТЫЙ временный WebView
            // Он перехватит URL, который загрузит JavaScript, и передаст в основной WebView
            print("   ⚠️ [createWebViewWith] Empty/about:blank URL, creating temporary OAuth WebView")
            let tempView = WKWebView(frame: .zero, configuration: configuration)
            tempView.navigationDelegate = self
            tempView.uiDelegate = self
            tempView.isHidden = true
            
            self.oauthWebView = tempView
            print("   🆕 [createWebViewWith] Temporary OAuth WebView created and saved")
            print("   ↩️ [createWebViewWith] Returning temporary WebView\n")
            return tempView
        }
        
        // Закрытие временного WebView
        public func webViewDidClose(_ webView: WKWebView) {
            print("\n🔴 [webViewDidClose] Called")
            if webView == oauthWebView {
                print("   🗑️ [webViewDidClose] Closing OAuth WebView")
                oauthWebView = nil
                print("   ✅ [webViewDidClose] OAuth WebView destroyed\n")
            } else {
                print("   ⚠️ [webViewDidClose] Not an OAuth WebView\n")
            }
        }
        
        // Обработка начала навигации
        public func webView(_ galaxyWebView: WKWebView, didStartProvisionalNavigation galaxyNavigation: WKNavigation!) {
            let isOAuthWebView = galaxyWebView == oauthWebView
            let webViewType = isOAuthWebView ? "OAuth WebView" : "Main WebView"
            
            print("\n🟢 [didStartProvisionalNavigation] Called on \(webViewType)")
            
            if let currentUrl = galaxyWebView.url {
                print("   Current URL: \(currentUrl.absoluteString)")
            } else {
                print("   Current URL: nil")
            }
            
            // Если это временный WebView - перехватываем РЕАЛЬНЫЙ URL (не about:blank)
            if galaxyWebView == oauthWebView, let realUrl = galaxyWebView.url {
                let urlString = realUrl.absoluteString
                print("   🟠 [didStartProvisionalNavigation] Processing OAuth WebView URL")
                
                // Игнорируем пустые URL и about:blank
                if !urlString.isEmpty && 
                   urlString != "about:blank" &&
                   !urlString.hasPrefix("about:") {
                    print("   ✅ [didStartProvisionalNavigation] Valid OAuth URL detected")
                    print("   📤 [didStartProvisionalNavigation] LOADING URL IN MAIN WEBVIEW: \(urlString)")
                    // Загружаем в основной WebView
                    if let mainWebView = galaxyWVView {
                        mainWebView.load(URLRequest(url: realUrl))
                        oauthWebView = nil
                        print("   🗑️ [didStartProvisionalNavigation] OAuth WebView destroyed")
                    }
                    print("   ↩️ [didStartProvisionalNavigation] Returning early\n")
                    return
                } else {
                    print("   ⚪️ [didStartProvisionalNavigation] Ignoring empty/about:blank URL")
                }
            }
            
            print("   ✅ [didStartProvisionalNavigation] Navigation started\n")
        }
        
        // Обработка завершения загрузки
        public func webView(_ galaxyWebView: WKWebView, didFinish galaxyNavigation: WKNavigation!) {
            let isOAuthWebView = galaxyWebView == oauthWebView
            let webViewType = isOAuthWebView ? "OAuth WebView" : "Main WebView"
            
            print("\n✅ [didFinish] Navigation finished on \(webViewType)")
            
            if let finalUrl = galaxyWebView.url {
                print("   Final URL: \(finalUrl.absoluteString)")
            } else {
                print("   Final URL: nil")
            }
            
            galaxyRefreshControl?.endRefreshing()
            print("   🔄 Refresh control ended\n")
        }
        
        // Обработка ошибок загрузки
        public func webView(_ galaxyWebView: WKWebView, didFail galaxyNavigation: WKNavigation!, withError galaxyError: Error) {
            let isOAuthWebView = galaxyWebView == oauthWebView
            let webViewType = isOAuthWebView ? "OAuth WebView" : "Main WebView"
            
            print("\n❌ [didFail] Navigation failed on \(webViewType)")
            print("   Error: \(galaxyError.localizedDescription)")
            
            if let failedUrl = galaxyWebView.url {
                print("   Failed URL: \(failedUrl.absoluteString)")
            } else {
                print("   Failed URL: nil")
            }
            
            galaxyRefreshControl?.endRefreshing()
            print("   🔄 Refresh control ended\n")
        }
        
        // Обработка ошибок загрузки (провизорная навигация)
        public func webView(_ galaxyWebView: WKWebView, didFailProvisionalNavigation galaxyNavigation: WKNavigation!, withError galaxyError: Error) {
            let isOAuthWebView = galaxyWebView == oauthWebView
            let webViewType = isOAuthWebView ? "OAuth WebView" : "Main WebView"
            
            print("\n❌ [didFailProvisionalNavigation] Provisional navigation failed on \(webViewType)")
            print("   Error: \(galaxyError.localizedDescription)")
            
            if let failedUrl = galaxyWebView.url {
                print("   Failed URL: \(failedUrl.absoluteString)")
            } else {
                print("   Failed URL: nil")
            }
            
            print("   ⚠️ [didFailProvisionalNavigation] Page failed to load\n")
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
