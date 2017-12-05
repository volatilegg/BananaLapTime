//
//  ViewController.swift
//  BananaLapTime
//
//  Created by Do Duc on 30/11/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

import UIKit
import AVFoundation
import CoreML

final class HomeViewController: UIViewController {

    // MARK: - ---------------------- IBOutlets --------------------------
    //
    @IBOutlet private weak var cameraWrapperView: UIView!
    @IBOutlet private weak var detailsLabel: UILabel!

    // MARK: - ---------------------- Public Properties --------------------------
    //

    // MARK: - ---------------------- Private Properties --------------------------
    //
    lazy private var captureSession: AVCaptureSession? = {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        return session
    }()

    private var videoPreviewLayer: AVCaptureVideoPreviewLayer? {
        guard let captureSession = self.captureSession else {
            return nil
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        let screenWidth = UIScreen.main.bounds.size.width
        previewLayer.bounds = CGRect(x: 0, y: 0, width: screenWidth, height: screenWidth)
        previewLayer.position = CGPoint.zero
        return previewLayer
    }

    lazy private var inception: Inceptionv3 = {
        let model = Inceptionv3()
        return model
    }()

    // MARK: - ---------------------- UIViewController life cycle --------------------------
    // loadView > viewDidLoad > viewWillAppear > viewWillLayoutSubviews > viewDidLayoutSubviews > viewDidAppear
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
    }

    // MARK: - ---------------------- Route Methods --------------------------
    // @IBActions, prepare(...), ...
    @IBAction func startButtonClicked(_ sender: Any) {
        
    }

    // MARK: - ---------------------- Public Methods --------------------------
    //
    func classifier(image: CVPixelBuffer) {
        guard let predictedResult = try? inception.prediction(image: image) else {
            return
        }

        runOnMainThread { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.detailsLabel.text = predictedResult.classLabel
        }
    }

    // MARK: - ---------------------- Private Methods --------------------------
    // fileprivate, private
    private func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(for: .video), let videoPreviewLayer = videoPreviewLayer, let captureSession = captureSession else {
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }

        captureSession.addInput(input)

        captureSession.beginConfiguration()
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32
        ]
        dataOutput.alwaysDiscardsLateVideoFrames = true
        captureSession.addOutput(dataOutput)
        captureSession.commitConfiguration()

        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = cameraWrapperView.layer.bounds
        cameraWrapperView.layer.addSublayer(videoPreviewLayer)

        let queue = DispatchQueue(label: "com.banana.videoQueue")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        captureSession.startRunning()
    }
}

extension HomeViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = sampleBuffer.image()?.cvBuffer() else {
            return
        }

        classifier(image: buffer)
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    }
}

extension UIImage {
    func cvBuffer() -> CVPixelBuffer? {
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        guard status == kCVReturnSuccess else {
            return nil
        }

        CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(data: pixelData, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

        context?.translateBy(x: 0, y: size.height)
        context?.scaleBy(x: 1.0, y: -1.0)

        UIGraphicsPushContext(context!)
        draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

        return pixelBuffer
    }
}

extension CMSampleBuffer {
    func cvBuffer() -> CVPixelBuffer? {
        guard let buffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }

        return buffer
    }

    func image() -> UIImage? {
        guard let buffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: buffer)
        let image = UIImage(ciImage: ciImage)
        return resize(image: image, newWidth: 299)
    }

    func resize(image: UIImage, ratio: CGFloat) -> UIImage? {
        let newSize: CGSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        return resize(image: image, newSize: newSize)        
    }

    func resize(image: UIImage, newWidth: CGFloat) -> UIImage? {
        let newSize: CGSize = CGSize(width: newWidth, height: newWidth)
        return resize(image: image, newSize: newSize)
    }

    func resize(image: UIImage, newSize: CGSize) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
