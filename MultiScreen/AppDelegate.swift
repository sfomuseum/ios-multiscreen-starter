import UIKit
import WebKit
import Foundation
import Logging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // https://developer.apple.com/documentation/uikit/windows_and_screens
    // https://developer.apple.com/documentation/uikit/uiscreen
    // https://developer.apple.com/documentation/uikit/windows_and_screens/displaying_content_on_a_connected_screen
    
    // https://www.bignerdranch.com/blog/adding-external-display-support-to-your-ios-app-is-ridiculously-easy/
    // https://medium.com/@dmytro.anokhin/notification-in-swift-d47f641282fa
    
    var logger = Logger(label: "org.sfomuseum.multiscreen")
    
    var window: UIWindow?
    
    // References to our windows that we're creating
    
    var windowsForScreens = [UIScreen: UIWindow]()
    
    // Create our view controller and add text to our test label
    
    private func addViewController(to window: UIWindow, requestURLString: String) {
        
        self.logger.info("add view controller \(requestURLString)")
        
        let vc = ViewController.makeFromStoryboard(requestURLString: requestURLString)
        
        vc.loadViewIfNeeded()
        window.rootViewController = vc
    }
    
    // Create and set up a new window with our view controller as the root
    
    private func setupWindow(for screen: UIScreen) {
        
        let window = UIWindow()
        
        let requestURLString = "external.html"
        addViewController(to: window, requestURLString: requestURLString)
        
        window.screen = screen
        window.makeKeyAndVisible()
        
        windowsForScreens[screen] = window
    }
    
    // Hide the window and remove our reference to it so it will be deallocated
    
    private func tearDownWindow(for screen: UIScreen) {
        guard let window = windowsForScreens[screen] else { return }
        window.isHidden = true
        windowsForScreens[screen] = nil
    }
        
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        self.logger.logLevel = .warning
        
        // Set up the device's main screen UI
        
        // let window = UIWindow()
        
        print("SCENES", application.connectedScenes)
        
        return true
        
        let requestURLString = "main.html"
        addViewController(to: window!, requestURLString: requestURLString)
        
        // We need to set up the other screens that are already connected
        
        let otherScreens = UIScreen.screens.filter { $0 != UIScreen.main }
        
        otherScreens.forEach { (screen) in
            setupWindow(for: screen)
        }
        
        // Listen for the screen connection notification
        // then set up the new window and attach it to the screen
        
        NotificationCenter.default
            .addObserver(forName: UIScreen.didConnectNotification,
                         object: nil,
                         queue: .main) { (notification) in
                            
                            // UIKit is nice enough to hand us the screen object
                            // that represents the newly connected display
                            let newScreen = notification.object as! UIScreen
                            self.setupWindow(for: newScreen)
        }
        
        // Listen for the screen disconnection notification.
        
        NotificationCenter.default.addObserver(forName: UIScreen.didDisconnectNotification,
                                               object: nil,
                                               queue: .main) { (notification) in
                                                
                                                let newScreen = notification.object as! UIScreen
                                                self.tearDownWindow(for: newScreen)
        }
        
        return true
    }
}

extension Bundle {
    var releaseVersionNumber: String? {
        return infoDictionary?["CFBundleShortVersionString"] as? String
    }
    var buildVersionNumber: String? {
        return infoDictionary?["CFBundleVersion"] as? String
    }
    var versionNumberPretty: String {
        return "v\(releaseVersionNumber ?? "0.0.0") (v\(buildVersionNumber ?? "x"))"
    }
}
