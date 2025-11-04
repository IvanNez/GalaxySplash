import Foundation
import UIKit

/// Менеджер для показа кастомных alert'ов
public final class CustomAlertManager {
    public static let shared = CustomAlertManager()
    
    private init() {}
    
    /// Показывает alert для уведомлений с переходом в настройки
    public func showNotificationsAlert() {
        let alert = UIAlertController(
            title: "Notification are disabled",
            message: "To receive notifications, please enable them in sttings.",
            preferredStyle: .alert
        )
        
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let rootVC = windowScene.windows
                .first(where: { $0.isKeyWindow })?.rootViewController
        else {
            return
        }
        
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString),
               UIApplication.shared.canOpenURL(settingsURL) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        rootVC.present(alert, animated: true)
    }
    
    /// Показывает кастомный alert с настраиваемыми параметрами
    /// - Parameters:
    ///   - title: Заголовок alert'а
    ///   - message: Сообщение alert'а
    ///   - primaryButtonTitle: Текст основной кнопки
    ///   - secondaryButtonTitle: Текст вторичной кнопки (опционально)
    ///   - primaryAction: Действие при нажатии на основную кнопку
    ///   - secondaryAction: Действие при нажатии на вторичную кнопку (опционально)
    public func showCustomAlert(
        title: String,
        message: String,
        primaryButtonTitle: String,
        secondaryButtonTitle: String? = nil,
        primaryAction: (() -> Void)? = nil,
        secondaryAction: (() -> Void)? = nil
    ) {
        let alert = UIAlertController(
            title: title,
            message: message,
            preferredStyle: .alert
        )
        
        guard
            let windowScene = UIApplication.shared.connectedScenes
                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene,
            let rootVC = windowScene.windows.first?.rootViewController
        else {
            
            return
        }
        
        // Основная кнопка
        alert.addAction(UIAlertAction(title: primaryButtonTitle, style: .default) { _ in
            primaryAction?()
            
        })
        
        // Вторичная кнопка (если указана)
        if let secondaryTitle = secondaryButtonTitle {
            alert.addAction(UIAlertAction(title: secondaryTitle, style: .cancel) { _ in
                secondaryAction?()
                
            })
        }
        
        rootVC.present(alert, animated: true)
        
    }
    
    /// Показывает alert с подтверждением действия
    /// - Parameters:
    ///   - title: Заголовок alert'а
    ///   - message: Сообщение alert'а
    ///   - confirmTitle: Текст кнопки подтверждения (по умолчанию "OK")
    ///   - cancelTitle: Текст кнопки отмены (по умолчанию "Cancel")
    ///   - onConfirm: Действие при подтверждении
    ///   - onCancel: Действие при отмене (опционально)
    public func showConfirmationAlert(
        title: String,
        message: String,
        confirmTitle: String = "OK",
        cancelTitle: String = "Cancel",
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) {
        showCustomAlert(
            title: title,
            message: message,
            primaryButtonTitle: confirmTitle,
            secondaryButtonTitle: cancelTitle,
            primaryAction: onConfirm,
            secondaryAction: onCancel
        )
    }
}
