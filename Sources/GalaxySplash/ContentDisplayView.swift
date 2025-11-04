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
        
        // Настройка User Agent (iOS 18.0 Safari 16.0)
        galaxyView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        
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
        var popupWebView: WKWebView? // Для OAuth popup
        
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
            
            let isPopup = webView == popupWebView
            let prefix = isPopup ? "🟣 [POPUP]" : "🔵 [MAIN]"
            
            if let url = action.request.url {
                print("\(prefix) decidePolicyFor: \(url.absoluteString)")
                
                let scheme = url.scheme?.lowercased()
                let urlStr = url.absoluteString.lowercased()
                
                // Открываем внешние схемы в системе
                if let scheme = scheme,
                   scheme != "http", scheme != "https", scheme != "about" {
                    print("\(prefix) Открываем внешнюю схему: \(scheme)")
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
                
                // ✅ Фоллбек: если target="_blank" и по какой-то причине не вызвался createWebViewWith
                if action.targetFrame == nil {
                    print("\(prefix) targetFrame == nil, загружаем в текущий WebView")
                    webView.load(URLRequest(url: url))
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
        
        // Обработка дочерних окон
        public func webView(_ webView: WKWebView,
                            createWebViewWith configuration: WKWebViewConfiguration,
                            for navAction: WKNavigationAction,
                            windowFeatures: WKWindowFeatures) -> WKWebView? {
            
            print("🟢 createWebViewWith вызван!")
            print("   URL: \(navAction.request.url?.absoluteString ?? "nil")")
            print("   targetFrame: \(navAction.targetFrame?.description ?? "nil")")
            print("   navigationType: \(navAction.navigationType.rawValue)")
            
            // Если URL пустой или about:blank - это OAuth popup
            // Нужно создать новый WebView и ДОБАВИТЬ его на экран
            if let url = navAction.request.url, 
               !url.absoluteString.isEmpty,
               url.absoluteString != "about:blank" {
                print("✅ Загружаем URL в текущий WebView: \(url.absoluteString)")
                webView.load(URLRequest(url: url))
                return nil
            } else {
                print("⚠️ Создаем popup WebView для OAuth")
                
                // Создаем popup WebView
                let popup = WKWebView(frame: webView.bounds, configuration: configuration)
                popup.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                popup.navigationDelegate = self
                popup.uiDelegate = self
                popup.backgroundColor = .black
                
                print("   📦 Popup создан, frame: \(popup.frame)")
                print("   📦 Parent webView frame: \(webView.frame)")
                
                // ВАЖНО: Добавляем popup на экран!
                webView.addSubview(popup)
                print("   ✅ Popup добавлен как subview")
                print("   🪟 Popup superview: \(popup.superview != nil ? "есть" : "нет")")
                print("   🎯 Число subviews в main WebView: \(webView.subviews.count)")
                
                // Добавляем кнопку закрытия
                let closeButton = UIButton(type: .system)
                closeButton.setTitle("✕", for: .normal)
                closeButton.titleLabel?.font = .systemFont(ofSize: 28, weight: .bold)
                closeButton.setTitleColor(.white, for: .normal)
                closeButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
                closeButton.layer.cornerRadius = 22
                closeButton.frame = CGRect(x: webView.bounds.width - 64, y: 50, width: 44, height: 44)
                closeButton.autoresizingMask = [.flexibleLeftMargin, .flexibleBottomMargin]
                closeButton.addTarget(self, action: #selector(closePopup), for: .touchUpInside)
                popup.addSubview(closeButton)
                
                print("   🔘 Кнопка закрытия добавлена")
                
                // Сохраняем ссылку на popup
                self.popupWebView = popup
                
                print("✅ Popup WebView создан и добавлен на экран")
                return popup
            }
        }
        
        
        // Закрытие popup
        @objc private func closePopup() {
            print("🔴 Закрываем popup")
            popupWebView?.removeFromSuperview()
            popupWebView = nil
            
            // Перезагружаем основной WebView после закрытия popup
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.galaxyWVView?.reload()
            }
        }
        
        // Автоматическое закрытие popup (вызывается сайтом через window.close())
        public func webViewDidClose(_ webView: WKWebView) {
            print("🟡 webViewDidClose вызван")
            if webView == popupWebView {
                closePopup()
            }
        }
        
        // Обработка начала навигации
        public func webView(_ galaxyWebView: WKWebView, didStartProvisionalNavigation galaxyNavigation: WKNavigation!) {
            let isPopup = galaxyWebView == popupWebView
            let prefix = isPopup ? "🟣 [POPUP]" : "🔵 [MAIN]"
            print("\(prefix) didStartProvisionalNavigation: \(galaxyWebView.url?.absoluteString ?? "nil")")
        }
        
        // Обработка завершения загрузки
        public func webView(_ galaxyWebView: WKWebView, didFinish galaxyNavigation: WKNavigation!) {
            galaxyRefreshControl?.endRefreshing()
            
            let isPopup = galaxyWebView == popupWebView
            let prefix = isPopup ? "🟣 [POPUP]" : "🔵 [MAIN]"
            print("\(prefix) didFinish: \(galaxyWebView.url?.absoluteString ?? "nil")")
            
            // Проверяем размеры popup
            if isPopup {
                print("   📏 Popup frame: \(galaxyWebView.frame)")
                print("   👁️ Popup isHidden: \(galaxyWebView.isHidden)")
                print("   🎨 Popup alpha: \(galaxyWebView.alpha)")
                print("   🪟 Popup superview: \(galaxyWebView.superview != nil ? "есть" : "нет")")
            }
        }
        
        // Обработка ошибок загрузки
        public func webView(_ galaxyWebView: WKWebView, didFail galaxyNavigation: WKNavigation!, withError galaxyError: Error) {
            galaxyRefreshControl?.endRefreshing()
            
            let isPopup = galaxyWebView == popupWebView
            let prefix = isPopup ? "🟣 [POPUP]" : "🔵 [MAIN]"
            print("\(prefix) didFail: \(galaxyError.localizedDescription)")
        }
        
        // Обработка ошибок загрузки (провизорная навигация)
        public func webView(_ galaxyWebView: WKWebView, didFailProvisionalNavigation galaxyNavigation: WKNavigation!, withError galaxyError: Error) {
            let isPopup = galaxyWebView == popupWebView
            let prefix = isPopup ? "🟣 [POPUP]" : "🔵 [MAIN]"
            print("\(prefix) didFailProvisionalNavigation: \(galaxyError.localizedDescription)")
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
