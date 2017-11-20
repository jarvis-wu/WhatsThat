//
//  MainViewController.swift
//  WhatsThat
//
//  Created by Zhaowei Wu on 2017-11-19.
//  Copyright © 2017 Zhaowei Wu. All rights reserved.
//

import UIKit
import AVKit
import Vision // an API built on CoreML
import Photos

class MainViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var screenshotButton: UIButton!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo
        guard let captureDevice = AVCaptureDevice.default(for: .video) else { return }
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else { return }
        captureSession.addInput(input)
        captureSession.startRunning()
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.addSublayer(previewLayer)
        previewLayer.frame = cameraView.frame
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        captureSession.addOutput(dataOutput)
        
    }
    
    // MARK: AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // This function get called each time the camera is able to capture a frame
        // print("Frame captured at: ", Date()) // for test
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        guard let model = try? VNCoreMLModel(for: Resnet50().model) else { return }
        let request = VNCoreMLRequest(model: model) { (requestOutput, error) in
            // perhaps catch error here
            
            guard let results = requestOutput.results as? [VNClassificationObservation] else { return }
            guard let firstObservation = results.first else { return }
            // print(firstObservation.identifier, firstObservation.confidence) // for test
            
            // Use dispatch queue here because "updating UI outside main thread is not permitted"
            DispatchQueue.main.async {
                let name = firstObservation.identifier
                let confidence = firstObservation.confidence * 100
                let resultString = "\(name) (\(confidence)%)"
                self.resultLabel.text = resultString
            }

        }
        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([request])
    }
    
    @IBAction func screenshotButtonTapped(_ sender: Any) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            takeScreenshot()
        case .denied, .restricted:
            let alertController = UIAlertController(title: "Photo access denied", message: "Please enable Photos Library access for this appliction in Settings > Privacy.", preferredStyle: UIAlertControllerStyle.alert)
            let actionOK = UIAlertAction(title: "OK", style: .cancel, handler: nil)
            alertController.addAction(actionOK)
            present(alertController, animated: true, completion: nil)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization({ (status) in
                if status == .authorized {
                    self.takeScreenshot()
                }
            })
        }
    }
    
    func takeScreenshot() {
        UIGraphicsBeginImageContext(self.view.frame.size)
        self.view.drawHierarchy(in: self.view.frame, afterScreenUpdates: true)
        //view.layer.render(in: UIGraphicsGetCurrentContext()!)
        if let image = UIGraphicsGetImageFromCurrentImageContext() {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
        UIGraphicsEndImageContext()
        
        // flash the screen here
        DispatchQueue.main.async {
            let flashOverlay = UIView(frame: self.view.frame)
            flashOverlay.backgroundColor = UIColor.white
            self.view.addSubview(flashOverlay)
            UIView.animate(withDuration: 0.5, animations: {
                flashOverlay.alpha = 0.0
            }, completion: { _ in
                flashOverlay.removeFromSuperview()
            })
        }
    }
    

}

