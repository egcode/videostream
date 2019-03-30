//
//  ViewController+Send.swift
//  VideoStream
//
//  Created by Eugene Golovanov on 2/18/19.
//  Copyright © 2019 Eugene G. All rights reserved.
//

import UIKit
import AVFoundation
import VideoToolbox

fileprivate var NALUHeader: [UInt8] = [0, 0, 0, 1]

var counter = 0
var videoData: NSMutableData?

// In fact, most of the hardcoded uses of VideoToolbox are push-streamed NAL Units instead of writing to a local H.264 file.
// If you want to save to local, using AVAssetWriter is a better choice, it will also be hardcoded internally.
func compressionOutputCallback(outputCallbackRefCon: UnsafeMutableRawPointer?,
                               sourceFrameRefCon: UnsafeMutableRawPointer?,
                               status: OSStatus,
                               infoFlags: VTEncodeInfoFlags,
                               sampleBuffer: CMSampleBuffer?) -> Swift.Void {
    guard status == noErr else {
        print("error: \(status)")
        return
    }
    
    if infoFlags == .frameDropped {
        print("frame dropped")
        return
    }
    
    guard let sampleBuffer = sampleBuffer else {
        print("sampleBuffer is nil")
        return
    }
    
    if CMSampleBufferDataIsReady(sampleBuffer) != true {
        print("sampleBuffer data is not ready")
        return
    }
    
    //    let desc = CMSampleBufferGetFormatDescription(sampleBuffer)
    //    let extensions = CMFormatDescriptionGetExtensions(desc!)
    //    print("extensions: \(extensions!)")
    //
    //    let sampleCount = CMSampleBufferGetNumSamples(sampleBuffer)
    //    print("sample count: \(sampleCount)")
    //
    //    let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer)!
    //    var length: Int = 0
    //    var dataPointer: UnsafeMutablePointer<Int8>?
    //    CMBlockBufferGetDataPointer(dataBuffer, 0, nil, &length, &dataPointer)
    //    print("length: \(length), dataPointer: \(dataPointer!)")
    
    let vc: ViewController = Unmanaged.fromOpaque(outputCallbackRefCon!).takeUnretainedValue()
    
    if let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true) {
        print("attachments: \(attachments)")
        
        let rawDic: UnsafeRawPointer = CFArrayGetValueAtIndex(attachments, 0)
        let dic: CFDictionary = Unmanaged.fromOpaque(rawDic).takeUnretainedValue()
        
        // if not contains means it's an IDR frame
        let keyFrame = !CFDictionaryContainsKey(dic, Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque())
        if keyFrame {
            print("IDR frame")
            
            // sps
            let format = CMSampleBufferGetFormatDescription(sampleBuffer)
            var spsSize: Int = 0
            var spsCount: Int = 0
            var nalHeaderLength: Int32 = 0
            var sps: UnsafePointer<UInt8>?
            if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                  0,
                                                                  &sps,
                                                                  &spsSize,
                                                                  &spsCount,
                                                                  &nalHeaderLength) == noErr {
                print("sps: \(String(describing: sps)), spsSize: \(spsSize), spsCount: \(spsCount), NAL header length: \(nalHeaderLength)")
                
                // pps
                var ppsSize: Int = 0
                var ppsCount: Int = 0
                var pps: UnsafePointer<UInt8>?
                
                if CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format!,
                                                                      1,
                                                                      &pps,
                                                                      &ppsSize,
                                                                      &ppsCount,
                                                                      &nalHeaderLength) == noErr {
                    print("sps: \(String(describing: pps)), spsSize: \(ppsSize), spsCount: \(ppsCount), NAL header length: \(nalHeaderLength)")
                    
                    let spsData: NSData = NSData(bytes: sps, length: spsSize)
                    let ppsData: NSData = NSData(bytes: pps, length: ppsSize)
                    
                    // save sps/pps to file
                    // NOTE: In fact, sps/pps does not change much in most cases or changes have little effect on video data.
                    // Therefore, in most cases you can transfer sps/pps data only at the beginning of the file or at the beginning of the video stream.
                    
                    vc.handle(sps: spsData, pps: ppsData)
                }
            }
        } // end of handle sps/pps
        
        // handle frame data
        guard let dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
            return
        }
        
        var lengthAtOffset: Int = 0
        var totalLength: Int = 0
        var dataPointer: UnsafeMutablePointer<Int8>?
        if CMBlockBufferGetDataPointer(dataBuffer, 0, &lengthAtOffset, &totalLength, &dataPointer) == noErr {
            var bufferOffset: Int = 0
            let AVCCHeaderLength = 4
            
            while bufferOffset < (totalLength - AVCCHeaderLength) {
                var NALUnitLength: UInt32 = 0
                // first four character is NALUnit length
                memcpy(&NALUnitLength, dataPointer?.advanced(by: bufferOffset), AVCCHeaderLength)
                
                // big endian to host endian. in iOS it's little endian
                NALUnitLength = CFSwapInt32BigToHost(NALUnitLength)
                
                let data: NSData = NSData(bytes: dataPointer?.advanced(by: bufferOffset + AVCCHeaderLength), length: Int(NALUnitLength))
                vc.encode(data: data, isKeyFrame: keyFrame)
                
                // move forward to the next NAL Unit
                bufferOffset += Int(AVCCHeaderLength)
                bufferOffset += Int(NALUnitLength)
            }
        }
    }
}

extension ViewController {
        
    func viewDidLoadSend() {

        let path = NSTemporaryDirectory() + "/\(counter).h264"
        try? FileManager.default.removeItem(atPath: path)
        if FileManager.default.createFile(atPath: path, contents: nil, attributes: nil) {
            fileHandler = FileHandle(forWritingAtPath: path)
        }
        
        let device = AVCaptureDevice.default(for: .video)!
        let input = try! AVCaptureDeviceInput(device: device)
        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }
        captureSession.sessionPreset = .iFrame960x540
        let output = AVCaptureVideoDataOutput()
        // YUV 420v
        //        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange]
        // BGRA
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        output.setSampleBufferDelegate(self, queue: captureQueue)
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
        }
        
        // not a good method
        if let connection = output.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!
            }
        }
        
        captureSession.startRunning()
        
        // Button Setup
        startButton.addTarget(self, action: #selector(startOrNot), for: .touchUpInside)
    }
    
    func viewDidLayoutSubviewsSend() {
        preview.frame = self.cameraView.bounds
    }
}

extension ViewController {
    @objc func startOrNot() {
        if isCapturing {
            stopCapture()
        } else {
            startCapture()
        }
    }
    
    func startCapture() {
        isCapturing = true
    }
    
    func stopCapture() {
        isCapturing = false
        
        guard let compressionSession = compressionSession else {
            return
        }
        
        VTCompressionSessionCompleteFrames(compressionSession, kCMTimeInvalid)
        VTCompressionSessionInvalidate(compressionSession)
        self.compressionSession = nil
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelbuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        //        if CVPixelBufferIsPlanar(pixelbuffer) {
        //            print("planar: \(CVPixelBufferGetPixelFormatType(pixelbuffer))")
        //        }
        //
        //        var desc: CMFormatDescription?
        //        CMVideoFormatDescriptionCreateForImageBuffer(kCFAllocatorDefault, pixelbuffer, &desc)
        //        let extensions = CMFormatDescriptionGetExtensions(desc!)
        //        print("extensions: \(extensions!)")
        
        if compressionSession == nil {
            let width = CVPixelBufferGetWidth(pixelbuffer)
            let height = CVPixelBufferGetHeight(pixelbuffer)
            
            print("width: \(width), height: \(height)")
            
            VTCompressionSessionCreate(kCFAllocatorDefault,
                                       Int32(width),
                                       Int32(height),
                                       kCMVideoCodecType_H264,
                                       nil, nil, nil,
                                       compressionOutputCallback,
                                       UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
                                       &compressionSession)
            
            guard let c = compressionSession else {
                return
            }
            
            // set profile to Main
            VTSessionSetProperty(c, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel)
            // capture from camera, so it's real time
            VTSessionSetProperty(c, kVTCompressionPropertyKey_RealTime, true as CFTypeRef)
            // key frame interval
            //            VTSessionSetProperty(c, kVTCompressionPropertyKey_MaxKeyFrameInterval, 10 as CFTypeRef)
            VTSessionSetProperty(c, kVTCompressionPropertyKey_MaxKeyFrameInterval, 40 as CFTypeRef)
            
            //            // Bit rate and rate
            //            VTSessionSetProperty(c, kVTCompressionPropertyKey_AverageBitRate, width * height * 2 * 32 as CFTypeRef)
            VTSessionSetProperty(c, kVTCompressionPropertyKey_AverageBitRate, width * height * 2 as CFTypeRef)
            
            
            //            VTSessionSetProperty(c, kVTCompressionPropertyKey_DataRateLimits, [width * height * 2 * 4, 1] as CFArray)
            
            // from 0 to 1
            VTSessionSetProperty(c, kVTCompressionPropertyKey_Quality, 0.1 as CFTypeRef)
            
            VTCompressionSessionPrepareToEncodeFrames(c)
        }
        
        guard let c = compressionSession else {
            return
        }
        
        guard isCapturing else {
            return
        }
        
        compressionQueue.sync {
            pixelbuffer.lock(.readwrite) {
                let presentationTimestamp = CMSampleBufferGetOutputPresentationTimeStamp(sampleBuffer)
                let duration = CMSampleBufferGetOutputDuration(sampleBuffer)
                VTCompressionSessionEncodeFrame(c, pixelbuffer, presentationTimestamp, duration, nil, nil, nil)
            }
        }
    }
    
    func handle(sps: NSData, pps: NSData) {
        counter += 1
        print("⚠️⚠️⚠️⚠️⚠️⚠️⚠️ Real iFrame: \(counter)")
        
        
//        //////////////////////////
//        // V1
//        if let d = videoData {
//            sendVideoData(data: d)
//            videoData = nil
//
//            // Start new GOP from iFrame
////            let headerData: NSData = NSData(bytes: NALUHeader, length: NALUHeader.count)
//            videoData = NSMutableData(bytes: NALUHeader, length: NALUHeader.count) // init with header
//            videoData?.append(sps as Data)
//            videoData?.append(NSData(bytes: NALUHeader, length: NALUHeader.count) as Data) // append header
//            videoData?.append(pps as Data)
//        }
//        // End of V1
//        //////////////////////////

        
        
        //////////////////////////
        // V2
        let headerData1: NSMutableData = NSMutableData(bytes: NALUHeader, length: NALUHeader.count)
        headerData1.append(sps as Data)
        sendVideoData(data: headerData1)
        
        let headerData2: NSMutableData = NSMutableData(bytes: NALUHeader, length: NALUHeader.count)
        headerData2.append(pps as Data)
        sendVideoData(data: headerData2)
        // End of V2
        //////////////////////////

    }
    
    func encode(data: NSData, isKeyFrame: Bool) {
        //        counter += 1
        print("❕ COUNTER22222 Encoded Frame: \(counter)")
        
        
//        //////////////////////////
//        // V1
//        let headerData: NSData = NSData(bytes: NALUHeader, length: NALUHeader.count)
//        if let d = videoData {
//            d.append(headerData as Data)
//            d.append(data as Data)
//        } else {
//            videoData = NSMutableData(bytes: NALUHeader, length: NALUHeader.count) // init with header
//            videoData?.append(data as Data)
//        }
//        // End of V1
//        //////////////////////////
        
        
        
        //////////////////////////
        // V2
        let headerData: NSMutableData = NSMutableData(bytes: NALUHeader, length: NALUHeader.count)
        headerData.append(data as Data)
        sendVideoData(data: headerData)
        // End of V2
        //////////////////////////

    }

    
    func sendVideoData(data:NSMutableData) {
        let base64Data = data.base64EncodedData(options: NSData.Base64EncodingOptions.endLineWithLineFeed)

        self.websocket?.send(base64Data)
//        self.websocket?.send("shit")

    }
}

