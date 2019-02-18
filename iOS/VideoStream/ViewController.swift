//
//  ViewController.swift
//  VideoStream
//
//  Created by Eugene G on 2/17/19.
//  Copyright © 2019 Eugene G. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var textViewMessages: UITextView!
    @IBOutlet weak var textFieldInput: UITextField!
    
    var websocket:SRWebSocket?
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let ws = self.websocket {
            ws.close()
            self.websocket = nil
        }
    }
    
    // MARK: - Buttons
    
    @IBAction func sendPing(_ sender: UIBarButtonItem) {
        if let ws = self.websocket {
            ws.sendPing(nil)
        }
    }
    
    @IBAction func reconnect(_ sender: UIBarButtonItem) {
        self.websocket = SRWebSocket(url: URL(string: "ws://localhost:8080/ws"))
        self.websocket?.delegate = self
        self.title = "Opening Connection..."
        self.websocket?.open()
    }
    
    @IBAction func sendMessage(_ sender: UIButton) {
        if let txt = self.textFieldInput.text, txt != "" {
            self.websocket?.send(txt)
        }
    }
}



extension ViewController: SRWebSocketDelegate {
    func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        print("✅Websocket Connected")
        self.title = "Connected"
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        print(":( Websocket Failed With Error \(String(describing: error))")
        self.title = "Connection Failed! (see logs)"
        self.websocket = nil;
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        print("MESSAGE: \(String(describing: message))")
        self.textViewMessages.text = String(describing: message)
    }
    
    func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        print("WebSocket closed")
        self.title = "Connection Closed! (see logs)"
        self.websocket = nil;
    }
    func webSocket(_ webSocket: SRWebSocket!, didReceivePong pongPayload: Data!) {
        print("WebSocket received pong")
    }
}
