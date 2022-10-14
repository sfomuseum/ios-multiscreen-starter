//
//  ViewController.swift
//  MultiScreen
//
//  Created by asc on 11/6/20.
//

import UIKit
import WebKit
import EventSource

class ViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {

    @IBOutlet var webView: WKWebView!

    let app = UIApplication.shared.delegate as! AppDelegate

    var url: String!
    
    var jsCompletionHandler: (Any?, Error?) -> Void = {
        
        (data, error) in
        
        if let error = error {
            // why can't I use logger here?
            print("JavaScript evaluation error: \(error)")
        }
    }
    
    //MARK: SSE
    // https://github.com/inaka/EventSource/blob/master/EventSourceSample/ViewController.swift
    var eventSource: EventSource?
    
    var sse_connection_attempts = 0
    let max_sse_connection_attempts = 100
    
    /// A  unix timestamp representing the time of the last SSE event from the relay server
    var last_sse_message = Int64(0)

    /// Semaphore to lock/unlock during SSE connections to stem "thundering herds" of connections/retries
    let sse_lock = DispatchSemaphore(value: 1)
    
    static func makeFromStoryboard(requestURLString: String) -> ViewController {
        
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateInitialViewController() as! ViewController
        
        vc.url = requestURLString
        return vc
    }
 
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func loadView() {
        
        app.logger.info("Load view for \(String(describing: self.url))")
        
        switch self.url {
        case "external.html":
            self.viewLoadExternal()
        default:
            self.viewLoadMain()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        
        if self.app.sse_enable {
            
            if self.app.network_available {
                
                // FIX: READ FROM info.plist
                let url = URL(string: "http://localhost:8080/sse")
                
                if url != nil {
                    self.app.sse_endpoint = url!
                    self.initializeSSE()
                }
            }
            
            NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "networkAvailable"),
                                                   object: nil,
                                                   queue: .main) { (notification) in
                
                let status = notification.object as! Bool
                let msg = "Network available: \(status)"
                
                self.app.logger.debug("Network available: \(status)")
                self.jsDebugLog(body: msg)
                
                if status == false {
                    self.eventSource?.disconnect()
                    self.sse_connection_attempts = 0
                } else {
                    self.initializeSSE()
                    // self.triggerShowCodeMessage()
                }
            }
        }
    }
    
    //MARK: Main
    
    func viewLoadMain(){
        
        let contentController = WKUserContentController();
                
        contentController.add(
            self,
            name: "consoleLog"
        )
                
        contentController.add(
            self,
            name: "sendMessage"
        )
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = contentController
        
        if self.url == nil {
            app.logger.error("Missing self.url")
            return
        }
        
        if app.sse_enable {
            self.url = "receiver.html"
        }
        
        var path = FileUtils.AbsPath(self.url)
        path = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                
        guard let url = URL(string: path) else {
            app.logger.error("Failed to convert path to URL \(path)")
            return
        }
        
        let request = URLRequest(url: url)
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        view = webView
        
        webView.load(request)
    }
    
    //MARK: External
    
    func viewLoadExternal(){
        
        let contentController = WKUserContentController();
        
        contentController.add(
            self,
            name: "consoleLog"
        )
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.userContentController = contentController
        
        var path = FileUtils.AbsPath(self.url)
        path = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                
        guard let url = URL(string: path) else {
            app.logger.error("Failed to convert path to URL \(path)")
            return
        }

        let request = URLRequest(url: url)
        
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        view = webView
        
        webView.load(request)
        
        NotificationCenter.default.addObserver(forName: Notification.Name(rawValue: "sendMessage"),
                               object: nil,
                               queue: .main) { (notification) in
                            
                            let msg = notification.object as! String
            
                            self.webView.evaluateJavaScript("receiveMessage('\(msg)')", completionHandler: self.jsCompletionHandler)
        }
    }
    
    //MARK: SSE
        
    /// Create SSE instance and register callbacks
    private func initializeSSE() {
                
        if self.app.sse_endpoint == nil {
            jsDebugLog(body: "Failed to intialize SSE, endpoint undefined.")
            return
        }
        
        let str_endpoint = self.app.sse_endpoint!.absoluteString

        self.sse_connection_attempts += 1
        
        jsDebugLog(body: "Initialize SSE w/ \(str_endpoint) \(sse_connection_attempts) of \(max_sse_connection_attempts)")
                    
        self.app.logger.warning("Initialize SSE w/ \(str_endpoint) \(sse_connection_attempts) of \(max_sse_connection_attempts)")
        
        if sse_connection_attempts > max_sse_connection_attempts {
            self.jsDebugLog(body: "Exceeded max SSE connection attempts")
            self.app.logger.warning("Exceeded max SSE connection attempts")
            return
        }
    
        // Okay, first things first. Only one process at a time talking to the
        // relay server...
        
        // Wait to do semaphore locking until after we've checked max attempts so
        // that the semaphore will get unlocked.
        
        self.sse_lock.signal()
        defer { self.sse_lock.signal() }
        
        let state = self.eventSource?.readyState
        jsDebugLog(body: "SSE begin connection with state \(String(describing: state))")

        switch state {
        case .connecting:
            jsDebugLog(body: "SSE connection in progress, exit this initialization")
            return
        case .open:
            // See this? It's bonkers that we need to do this but it appears to
            // be the only way to prevent an ever growing number of open SSE connections
            // See notes above.
            jsDebugLog(body: "SSE connection is already open, closing")
            self.eventSource?.disconnect()
        default:
            ()
        }
        
        eventSource = EventSource(url: self.app.sse_endpoint!)
        
        eventSource?.onOpen { [weak self] in
            let state = self?.eventSource?.readyState
            print("CONNTECT \(state)")
            self?.jsDebugLog(body: "SSE (native) connected with state \(String(describing: state))")
            self?.app.logger.info("SSE open")
            self?.sse_connection_attempts = 0
        }
        
        /*
        
        From the EventSource docs:
        
        /// Callback called once EventSource has disconnected from server. This can happen for multiple reasons.
        /// The server could have requested the disconnection or maybe a network layer error, wrong URL or any other
        /// error. The callback receives as parameters the status code of the disconnection, if we should reconnect or not
        /// following event source rules and finally the network layer error if any. All this information is more than
        /// enought for you to take a decition if you should reconnect or not.
        
        Basically, there are so many places in the chain where there might be a network
        disconnect from the relay-server (SSE broker timeouts), to nginx (proxy timeouts), to
        whatever is happening in the SFO network that... it's hard to imagine trapping all the
        edge cases in advance. Good times...
        
        */
        
        eventSource?.onComplete { [weak self] statusCode, reconnect, error in
            
            self?.jsDebugLog(body: "SSE (native) disconnected. Reconnect: \(String(describing: reconnect))")
            
            let str_code = String(describing: statusCode)
            let str_error = String(describing: error)
            
            if error != nil {
                self?.jsDebugLog(body: "SSE (native) disconnected with error, code: \(str_code)")
                
                self?.app.logger.warning("SSE disconnected with error, code: \(str_code) error: \(str_error) reconnect: \(String(describing: reconnect))")
                
                self?.jsDebugLog(body: "Disconnect event source")
                self?.eventSource?.disconnect()
            }
    
            let state = self?.eventSource?.readyState
            self?.jsDebugLog(body: "SSE state is \(String(describing: state))")
            
            guard reconnect ?? false else {
            //if reconnect == true {

                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5000)) { [weak self] in
                    self?.initializeSSE()
                }
                
                return
            }
            
            // self?.jsDebugLog(body: "SSE connection completed")
            // self?.eventSource?.disconnect()
            
            // See notes above. Basically just keep trying to reconnect.
            // Note: The relay server has a built-in timeout for disconnecting
            // SSE connections (default is 1H) in order to try and prevent
            // so-called "thundering herds" of SSE connections that are left
            // open. This might be better solved by changing the nginx proxy
            // config which sets an abnormally high timeout in order to prevent
            // nginx from trying to be clever. Either way: Someone is terminating
            // the SSE connection.

            let retryTime = self?.eventSource?.retryTime ?? 3000
            
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(retryTime)) { [weak self] in
                let state = self?.eventSource?.readyState
                self?.jsDebugLog(body: "SSE retry connect w/ ready state: \(String(describing: state))")
                self?.eventSource?.connect()
            }

        }
        
        eventSource?.onMessage { [weak self] id, event, raw in
            
            if raw == nil {
                return
            }
            
            let data = Data(raw!.utf8)
            let decoder = JSONDecoder()
            
            var message: SSEMessage
            
            do {
                message = try decoder.decode(SSEMessage.self, from: data)
                self?.handleSSEMessage(message: message)
            } catch(let err) {
                self?.app.logger.error("Problem decoding SSE message: \(err)")
                self?.app.logger.error("Message was \(String(describing: raw))")
            }
        }
        
        eventSource?.addEventListener("user-connected") { [weak self] id, event, data in
            let state = self?.eventSource?.readyState
            self?.app.logger.info("SSE connected with state \(String(describing: state))")
        }
        
        jsDebugLog(body: "Connect to SSE endpoint")
        eventSource?.connect()
    }
    
    /// Process individual SSE messages
    private func handleSSEMessage(message: SSEMessage) {
        
        self.last_sse_message = Int64(Date().timeIntervalSince1970)
        
        self.app.logger.info("SSE message received \(message.type)")
        
        // self.app.logger.info("[checkin] SSE message:  \(message.type)")
        // self.app.logger.info("SSE BODY \(message.data)")
        
        switch (message.type) {
        default:
            self.app.logger.warning("Unhandled SSE message type \(message.type)")
        }
    }
    
    //MARK: JavaScript
    
    /// Utility function to invoke t2.commom:debugMessage from inside iOS
    /// depends on <div id="debug-container"><div id="debug"></div></div>
    /// being uncommented (20200210/thisisaaronland)
    private func jsDebugLog(body: String) {
        self.jsDispatchAsync(jsFunc: "debugMessage('\(body)')")
    }
    
    /// Invoke the webView's evaluateJavaScript() method with the application's default completionHandler
    private func jsDispatch(jsFunc: String) {
        self.app.logger.debug("Dispatch JS '\(jsFunc)'")
        self.webView?.evaluateJavaScript(jsFunc, completionHandler: self.jsCompletionHandler)
    }
    
    /// Invoke the application's jsDispatch method ensuring that the operation is performed asynchronously
    private func jsDispatchAsync(jsFunc: String){
        DispatchQueue.main.async {
            self.jsDispatch(jsFunc: jsFunc)
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            
        app.logger.debug("Received message \(message.name)")
        
        switch message.name {
        case "consoleLog":
            app.logger.info("Received message \(message.name): \(message.body)")
        case "sendMessage":
            NotificationCenter.default.post(name: Notification.Name("sendMessage"), object: message.body)
        default:
            app.logger.debug("Unhandled message \(message.name)")
        }
    }


}
