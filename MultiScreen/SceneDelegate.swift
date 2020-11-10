//
//  SceneDelegate.swift
//  MultiScreen
//
//  Created by asc on 11/6/20.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    var windowsForScreens = [UIScreen: UIWindow]()
    
    private func addViewController(to window: UIWindow, requestURLString: String) {
        
        // self.logger.info("add view controller \(requestURLString)")
        
        let vc = ViewController.makeFromStoryboard(requestURLString: requestURLString)
        
        vc.loadViewIfNeeded()
        window.rootViewController = vc
    }
    
    private func setupWindow(for screen: UIScreen) {
        
        let window = UIWindow()
        
        let requestURLString = "external.html"
        addViewController(to: window, requestURLString: requestURLString)
        
        window.screen = screen
        window.makeKeyAndVisible()
        
        windowsForScreens[screen] = window
    }
    
    private func tearDownWindow(for screen: UIScreen) {
        guard let window = windowsForScreens[screen] else { return }
        window.isHidden = true
        windowsForScreens[screen] = nil
    }
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let _ = (scene as? UIWindowScene) else { return }
        
        if window == nil {
            return
        }
        
        print("WILL CONNCT", window)
        
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
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}

