import UIKit
import WebKit
import Foundation
import Logging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
        
    var logger = Logger(label: "org.sfomuseum.multiscreen")
 
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        self.logger.logLevel = .warning
    
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
