import UIKit
import WebKit
import Foundation
import Logging
import Network

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
         
    var logger = Logger(label: "org.sfomuseum.multiscreen")
    
    /// The URL of the "controller" application defined in ...
    var relay_endpoint: URL?
    
    /// The URL of the "controller" application's "checkin" endpoint. We use this to signal that the iPad is still up and running.
    var checkin_endpoint: URL?
    
    /// The URL of the "controller" application's "SSE" endpoint where this application will listen for events to control the map
    var sse_endpoint: URL?
    
    /// Global variable to signal network availability - this is monitored and updated below
    var network_available = false

    var sse_enable = true   // Read from info.plist

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        logger.logLevel = .debug
        
        //MARK:  Check network status
        // https://developer.apple.com/documentation/network/nwpathmonitor/2998733-init
        
        let monitor = NWPathMonitor()
        
        let queue = DispatchQueue.global(qos: .background)
        monitor.start(queue: queue)
        monitor.pathUpdateHandler = { path in
            
            if path.status == .satisfied {
                self.network_available = true
            } else {
                self.network_available = false
            }
            
            NotificationCenter.default.post(name: Notification.Name("networkAvailable"), object: self.network_available)
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
