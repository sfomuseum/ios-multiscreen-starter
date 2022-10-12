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

    var checkin_timer: Timer?
    
    /// Number of seconds between checkins
    var checkin_interval = TimeInterval(30)
    
    var last_checkin_time = Int64(0)
    var last_checkin_attempted = Int64(0)
    
    var last_checkin_status = false
    
    /// The maximum number of seconds that it's okay to have not heard from the relay server
    var last_checkin_allowable_delay = 90

    /// Semaphore to lock/unlock during SSE connections to stem "thundering herds" of connections/retries
    let sse_lock = DispatchSemaphore(value: 1)
    
    static func makeFromStoryboard(requestURLString: String) -> ViewController {
        
        let vc = UIStoryboard(name: "Main", bundle: nil)
            .instantiateInitialViewController() as! ViewController
        
        vc.url = requestURLString
        return vc
    }
    
    // This no longer seems to be necessary - as in HTML pages loaded
    // by a WKWebView instance seem to be able to load adjacent JavaScript
    // files defined in <script> tags. I am leaving this here for historical
    // purposes and "just in case". (20201111/thisisaaronland)
    
    static func buildUserScript(_ paths:Array<String>)->Result<WKUserScript, Error>{
        
        /*
         
        let scripts = [
            "javascript/common.js",
            "javascript/external.js"
        ]
        
        let script_rsp = ViewController.buildUserScript(scripts)
        
        switch script_rsp {
        case .failure(let error):
            print(error)
        case .success(let script):
            contentController.addUserScript(script)
        }
        
        */
                
        let script_rsp = FileUtils.ConcatenateFileContents(paths)
        
        switch script_rsp {
        case .failure(let error):
            print("Failed to concatenate file contents: \(error)")
            return .failure(error)
        case .success(let body):
            
            let script = WKUserScript(
                source: body,
                injectionTime: WKUserScriptInjectionTime.atDocumentEnd,
                forMainFrameOnly: true
            )
            
            return .success(script)
        }
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
        
        switch self.url {
        case "external.html":
            self.webViewDidFinishExternal()
        default:
            self.webViewDidFinishMain()
        }
    }
    
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
    
    func webViewDidFinishMain() {
        // no-op
    }
    
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
    
    func webViewDidFinishExternal() {
        // no-op
    }
    
    //MARK: SSE
    
    /// A thin wrapper around the initializeSSE method to ensure that the application can make a successful
    /// "checkin" request with the relay server. It can optionally be configured to retry the connection (and checkin)
    /// until successful.
    private func initializeSSEWithCheckin(retry: Bool, max_tries: Int) {
        
        jsDebugLog(body: "Initialize SSE with checkin, retry: \(retry) max tries: \(max_tries)")
        
        var req = URLRequest(url: self.app.checkin_endpoint!)
        req.httpMethod = "POST"
        req.timeoutInterval = TimeInterval(10) // Default is 60 seconds, we run every 30 seconds...
        
        let task = URLSession.shared.dataTask(with: req) { [self] data, response, error in
            
            self.last_checkin_attempted = Int64(Date().timeIntervalSince1970)
            
            guard let rsp = response as? HTTPURLResponse else {
                self.last_checkin_status = false
                self.initializeSSEWithCheckinOnError(retry: retry, max_tries: max_tries)
                return
            }
            
            if error != nil {
                self.last_checkin_status = false
                self.initializeSSEWithCheckinOnError(retry: retry, max_tries: max_tries)
                return
            }
            
            guard (204) ~= rsp.statusCode else {
                self.last_checkin_status = false
                self.initializeSSEWithCheckinOnError(retry: retry, max_tries: max_tries)
                return
            }
            
            self.last_checkin_time = Int64(Date().timeIntervalSince1970)
            self.last_checkin_status = true
            
            self.initializeSSE()
        }
        
        task.resume()
    }
    
    /// Private method to wrap how (whether) to handle unsuccessful checkin responses from the
    /// initializeSSEWithCheckIn method
    private func initializeSSEWithCheckinOnError(retry: Bool, max_tries: Int) {
        
        if !retry{
            return
        }
        
        var _max_tries = max_tries
        
        if _max_tries > 0 {
            
            _max_tries = _max_tries - 1
            
            if _max_tries == 0 {
                return
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(5000)) { [weak self] in
            self?.initializeSSEWithCheckin(retry: retry, max_tries: _max_tries)
        }
    }
    
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
                    self?.jsDebugLog(body: "SSE do reconnect (w/ retries)")
                    
                    self?.initializeSSEWithCheckin(retry: false, max_tries: -1)
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
        
        // Start a timer to ensure that we've received a (any) message from the relay-server
        // recently. We do this to prevent scenarios where the iPad application will show a
        // a QR code that will result in an error (because the relay server isn't responding)
        
        if checkin_timer == nil {
            
            jsDebugLog(body: "Create checkin timer")
            self.checkin_timer = Timer.scheduledTimer(timeInterval: self.checkin_interval, target: self, selector: #selector(checkInWithRelayServer), userInfo: nil, repeats: true)
        }
    }
    
    /// Code to check whether the application can "check in" with the relay server.
    @objc private func checkInWithRelayServer() {
        
        if !self.app.network_available {
            self.app.logger.debug("Unable to checkin, network unavailable")
            return
        }
        
        var req = URLRequest(url: self.app.checkin_endpoint!)
        req.httpMethod = "POST"
        req.timeoutInterval = TimeInterval(10) // Default is 60 seconds, we run every 30 seconds...
        
        jsDebugLog(body:"Do checkin")
        
        let task = URLSession.shared.dataTask(with: req) { [self] data, response, error in
            
            self.last_checkin_attempted = Int64(Date().timeIntervalSince1970)
            
            guard let rsp = response as? HTTPURLResponse else {
                self.app.logger.warning("Checkin \(self.app.checkin_endpoint!) failed with null response")
                
                jsDebugLog(body: "Bunk checkin response")
                
                self.last_checkin_status = false
                self.handleRelayServerCheckin()
                
                return
            }
            
            if error != nil {
                self.app.logger.error("Checkin \(self.app.checkin_endpoint!) failed with error \(String(describing: error))")
                
                jsDebugLog(body: "Checkin error \(String(describing: error))")
                
                self.last_checkin_status = false
                self.handleRelayServerCheckin()
                return
            }
            
            guard (204) ~= rsp.statusCode else {
                self.app.logger.error("Status code for checkin \(self.app.checkin_endpoint!) should be 204, but is \(rsp.statusCode)")
                
                jsDebugLog(body: "Checkin failed \(rsp.statusCode)")
                
                self.last_checkin_status = false
                self.handleRelayServerCheckin()
                return
            }
            
            self.last_checkin_time = Int64(Date().timeIntervalSince1970)
            self.last_checkin_status = true
            
            self.app.logger.info("Set last checkin as \(self.last_checkin_time)")
            jsDebugLog(body: "Set last checkin as \(self.last_checkin_time)")
            
            self.handleRelayServerCheckin()
        }
        
        jsDebugLog(body:"Start checkin")
        task.resume()
    }
    
    private func handleRelayServerCheckin(){
        
        jsDebugLog(body: "Handle relay server checkin")
        
        if self.last_checkin_attempted == 0 {
            return
        }
        
        // self.app.logger.info("Ensure SSE message last: \(self.last_sse_message) now: \(now)")
        
        var ok = true
        
        if self.last_checkin_status == false {
            jsDebugLog(body: "Hide QR code (no messages from SSE server)")
            ok = false
        }
        
        if ok {
            
            if self.eventSource == nil {
                jsDebugLog(body: "Reconnect to SSE server")
                self.initializeSSEWithCheckin(retry: false, max_tries: -1)
            }
            
            jsDebugLog(body: "Last checkin with relay server was \(self.last_checkin_time)")
            return
        }
        
        jsDebugLog(body: "Disconnect from SSE server")
        self.eventSource?.disconnect()
        self.eventSource = nil
                
        DispatchQueue.main.async {
            // 
        }
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
