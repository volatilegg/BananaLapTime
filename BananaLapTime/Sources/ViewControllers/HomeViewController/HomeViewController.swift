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

enum ModelType {
    case inceptionV3
    case googLeNetPlace
    case mobileNet
    case vgg16

    var imageSize: CGFloat {
        switch self {
        case .inceptionV3:
            return 299
        case .googLeNetPlace:
            return 224
        case .mobileNet:
            return 224
        case .vgg16:
            return 224
        }
    }
}

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
    @IBOutlet private weak var currentObjectLabel: UILabel!
    @IBOutlet private weak var lapTimeLabel: UILabel!
    @IBOutlet private weak var lapClockLabel: UILabel!

    // MARK: - ---------------------- Public Properties --------------------------
    //

    // MARK: - ---------------------- Private Properties --------------------------
    //
    private let kMinimumLaptime: TimeInterval = 3.0
    private let kLapTimerInterval: TimeInterval = 0.1 // timer only has a resolution 50ms-100ms
    private let kDefaultClockText: String = "00:00:00.0"

    private var selectedObject: (name: String, prediction: Double) = (name: "Unknown", prediction: 0) {
        didSet {
            guard selectedObject.name != oldValue.name else {
                return
            }

            guard let currentObjectLabel = currentObjectLabel else {
                return
            }

            currentObjectLabel.text = "Lap for: \(selectedObject.name) \(selectedObject.prediction.percentage)%"
        }
    }

    private var prediction: Double = 0
    private var modelType: ModelType = .vgg16
    private var lapTimer: Timer = Timer()
    private var startTime: Date?
    private var lapRecords: [Record] = [] {
        didSet {
            guard let lapTimeLabel = lapTimeLabel else {
                return
            }

            var lapText = ""
            for (index, lapRecord) in lapRecords.enumerated() {
                lapText = lapText + "\(index). \(lapRecord.name): \(lapRecord.lapTime.clockFormat)\n"
            }

            lapTimeLabel.text = lapText
        }
    }

    private var state = BananaState.warmUp {
        didSet {
            print("[State]: \(oldValue) ==> \(state)")
            guard state != oldValue else {
                return
            }

            stateDidChange()
        }
    }

    lazy private var inception: Inceptionv3 = {
        let model = Inceptionv3()
        return model
    }()

    lazy private var googleNet: GoogLeNetPlaces = {
        let model = GoogLeNetPlaces()
        return model
    }()

    lazy private var vgg16: VGG16 = {
        let model = VGG16()
        return model
    }()

    lazy private var mobileNet: MobileNet = {
        let model = MobileNet()
        return model
    }()

    // Camera related variable
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

    @IBAction func stopButtonClicked(_ sender: Any) {
        state = .end
    }

    // MARK: - ---------------------- Public Methods --------------------------
    //

    func classifierVGG16(image: CVPixelBuffer) {
        guard let predictedResult = try? vgg16.prediction(image: image) else {
            return
        }

        handlerData(predictedResult: predictedResult.classLabelProbs)
    }

    func classifierGooglePlace(image: CVPixelBuffer) {
        guard let predictedResult = try? googleNet.prediction(sceneImage: image) else {
            return
        }

        handlerData(predictedResult: predictedResult.sceneLabelProbs)
    }

    func classifierInception(image: CVPixelBuffer) {
        guard let predictedResult = try? inception.prediction(image: image) else {
            return
        }

        handlerData(predictedResult: predictedResult.classLabelProbs)
    }

    func classifierMobileNet(image: CVPixelBuffer) {
        guard let predictedResult = try? mobileNet.prediction(image: image) else {
            return
        }
        
        handlerData(predictedResult: predictedResult.classLabelProbs)
    }
    @objc func updateTimer() {
        guard let startTime = startTime else {
            return
        }

        lapClockLabel.text = startTime.timeIntervalSinceNow.clockFormat
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
        // Lap time clock stay at 0
        lapClockLabel.text = kDefaultClockText
    }

    private func startState() {
        // Start lapTimer
        startLapTimer()
    }

    private func lappingState() {

    }

    private func endState() {
        // Stop lapTimer
        stopLapTimer()
    }

    private func startLapTimer() {
        startTime = Date()
        lapTimer = Timer.scheduledTimer(timeInterval: kLapTimerInterval, target: self, selector: #selector(updateTimer), userInfo: nil, repeats: true)
        state = .lapping
    }

    private func stopLapTimer() {
        if let startTime = startTime {
            let newRecord = Record(name: selectedObject.name, lapTime: startTime.timeIntervalSinceNow)
            lapRecords.append(newRecord)
        }

        startTime = nil
        lapTimer.invalidate()
        state = .warmUp
    }

    private func classifier(sampleBuffer: CMSampleBuffer, model: ModelType) {
        guard let buffer = sampleBuffer.image(newWidth: model.imageSize)?.cvBuffer() else {
            return
        }

        switch model {
        case .inceptionV3:
            classifierInception(image: buffer)
        case .googLeNetPlace:
            classifierGooglePlace(image: buffer)
        case .mobileNet:
            classifierMobileNet(image: buffer)
        case .vgg16:
            classifierVGG16(image: buffer)
        }
    }

    private func handlerData(predictedResult: [String: Double]) {

        runOnMainThread { [weak self] in
            guard let strongSelf = self else {
                return
            }

            let topTwo = predictedResult.sorted(by: { $0.value > $1.value }).prefix(2)
            strongSelf.detailsLabel.text = topTwo.display

            guard let topObject = topTwo.first else {
                return
            }

            // Warmup handler
            if strongSelf.state == .warmUp {
                strongSelf.selectedObject = (name: topObject.key, prediction: topObject.value)
                return
            }

            // Lapping handler
            if strongSelf.state == .lapping {
                guard topObject.key == strongSelf.selectedObject.name else {
                    return
                }

                guard let startTime = strongSelf.startTime, abs(startTime.timeIntervalSinceNow) > strongSelf.kMinimumLaptime else {
                    return
                }

                if topObject.value.acceptablePrediction(with: strongSelf.selectedObject.prediction) {
                    strongSelf.state = .end
                }

                return
            }
        }
    }
}

extension HomeViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        classifier(sampleBuffer: sampleBuffer, model: modelType)
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

    }
}
