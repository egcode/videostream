//
//  ViewController+WebSocket.swift
//  VideoStream
//
//  Created by Eugene G on 2/17/19.
//  Copyright © 2019 Eugene G. All rights reserved.
//

import UIKit

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
        if let m = message as? String {
            let newNessage = "\(self.messagesCount). \(m)"
            if self.messagesCount == 0 {
                self.textViewMessages.text = newNessage
                self.messagesCount += 1
            } else {
                self.textViewMessages.text += "\n\(newNessage)"
                self.messagesCount += 1
            }
        } else {
            print("Error: \(String(describing: message))")
        }
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
