//
//  ViewController.swift
//  MultiScreen
//
//  Created by asc on 11/6/20.
//

import UIKit
import WebKit

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
