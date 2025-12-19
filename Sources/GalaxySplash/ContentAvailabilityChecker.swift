import Foundation
import Network
import UIKit

/// Универсальный проверщик доступности внешнего контента
public class ContentAvailabilityChecker {
    
    /// Результат проверки доступности контента
    public struct ContentCheckResult {
        public let shouldShowExternalContent: Bool
        public let finalUrl: String
        public let reason: String
        
        public init(shouldShowExternalContent: Bool, finalUrl: String, reason: String) {
            self.shouldShowExternalContent = shouldShowExternalContent
            self.finalUrl = finalUrl
            self.reason = reason
        }
    }
    
    /// Проверяет доступность внешнего контента с кэшированием результатов
    /// - Parameters:
    ///   - url: URL для проверки
    ///   - targetDate: Целевая дата (контент доступен только после этой даты)
    ///   - deviceCheck: Проверять ли тип устройства (iPad исключается)
    ///   - timeout: Таймаут для сетевых запросов
    ///   - cacheKey: Уникальный ключ для кэширования (по умолчанию используется URL)
    /// - Returns: Результат проверки с флагом показа и финальным URL
    public static func checkContentAvailability(
        url: String,
        targetDate: Date,
        deviceCheck: Bool = true,
        timeout: TimeInterval = 12.0,
        cacheKey: String? = nil
    ) -> ContentCheckResult {
        
        print("\n🔍 [ContentAvailabilityChecker] ========== START CHECK ==========")
        print("   Original URL: \(url)")
        print("   Cache key: \(cacheKey ?? "using URL as key")")
        
        let uniqueKey = cacheKey ?? url
        let hasShownExternalKey = "hasShownExternal_\(uniqueKey)"
        let hasShownAppKey = "hasShownApp_\(uniqueKey)"
        let savedUrlKey = "savedUrl_\(uniqueKey)"
        
        print("   UserDefaults keys:")
        print("     - hasShownExternal: \(hasShownExternalKey)")
        print("     - hasShownApp: \(hasShownAppKey)")
        print("     - savedUrl: \(savedUrlKey)")
        
        // Проверяем кэш - уже показывали внешний контент
        if UserDefaults.standard.bool(forKey: hasShownExternalKey) {
            print("\n✅ [ContentAvailabilityChecker] Found cached EXTERNAL content flag")
            let savedUrl = UserDefaults.standard.string(forKey: savedUrlKey) ?? url
            print("   Saved URL: \(savedUrl)")
            
            // Извлекаем и сохраняем path_id из сохранённой ссылки
            if let components = URLComponents(string: savedUrl),
               let pathIdItem = components.queryItems?.first(where: { $0.name == "pathid" }),
               let pathIdValue = pathIdItem.value {
                let pathIdKey = "savedPathId_\(url.hash)"
                print("\n🔑 [ContentAvailabilityChecker] Extracting path_id from saved URL")
                print("   Saved URL: \(savedUrl)")
                print("   Found path_id: \(pathIdValue)")
                print("   Saving to key: \(pathIdKey)")
                UserDefaults.standard.set(pathIdValue, forKey: pathIdKey)
                print("   ✅ path_id saved successfully")
            } else {
                print("\n⚠️ [ContentAvailabilityChecker] No path_id found in saved URL: \(savedUrl)")
            }
            
            // Валидируем сохраненный URL
            print("\n🔄 [ContentAvailabilityChecker] Validating saved URL...")
            let validationResult = validateSavedUrl(savedUrl: savedUrl, originalUrl: url, timeout: timeout)
            if validationResult.isValid {
                print("✅ [ContentAvailabilityChecker] Saved URL is VALID")
                print("   Final URL: \(validationResult.finalUrl)")
                print("🔍 [ContentAvailabilityChecker] ========== END CHECK (cached valid) ==========\n")
                return ContentCheckResult(
                    shouldShowExternalContent: true,
                    finalUrl: validationResult.finalUrl,
                    reason: "Valid cached external content"
                )
            } else {
                print("❌ [ContentAvailabilityChecker] Saved URL is INVALID, requesting new URL...")
                // Запрашиваем новый URL с path_id
                let newUrlResult = requestNewUrlWithPathId(originalUrl: url, timeout: timeout)
                if newUrlResult.success {
                    print("✅ [ContentAvailabilityChecker] Got new URL successfully")
                    print("   New final URL: \(newUrlResult.finalUrl)")
                    print("   Saving to key: \(savedUrlKey)")
                    UserDefaults.standard.set(newUrlResult.finalUrl, forKey: savedUrlKey)
                    print("   ✅ New URL saved to UserDefaults")
                    
                    // Извлекаем и сохраняем path_id из новой ссылки
                    if let components = URLComponents(string: newUrlResult.finalUrl),
                       let pathIdItem = components.queryItems?.first(where: { $0.name == "pathid" }),
                       let pathIdValue = pathIdItem.value {
                        let pathIdKey = "savedPathId_\(url.hash)"
                        print("\n🔑 [ContentAvailabilityChecker] Extracting path_id from new URL")
                        print("   New URL: \(newUrlResult.finalUrl)")
                        print("   Found path_id: \(pathIdValue)")
                        print("   Saving to key: \(pathIdKey)")
                        UserDefaults.standard.set(pathIdValue, forKey: pathIdKey)
                        print("   ✅ path_id saved successfully")
                    } else {
                        print("\n⚠️ [ContentAvailabilityChecker] No path_id found in new URL: \(newUrlResult.finalUrl)")
                    }
                    
                    print("🔍 [ContentAvailabilityChecker] ========== END CHECK (new URL) ==========\n")
                    return ContentCheckResult(
                        shouldShowExternalContent: true,
                        finalUrl: newUrlResult.finalUrl,
                        reason: "New URL with path_id"
                    )
                } else {
                    print("❌ [ContentAvailabilityChecker] Failed to get new URL")
                    print("🔍 [ContentAvailabilityChecker] ========== END CHECK (failed new URL) ==========\n")
                    return ContentCheckResult(
                        shouldShowExternalContent: true,
                        finalUrl: "",
                        reason: "Failed to get new URL, show empty WebView"
                    )
                }
            }
        }
        
        // Проверяем кэш - уже показывали приложение
        if UserDefaults.standard.bool(forKey: hasShownAppKey) {
            print("\n✅ [ContentAvailabilityChecker] Found cached APP content flag")
            print("🔍 [ContentAvailabilityChecker] ========== END CHECK (cached app) ==========\n")
            return ContentCheckResult(
                shouldShowExternalContent: false,
                finalUrl: "",
                reason: "Cached app content"
            )
        }
        
        print("\n🆕 [ContentAvailabilityChecker] No cache found, performing full checks...")
        
        // Проверка 1: Интернет соединение
        print("\n🌐 [ContentAvailabilityChecker] Check 1: Internet connection")
        let internetResult = checkInternetConnection(timeout: 2.0)
        if !internetResult {
            print("❌ [ContentAvailabilityChecker] No internet connection")
            print("   Saving APP flag to key: \(hasShownAppKey)")
            UserDefaults.standard.set(true, forKey: hasShownAppKey)
            print("🔍 [ContentAvailabilityChecker] ========== END CHECK (no internet) ==========\n")
            return ContentCheckResult(
                shouldShowExternalContent: false,
                finalUrl: "",
                reason: "No internet connection"
            )
        }
        print("✅ [ContentAvailabilityChecker] Internet connection OK")
        
        // Проверка 2: Дата
        print("\n📅 [ContentAvailabilityChecker] Check 2: Target date")
        print("   Target date: \(targetDate)")
        print("   Current date: \(Date())")
        let dateResult = checkTargetDate(targetDate: targetDate)
        if !dateResult {
            print("❌ [ContentAvailabilityChecker] Target date not reached")
            print("   Saving APP flag to key: \(hasShownAppKey)")
            UserDefaults.standard.set(true, forKey: hasShownAppKey)
            print("🔍 [ContentAvailabilityChecker] ========== END CHECK (date not reached) ==========\n")
            return ContentCheckResult(
                shouldShowExternalContent: false,
                finalUrl: "",
                reason: "Target date not reached"
            )
        }
        print("✅ [ContentAvailabilityChecker] Date check OK")
        
        // Проверка 3: Устройство (если включена)
        if deviceCheck {
            print("\n📱 [ContentAvailabilityChecker] Check 3: Device type")
            print("   Current device: \(UIDevice.current.model)")
            let deviceResult = checkDeviceType()
            if !deviceResult {
                print("❌ [ContentAvailabilityChecker] Device is iPad (not supported)")
                print("   Saving APP flag to key: \(hasShownAppKey)")
                UserDefaults.standard.set(true, forKey: hasShownAppKey)
                print("🔍 [ContentAvailabilityChecker] ========== END CHECK (iPad) ==========\n")
                return ContentCheckResult(
                    shouldShowExternalContent: false,
                    finalUrl: "",
                    reason: "Device not supported (iPad)"
                )
            }
            print("✅ [ContentAvailabilityChecker] Device check OK")
        } else {
            print("\n⚪️ [ContentAvailabilityChecker] Check 3: Device check DISABLED")
        }
        
        // Проверка 4: Серверный код
        print("\n🌐 [ContentAvailabilityChecker] Check 4: Server response")
        let serverResult = checkServerResponseWithPathId(url: url, timeout: timeout)
        if !serverResult.success {
            print("❌ [ContentAvailabilityChecker] Server check FAILED")
            print("   Reason: \(serverResult.reason)")
            print("   Saving APP flag to key: \(hasShownAppKey)")
            UserDefaults.standard.set(true, forKey: hasShownAppKey)
            print("🔍 [ContentAvailabilityChecker] ========== END CHECK (server failed) ==========\n")
            return ContentCheckResult(
                shouldShowExternalContent: false,
                finalUrl: "",
                reason: "Server check failed: \(serverResult.reason)"
            )
        }
        print("✅ [ContentAvailabilityChecker] Server check OK")
        print("   Final URL: \(serverResult.finalUrl)")
        
        // Все проверки пройдены - сохраняем результат
        print("\n🎉 [ContentAvailabilityChecker] All checks PASSED! Saving results...")
        print("   Saving EXTERNAL flag to key: \(hasShownExternalKey)")
        UserDefaults.standard.set(true, forKey: hasShownExternalKey)
        print("   Saving URL to key: \(savedUrlKey)")
        print("   URL value: \(serverResult.finalUrl)")
        UserDefaults.standard.set(serverResult.finalUrl, forKey: savedUrlKey)
        
        // Извлекаем и сохраняем path_id из финальной ссылки
        if let components = URLComponents(string: serverResult.finalUrl),
           let pathIdItem = components.queryItems?.first(where: { $0.name == "pathid" }),
           let pathIdValue = pathIdItem.value {
            let pathIdKey = "savedPathId_\(url.hash)"
            print("\n🔑 [ContentAvailabilityChecker] Extracting path_id from final URL")
            print("   Final URL: \(serverResult.finalUrl)")
            print("   Found path_id: \(pathIdValue)")
            print("   Saving to key: \(pathIdKey)")
            UserDefaults.standard.set(pathIdValue, forKey: pathIdKey)
            print("   ✅ path_id saved successfully")
        } else {
            print("\n⚠️ [ContentAvailabilityChecker] No path_id found in final URL: \(serverResult.finalUrl)")
        }
        
        print("🔍 [ContentAvailabilityChecker] ========== END CHECK (all passed) ==========\n")
        return ContentCheckResult(
            shouldShowExternalContent: true,
            finalUrl: serverResult.finalUrl,
            reason: "All checks passed"
        )
    }
    
    // MARK: - Private Methods
    
    private static func checkInternetConnection(timeout: TimeInterval) -> Bool {
        let monitor = NWPathMonitor()
        var isConnected = false
        let semaphore = DispatchSemaphore(value: 0)
        
        monitor.pathUpdateHandler = { path in
            isConnected = path.status == .satisfied
            semaphore.signal()
        }
        
        let queue = DispatchQueue(label: "ContentAvailabilityConnectionMonitor")
        monitor.start(queue: queue)
        
        _ = semaphore.wait(timeout: .now() + timeout)
        monitor.cancel()
        
        return isConnected
    }
    
    private static func checkTargetDate(targetDate: Date) -> Bool {
        let currentDate = Date()
        return currentDate >= targetDate
    }
    
    private static func checkDeviceType() -> Bool {
        return UIDevice.current.model != "iPad"
    }
    
    private static func checkServerResponse(url: String, timeout: TimeInterval) -> (success: Bool, finalUrl: String, reason: String) {
        print("\n🌐 [checkServerResponse] Checking server response")
        print("   📤 [checkServerResponse] REQUEST URL: \(url)")
        
        guard let requestUrl = URL(string: url) else {
            print("   ❌ [checkServerResponse] Invalid URL format")
            return (false, "", "Invalid URL")
        }
        
        let redirectHandler = ContentRedirectHandler()
        let session = URLSession(configuration: .default, delegate: redirectHandler, delegateQueue: nil)
        
        let semaphore = DispatchSemaphore(value: 0)
        var result = (success: false, finalUrl: "", reason: "Unknown error")
        
        print("   🚀 [checkServerResponse] Starting HTTP request...")
        let task = session.dataTask(with: requestUrl) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("   ❌ [checkServerResponse] Network error: \(error.localizedDescription)")
                result = (false, "", "Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("\n   📊 [checkServerResponse] ===== FINAL RESPONSE =====")
                print("   HTTP Status: \(httpResponse.statusCode)")
                print("   Response URL: \(httpResponse.url?.absoluteString ?? "nil")")
                
                // Показываем полную цепочку редиректов
                if redirectHandler.redirectCount > 0 {
                    print("   🔗 Total redirects: \(redirectHandler.redirectCount)")
                    print("   📊 Complete redirect chain:")
                    print("      0. (START) \(url)")
                    for (index, chainUrl) in redirectHandler.redirectChain.enumerated() {
                        print("      \(index + 1). (REDIRECT #\(index + 1)) \(chainUrl)")
                    }
                } else {
                    print("   ℹ️ No redirects - direct response")
                }
                
                if (200...403).contains(httpResponse.statusCode) {
                    let resolvedUrl = redirectHandler.finalUrl.isEmpty ? requestUrl.absoluteString : redirectHandler.finalUrl
                    print("   ✅ [checkServerResponse] Success!")
                    print("   📥 [checkServerResponse] FINAL URL: \(resolvedUrl)")
                    
                    // Анализируем финальный URL
                    if let components = URLComponents(string: resolvedUrl) {
                        let queryItems = components.queryItems ?? []
                        if !queryItems.isEmpty {
                            print("   🔍 Query parameters in FINAL URL:")
                            for item in queryItems {
                                print("      - \(item.name) = \(item.value ?? "nil")")
                            }
                        }
                    }
                    
                    result = (true, resolvedUrl, "Success")
                } else {
                    print("   ❌ [checkServerResponse] Server error: \(httpResponse.statusCode)")
                    result = (false, "", "Server error: \(httpResponse.statusCode)")
                }
            } else {
                print("   ❌ [checkServerResponse] Invalid response")
                result = (false, "", "Invalid response")
            }
        }
        
        task.resume()
        print("   ⏳ [checkServerResponse] Waiting for response...")
        _ = semaphore.wait(timeout: .now() + timeout)
        
        if result.success && result.finalUrl.isEmpty {
            result.finalUrl = requestUrl.absoluteString
            print("   ⚠️ [checkServerResponse] Empty final URL, using request URL")
        }
        
        return result
    }
    
    private static func checkServerResponseWithPathId(url: String, timeout: TimeInterval) -> (success: Bool, finalUrl: String, reason: String) {
        print("\n🌐 [checkServerResponseWithPathId] Starting server check")
        print("   Original URL: \(url)")
        print("   User ID: \(GalaxySplash.getUserID())")
        
        // Добавляем push_id к главной ссылке
        let urlWithPushId: String
        if url.contains("?") {
            urlWithPushId = "\(url)&push_id=\(GalaxySplash.getUserID())"
        } else {
            urlWithPushId = "\(url)?push_id=\(GalaxySplash.getUserID())"
        }
        
        print("   📤 [checkServerResponseWithPathId] REQUEST URL: \(urlWithPushId)")
        
        guard let requestUrl = URL(string: urlWithPushId) else {
            print("   ❌ [checkServerResponseWithPathId] Invalid URL format")
            return (false, "", "Invalid URL")
        }
        
        let redirectHandler = ContentRedirectHandler()
        let session = URLSession(configuration: .default, delegate: redirectHandler, delegateQueue: nil)
        
        let semaphore = DispatchSemaphore(value: 0)
        var result = (success: false, finalUrl: "", reason: "Unknown error")
        
        print("   🚀 [checkServerResponseWithPathId] Starting HTTP request...")
        let task = session.dataTask(with: requestUrl) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("   ❌ [checkServerResponseWithPathId] Network error: \(error.localizedDescription)")
                result = (false, "", "Network error: \(error.localizedDescription)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("\n   📊 [checkServerResponseWithPathId] ===== FINAL RESPONSE =====")
                print("   HTTP Status: \(httpResponse.statusCode)")
                print("   Response URL: \(httpResponse.url?.absoluteString ?? "nil")")
                
                // Показываем полную цепочку редиректов
                if redirectHandler.redirectCount > 0 {
                    print("   🔗 Total redirects: \(redirectHandler.redirectCount)")
                    print("   📊 Complete redirect chain:")
                    print("      0. (START) \(urlWithPushId)")
                    for (index, chainUrl) in redirectHandler.redirectChain.enumerated() {
                        print("      \(index + 1). (REDIRECT #\(index + 1)) \(chainUrl)")
                    }
                } else {
                    print("   ℹ️ No redirects - direct response")
                }
                
                if (200...403).contains(httpResponse.statusCode) {
                    let resolvedUrl = redirectHandler.finalUrl.isEmpty ? requestUrl.absoluteString : redirectHandler.finalUrl
                    print("   ✅ [checkServerResponseWithPathId] Success!")
                    print("   📥 [checkServerResponseWithPathId] FINAL URL: \(resolvedUrl)")
                    
                    // Анализируем финальный URL
                    if let components = URLComponents(string: resolvedUrl) {
                        let queryItems = components.queryItems ?? []
                        if !queryItems.isEmpty {
                            print("   🔍 Query parameters in FINAL URL:")
                            for item in queryItems {
                                print("      - \(item.name) = \(item.value ?? "nil")")
                            }
                        }
                    }
                    
                    result = (true, resolvedUrl, "Success")
                    
                    // Сохраняем path_id если есть
                    if let components = URLComponents(url: requestUrl, resolvingAgainstBaseURL: false),
                       let pathIdItem = components.queryItems?.first(where: { $0.name == "pathid" }),
                       let pathIdValue = pathIdItem.value {
                        let pathIdKey = "savedPathId_\(url.hash)"
                        print("\n🔑 [checkServerResponseWithPathId] Found path_id in request URL")
                        print("   path_id value: \(pathIdValue)")
                        print("   Saving to key: \(pathIdKey)")
                        UserDefaults.standard.set(pathIdValue, forKey: pathIdKey)
                        print("   ✅ path_id saved")
                    } else {
                        print("   ⚠️ [checkServerResponseWithPathId] No path_id in request URL")
                    }
                } else {
                    print("   ❌ [checkServerResponseWithPathId] Server error: \(httpResponse.statusCode)")
                    result = (false, "", "Server error: \(httpResponse.statusCode)")
                }
            } else {
                print("   ❌ [checkServerResponseWithPathId] Invalid response")
                result = (false, "", "Invalid response")
            }
        }
        
        task.resume()
        print("   ⏳ [checkServerResponseWithPathId] Waiting for response...")
        _ = semaphore.wait(timeout: .now() + timeout)
        
        if result.success && result.finalUrl.isEmpty {
            result.finalUrl = requestUrl.absoluteString
            print("   ⚠️ [checkServerResponseWithPathId] Empty final URL, using request URL")
        }
        
        return result
    }
    
    // MARK: - URL Validation and Path ID Methods
    
    private static func validateSavedUrl(savedUrl: String, originalUrl: String, timeout: TimeInterval) -> (isValid: Bool, finalUrl: String) {
        print("\n🔍 [validateSavedUrl] Validating saved URL")
        print("   Saved URL: \(savedUrl)")
        print("   Original URL: \(originalUrl)")
        print("   User ID: \(GalaxySplash.getUserID())")
        
        let processedSavedUrl: String
        if savedUrl.contains("?") {
            processedSavedUrl = "\(savedUrl)&push_id=\(GalaxySplash.getUserID())"
        } else {
            processedSavedUrl = "\(savedUrl)?push_id=\(GalaxySplash.getUserID())"
        }
        
        print("   📤 [validateSavedUrl] VALIDATION REQUEST URL: \(processedSavedUrl)")
        
        let validationResult = checkServerResponse(url: processedSavedUrl, timeout: timeout)
        if validationResult.success {
            let finalUrl = validationResult.finalUrl.isEmpty ? processedSavedUrl : validationResult.finalUrl
            print("   ✅ [validateSavedUrl] Validation SUCCESS")
            print("   📥 [validateSavedUrl] VALIDATION RESPONSE URL: \(finalUrl)")
            return (true, finalUrl)
        } else {
            print("   ❌ [validateSavedUrl] Validation FAILED: \(validationResult.reason)")
            return (false, processedSavedUrl)
        }
    }
    
    private static func requestNewUrlWithPathId(originalUrl: String, timeout: TimeInterval) -> (success: Bool, finalUrl: String) {
        print("\n🔄 [requestNewUrlWithPathId] Requesting new URL with saved path_id")
        print("   Original URL: \(originalUrl)")
        
        // Получаем сохраненный path_id
        let pathIdKey = "savedPathId_\(originalUrl.hash)"
        let savedPathId = UserDefaults.standard.string(forKey: pathIdKey) ?? ""
        
        if !savedPathId.isEmpty {
            print("   🔑 [requestNewUrlWithPathId] Found saved path_id: \(savedPathId)")
            print("   📦 [requestNewUrlWithPathId] Loaded from key: \(pathIdKey)")
        } else {
            print("   ⚠️ [requestNewUrlWithPathId] No saved path_id found")
            print("   📦 [requestNewUrlWithPathId] Checked key: \(pathIdKey)")
        }
        
        var urlString = originalUrl
        if !savedPathId.isEmpty {
            if urlString.contains("?") {
                urlString += "&pathid=\(savedPathId)"
            } else {
                urlString += "?pathid=\(savedPathId)"
            }
            print("   📤 [requestNewUrlWithPathId] REQUEST URL (with pathid): \(urlString)")
        } else {
            print("   📤 [requestNewUrlWithPathId] REQUEST URL (no pathid): \(urlString)")
        }
        
        let redirectHandler = ContentRedirectHandler()
        let session = URLSession(configuration: .default, delegate: redirectHandler, delegateQueue: nil)
        
        let semaphore = DispatchSemaphore(value: 0)
        var result = (success: false, finalUrl: "")
        
        guard let url = URL(string: urlString) else {
            print("   ❌ [requestNewUrlWithPathId] Invalid URL format")
            return (false, "")
        }
        
        print("   🚀 [requestNewUrlWithPathId] Starting HTTP request...")
        let task = session.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                print("   ❌ [requestNewUrlWithPathId] Network error: \(error.localizedDescription)")
                result = (false, "")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("\n   📊 [requestNewUrlWithPathId] ===== FINAL RESPONSE =====")
                print("   HTTP Status: \(httpResponse.statusCode)")
                print("   Response URL: \(httpResponse.url?.absoluteString ?? "nil")")
                
                // Показываем полную цепочку редиректов
                if redirectHandler.redirectCount > 0 {
                    print("   🔗 Total redirects: \(redirectHandler.redirectCount)")
                    print("   📊 Complete redirect chain:")
                    print("      0. (START) \(urlString)")
                    for (index, chainUrl) in redirectHandler.redirectChain.enumerated() {
                        print("      \(index + 1). (REDIRECT #\(index + 1)) \(chainUrl)")
                    }
                } else {
                    print("   ℹ️ No redirects - direct response")
                }
                
                if (200...403).contains(httpResponse.statusCode) {
                    let resolvedUrl = redirectHandler.finalUrl.isEmpty ? url.absoluteString : redirectHandler.finalUrl
                    print("   ✅ [requestNewUrlWithPathId] Success!")
                    print("   📥 [requestNewUrlWithPathId] FINAL URL: \(resolvedUrl)")
                    
                    // Анализируем финальный URL
                    if let components = URLComponents(string: resolvedUrl) {
                        let queryItems = components.queryItems ?? []
                        if !queryItems.isEmpty {
                            print("   🔍 Query parameters in FINAL URL:")
                            for item in queryItems {
                                print("      - \(item.name) = \(item.value ?? "nil")")
                            }
                        }
                    }
                    
                    result = (true, resolvedUrl)
                    
                    // Сохраняем новый path_id если есть
                    if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                       let pathIdItem = components.queryItems?.first(where: { $0.name == "pathid" }),
                       let pathIdValue = pathIdItem.value {
                        print("\n🔑 [requestNewUrlWithPathId] Found NEW path_id in response")
                        print("   New path_id value: \(pathIdValue)")
                        print("   Updating key: \(pathIdKey)")
                        UserDefaults.standard.set(pathIdValue, forKey: pathIdKey)
                        print("   ✅ New path_id saved")
                    } else {
                        print("   ⚠️ [requestNewUrlWithPathId] No path_id in response URL")
                    }
                } else {
                    print("   ❌ [requestNewUrlWithPathId] Server error: \(httpResponse.statusCode)")
                    result = (false, "")
                }
            } else {
                print("   ❌ [requestNewUrlWithPathId] Invalid response")
                result = (false, "")
            }
        }
        
        task.resume()
        print("   ⏳ [requestNewUrlWithPathId] Waiting for response...")
        _ = semaphore.wait(timeout: .now() + timeout)
        
        if result.success && result.finalUrl.isEmpty {
            result.finalUrl = url.absoluteString
            print("   ⚠️ [requestNewUrlWithPathId] Empty final URL, using request URL")
        }
        
        return result
    }
}

// MARK: - Redirect Handler

private class ContentRedirectHandler: NSObject, URLSessionTaskDelegate {
    var finalUrl: String = ""
    var redirectChain: [String] = []
    var redirectCount: Int = 0
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        redirectCount += 1
        
        if let url = request.url {
            finalUrl = url.absoluteString
            redirectChain.append(finalUrl)
            
            print("\n🔀 [ContentRedirectHandler] ====== REDIRECT #\(redirectCount) ======")
            print("   HTTP Status: \(response.statusCode)")
            print("   📍 Redirecting FROM: \(task.originalRequest?.url?.absoluteString ?? "unknown")")
            print("   📍 Redirecting TO: \(finalUrl)")
            
            // Показываем всю цепочку редиректов
            if redirectChain.count > 1 {
                print("   📊 Current redirect chain:")
                for (index, chainUrl) in redirectChain.enumerated() {
                    print("      \(index + 1). \(chainUrl)")
                }
            }
            
            // Проверяем наличие важных параметров
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                let queryItems = components.queryItems ?? []
                if !queryItems.isEmpty {
                    print("   🔍 Query parameters in redirect URL:")
                    for item in queryItems {
                        print("      - \(item.name) = \(item.value ?? "nil")")
                    }
                }
                
                // Особое внимание к path_id и push_id
                if let pathId = queryItems.first(where: { $0.name == "pathid" })?.value {
                    print("   🔑 Found path_id in redirect: \(pathId)")
                }
                if let pushId = queryItems.first(where: { $0.name == "push_id" })?.value {
                    print("   👤 Found push_id in redirect: \(pushId)")
                }
            }
        }
        
        // ВАЖНО: передаем request дальше, чтобы продолжить редиректы
        completionHandler(request)
    }
}

