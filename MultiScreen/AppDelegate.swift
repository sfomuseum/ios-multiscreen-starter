import UIKit
import WebKit
import Foundation
import Logging
import Network

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
         
    var logger = Logger(label: "org.sfomuseum.multiscreen")
    
    /// A boolean flag to signal whether or not the application should run using a networked
    /// relay server. This is read from the applications Settings bundle/preferences panel
    var enable_relay = false

    /// The root URL of the "controller" realy application
    /// This is read from the applications Settings bundle/preferences panel
    var relay_endpoint: URL?
    
    /// The URL of the "controller" application's "SSE" endpoint where this application will listen for events to control the map
    /// This is derived from relay_endpoint
    var sse_endpoint: URL?
    
    /// Global variable to signal network availability - this is monitored and updated below
    var network_available = false

    // I wish something like were just built in to iOS...
    // https://github.com/Abstract45/SettingsExample
    
    private func registerSettingsBundle() {
        
        guard let settingsBundle = Bundle.main.url(forResource: "Settings", withExtension:"bundle") else {
            NSLog("Could not find Settings.bundle")
            return;
        }
        
        guard let settings = NSDictionary(contentsOf: settingsBundle.appendingPathComponent("Root.plist")) else {
            NSLog("Could not find Root.plist in settings bundle")
            return
        }
        
        guard let preferences = settings.object(forKey: "PreferenceSpecifiers") as? [[String: AnyObject]] else {
            NSLog("Root.plist has invalid format")
            return
        }
        
        var defaultsToRegister = [String: AnyObject]()
        for p in preferences {
            if let k = p["Key"] as? String, let v = p["DefaultValue"] {
                // NSLog("%@", "registering \(v) for key \(k)")
                defaultsToRegister[k] = v
            }
        }
        
        UserDefaults.standard.register(defaults: defaultsToRegister)
    }
    
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        logger.logLevel = .debug
        
        // START OF stuff defined in Setttings.bundle
        
        registerSettingsBundle()
        
        let settings = UserDefaults.standard
        settings.synchronize()
        
        enable_relay = settings.bool(forKey: "EnableRelay")
        let str_relay_endpoint = settings.string(forKey: "RelayEndpoint")
        
        if str_relay_endpoint == nil{
            self.logger.error("Application is configured as receiver but relay endpoint is empty.")
            enable_relay = false
        }
        
        relay_endpoint = URL(string: str_relay_endpoint!)
        
        if relay_endpoint == nil {
            self.logger.error("Application is configured as receiver but relay endpoint can not be parsed.")
            enable_relay = false
        }
        
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
