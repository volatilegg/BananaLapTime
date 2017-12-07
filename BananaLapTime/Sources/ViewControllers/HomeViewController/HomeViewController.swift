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

enum BananaState: String {
    case warmUp
    case start
    case lapping
    case end
}

final class HomeViewController: UIViewController {

    // MARK: - ---------------------- IBOutlets --------------------------
    //
    @IBOutlet private weak var cameraWrapperView: UIView!
    @IBOutlet private weak var detailsLabel: UILabel!
    @IBOutlet private weak var lapTimeLabel: UILabel!
    @IBOutlet private weak var lapClockLabel: UILabel!

    // MARK: - ---------------------- Public Properties --------------------------
    //

    // MARK: - ---------------------- Private Properties --------------------------
    //
    private static let kMinimumLaptime: TimeInterval = 5.0
    private static let kpredictionDela: Double = 0.2 // 20%

    private var lapTimer: Timer?

    private var state = BananaState.warmUp {
        didSet {
            print("--- \(state) === \(oldValue)")
            guard state != oldValue else {
                return
            }

            stateDidChange()
        }
    }

    // Camera related variable
    lazy private var captureSession: AVCaptureSession? = {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        return session
    }()

    lazy private var inception: Inceptionv3 = {
        let model = Inceptionv3()
        return model
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

    // MARK: - ---------------------- UIViewController life cycle --------------------------
    // loadView > viewDidLoad > viewWillAppear > viewWillLayoutSubviews > viewDidLayoutSubviews > viewDidAppear
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()

        // Initialise state
        stateDidChange()
    }

    // MARK: - ---------------------- Route Methods --------------------------
    // @IBActions, prepare(...), ...
    @IBAction func startButtonClicked(_ sender: Any) {
        state = .start
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

            let topTwo = predictedResult.classLabelProbs.sorted(by: { $0.value > $1.value }).prefix(2)
            strongSelf.detailsLabel.text = topTwo.display
        }
    }

    @objc func updateTimer() {

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

    private func stateDidChange() {
        switch state {
        case .warmUp:
            warmUpState()
        case .start:
            startState()
        case .lapping:
            lappingState()
        case .end:
            endState()
        }
    }

    private func warmUpState() {
        // Lap time for label: top-object

        // Lap time clock stay at 0

    }

    private func startState() {
        // Lap time for label: top-object

        // Start lapTimer
        lapTimer = Timer(fireAt: Date(), interval: 0.01, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
    }

    private func lappingState() {
        // Lap time for label: top-object

        // Lap time clock stay at 0

    }

    private func endState() {
        // Lap time for label: top-object

        // Stop lapTimer
        lapTimer?.invalidate()

        // Update result

    }

    private func startLapTimer() {

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
