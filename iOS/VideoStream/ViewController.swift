//
//  ViewController.swift
//  VideoStream
//
//  Created by Eugene G on 2/17/19.
//  Copyright © 2019 Eugene G. All rights reserved.
//

import UIKit
import AVFoundation
import VideoToolbox

class ViewController: UIViewController {
    
    
    ///////////////////////////////////////////////////////////
    ///////////////////////SEND VIDEO PARAMS///////////////////
    let captureSession = AVCaptureSession()
    let captureQueue = DispatchQueue(label: "videotoolbox.compression.capture")
    let compressionQueue = DispatchQueue(label: "videotoolbox.compression.compression")
    lazy var preview: AVCaptureVideoPreviewLayer = {
        let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
        preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(preview)
        
        return preview
    }()
    var compressionSession: VTCompressionSession?
    var fileHandler: FileHandle?
    var isCapturing: Bool = false
    //////////////////////////////////////////
    
    
    ///////////////////////////////////////////////////////////
    ///////////////////////SEND RECEIVE PARAMS///////////////////
    var formatDesc: CMVideoFormatDescription?
    var decompressionSession: VTDecompressionSession?
    var videoLayer: AVSampleBufferDisplayLayer?
    
    var spsSize: Int = 0
    var ppsSize: Int = 0
    
    var sps: Array<UInt8>?
    var pps: Array<UInt8>?

    ///////////////////////////////////////////////////////////

    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var receivedView: UIView!
    @IBOutlet weak var startButton: UIButton!
    
    var videoFromWebSocketFileHandler: FileHandle?

    
    
    
    @IBOutlet weak var textViewMessages: UITextView!
    @IBOutlet weak var textFieldInput: UITextField!
    
    var websocket:SRWebSocket?
    
    var messagesCount = 0
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if UIImagePickerController.isSourceTypeAvailable(.camera){
            self.viewDidLoadSend()
        } else {
            self.cameraView.backgroundColor = UIColor.red
        }
        
        self.viewDidLoadReceive()

    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if UIImagePickerController.isSourceTypeAvailable(.camera){
            self.viewDidLayoutSubviewsSend()
        } else {
            self.cameraView.backgroundColor = UIColor.red
        }


    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if let ws = self.websocket {
            ws.close()
            self.websocket = nil
        }
    }
    
    // MARK: - Remove keyboard

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let touch = touches.first
        if touch?.phase == UITouchPhase.began {
            touch?.view?.endEditing(true)
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
        if UIImagePickerController.isSourceTypeAvailable(.camera){
            self.websocket = SRWebSocket(url: URL(string: "ws://192.168.1.207:8080/ws"))
        }
        self.websocket?.delegate = self
        self.title = "Opening Connection..."
        self.websocket?.open()
    }
    
    @IBAction func sendMessage(_ sender: UIButton) {
        if let txt = self.textFieldInput.text, txt != "" {
            self.websocket?.send(txt)
            self.textFieldInput.text = ""
        }
    }
}
