//
//  AppDelegate.swift
//  MultiScreen
//
//  Created by asc on 11/6/20.
//

import UIKit
import WebKit
import Foundation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    private let primary = "main.html"
    private let external = "external.html"
    
    var window: UIWindow?

    // References to our windows that we're creating
    var windowsForScreens = [UIScreen: UIWindow]()
    
    // Create our view controller and add text to our test label
    
    private func addViewController(to window: UIWindow, requestURLString: String) {
        let vc = ViewController.makeFromStoryboard(requestURLString: requestURLString)
        
        vc.loadViewIfNeeded()
        window.rootViewController = vc
    }
    
    // Create and set up a new window with our view controller as the root
    private func setupWindow(for screen: UIScreen) {
        let window = UIWindow()
        
        addViewController(to: window, requestURLString: external)
        
        window.screen = screen
        window.makeKeyAndVisible()
        
        windowsForScreens[screen] = window
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Set up the device's main screen UI
        addViewController(to: window!, requestURLString: primary)
        
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
        
        /*
 
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "setFocus"),
                                               object: nil,
                                               queue: .main) { (notification) in
                                                let msg = notification.object as! WKScriptMessage
                                                
                                                if let focus = msg.body as? String {
                                                    // print("UPDATE FOCUS", focus)
                                                    self.current_location.focus = focus
                                                }
        }
        */
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

