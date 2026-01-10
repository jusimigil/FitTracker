import SwiftUI
import UserNotifications

// 1. The "Delegate" that allows notifications to show while app is open
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // This function tells iOS: "Show the banner/sound even if FitTracker is open!"
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
}

@main
struct FitTrackerApp: App {
    // 2. Connect the Delegate to the App
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject var dataManager = DataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .onAppear {
                    // 3. Ask for permission immediately when app launches
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        if granted {
                            print("Notifications allowed")
                        } else {
                            print("Notifications denied")
                        }
                    }
                }
        }
    }
}
