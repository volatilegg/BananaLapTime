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
import Vision

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
    @IBOutlet private weak var gridImageView: UIImageView!
    @IBOutlet private weak var detailsLabel: UILabel!
    @IBOutlet private weak var currentObjectLabel: UILabel!
    @IBOutlet private weak var currentModelTypeLabel: UILabel!
    @IBOutlet private weak var lapTimeLabel: UILabel!
    @IBOutlet private weak var lapClockLabel: UILabel!
    @IBOutlet private weak var modelSelectionPickerView: UIPickerView!
    @IBOutlet private weak var selectModelButton: UIButton!

    // MARK: - ---------------------- Public Properties --------------------------
    //

    // MARK: - ---------------------- Private Properties --------------------------
    //
    private let kMinimumLaptime: TimeInterval = 3.0
    private let kLapTimerInterval: TimeInterval = 0.1 // timer only has a resolution 50ms-100ms
    private let kDefaultClockText: String = "00:00:00.0"
    private var prediction: Double = 0
    private var modelType: ModelType = .tinyYOLO {
        didSet {
            guard modelType != oldValue else {
                return
            }

            modelTypeChange()
        }
    }

    private var lapTimer: Timer = Timer()
    private var startTime: Date?
    private var lapRecords: [Record] = [] {
        didSet {
            guard let lapTimeLabel = lapTimeLabel else {
                return
            }

            var lapText = ""
            for (index, lapRecord) in lapRecords.enumerated() {
                lapText = lapText + "\(index+1). \(lapRecord.name): \(lapRecord.lapTime.clockFormat)\n"
            }

            lapTimeLabel.text = lapText
        }
    }

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

    private var state = BananaState.warmUp {
        didSet {
            print("[State]: \(oldValue) ==> \(state)")
            guard state != oldValue else {
                return
            }

            stateDidChange()
        }
    }

    var visionRequest: VNCoreMLRequest?

    lazy private var inception = Inceptionv3()
    lazy private var googleNet = GoogLeNetPlaces()
    lazy private var vgg16 = VGG16()
    lazy private var mobileNet = MobileNet()
    lazy private var ageNet = AgeNet()
    lazy private var food101 = Food101()
    lazy private var tinyYOLO = TinyYOLO()
    lazy private var carRecognition = CarRecognition()

    lazy private var models: [ModelType] = {
        return [ModelType.inceptionV3, ModelType.vgg16, ModelType.googLeNetPlace, ModelType.mobileNet, ModelType.ageNet, ModelType.food101, ModelType.tinyYOLO, ModelType.carRecognition]
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
        modelTypeChange()

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

    @IBAction func selectModelButtonClicked(_ sender: Any) {
        let selectedIndex = modelSelectionPickerView.selectedRow(inComponent: 0)
        guard selectedIndex < models.count else {
            return
        }

        modelType = models[selectedIndex]
    }
    // MARK: - ---------------------- Public Methods --------------------------
    //

    func classifierVGG16(image: CVPixelBuffer) {
        guard let predictedResult = try? vgg16.prediction(image: image) else {
            return
        }

        handlerPredictions(predictedResult.classLabelProbs)
    }

    func classifierGooglePlace(image: CVPixelBuffer) {
        guard let predictedResult = try? googleNet.prediction(sceneImage: image) else {
            return
        }

        handlerPredictions(predictedResult.sceneLabelProbs)
    }

    func classifierInception(image: CVPixelBuffer) {
        guard let predictedResult = try? inception.prediction(image: image) else {
            return
        }

        handlerPredictions(predictedResult.classLabelProbs)
    }

    func classifierMobileNet(image: CVPixelBuffer) {
        guard let predictedResult = try? mobileNet.prediction(image: image) else {
            return
        }
        
        handlerPredictions(predictedResult.classLabelProbs)
    }

    func classifierAgeNet(image: CVPixelBuffer) {
        guard let predictedResult = try? ageNet.prediction(data: image) else {
            return
        }

        handlerPredictions(predictedResult.prob)
    }

    func classifierFood101(image: CVPixelBuffer) {
        guard let predictedResult = try? food101.prediction(image: image) else {
            return
        }

        handlerPredictions(predictedResult.foodConfidence)
    }

    func classifierTinyYOLO(image: CVPixelBuffer) {
        guard let predictedResult = try? tinyYOLO.prediction(image: image) else {
            return
        }

        runOnMainThread { [weak self] in
            guard let strongSelf = self else {
                return
            }

            guard let gridImageView = strongSelf.gridImageView else {
                return
            }

            gridImageView.image = predictedResult.grid.image(offset: 0.0, scale: 416)
        }

        // TODO: Handler grid
        //handlerData(predictedResult: predictedResult.featureNames)
    }

    func classifierCarRecognition(image: CVPixelBuffer) {
        guard let predictedResult = try? carRecognition.prediction(data: image) else {
            return
        }

        handlerPredictions(predictedResult.prob)
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
        videoPreviewLayer.frame = cameraWrapperView.bounds
        cameraWrapperView.layer.addSublayer(videoPreviewLayer)

        if let captureConnection = videoPreviewLayer.connection, captureConnection.isVideoOrientationSupported {
            captureConnection.videoOrientation = AVCaptureVideoOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue) ?? .landscapeLeft
        }

        let queue = DispatchQueue(label: "com.banana.videoQueue")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
        captureSession.startRunning()
    }

    private func setupVision(with coreMLModel: MLModel) {
        guard let visionModel = try? VNCoreMLModel(for: coreMLModel) else {
            return
        }

        visionRequest = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, error in
            guard let strongSelf = self else {
                return
            }

            guard let observations = request.results as? [VNClassificationObservation] else {
                print(error ?? "cc")
                return
            }

            strongSelf.handlerPredictions(observations)
        })

        visionRequest?.imageCropAndScaleOption = .centerCrop
    }

    private func modelTypeChange() {
        currentModelTypeLabel.text = modelType.rawValue

        var coreMLModel: MLModel!

        switch modelType {
        case .inceptionV3:
            coreMLModel = inception.model
        case .googLeNetPlace:
            coreMLModel = googleNet.model
        case .mobileNet:
            coreMLModel = mobileNet.model
        case .vgg16:
            coreMLModel = vgg16.model
        case .ageNet:
            coreMLModel = ageNet.model
        case .carRecognition:
            coreMLModel = carRecognition.model
        case .food101:
            coreMLModel = food101.model
        case .tinyYOLO:
            coreMLModel = tinyYOLO.model
        }

        setupVision(with: coreMLModel)
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
        selectModelButton.isEnabled = true
    }

    private func startState() {
        // Start lapTimer
        startLapTimer()
        selectModelButton.isEnabled = false
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
            /*let alert = UIAlertController(title: "New record added", message: "Lap time for \(selectedObject.name) (\(selectedObject.prediction.percentage)%): \(startTime.timeIntervalSinceNow.clockFormat)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .`default`, handler: { _ in

            }))
            self.present(alert, animated: true, completion: nil)*/
        }

        startTime = nil
        lapTimer.invalidate()
        state = .warmUp
    }

    private func classifierWithVision(sampleBuffer: CMSampleBuffer, model: ModelType) {
        guard let inputData = sampleBuffer.image(newWidth: model.imageSize)?.cgImage else {
            return
        }

        guard let visionRequest = visionRequest else {
            return
        }

        let handler = VNImageRequestHandler(cgImage: inputData, options: [:])
        try? handler.perform([visionRequest])
    }

    private func classifierWithoutVision(sampleBuffer: CMSampleBuffer, model: ModelType) {
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
        case .ageNet:
            classifierAgeNet(image: buffer)
        case .carRecognition:
            classifierCarRecognition(image: buffer)
        case .food101:
            classifierFood101(image: buffer)
        case .tinyYOLO:
            classifierTinyYOLO(image: buffer)
        }
    }

    private func handlerPredictions(_ predictedResults: [String: Double]) {

        runOnMainThread { [weak self] in
            guard let strongSelf = self else {
                return
            }

            let topFive = predictedResults.sorted(by: { $0.value > $1.value }).prefix(5)
            strongSelf.detailsLabel.text = topFive.display

            guard let topObject = topFive.first else {
                return
            }

            // Warmup handler
            if strongSelf.state == .warmUp {
                strongSelf.selectedObject = (name: topObject.key, prediction: topObject.value)
                return
            }

            // Lapping handler
            if strongSelf.state == .lapping {
                guard let startTime = strongSelf.startTime, abs(startTime.timeIntervalSinceNow) > strongSelf.kMinimumLaptime else {
                    return
                }

                for obj in topFive where obj.key == strongSelf.selectedObject.name && obj.value.acceptablePrediction(with: strongSelf.selectedObject.prediction) {
                    strongSelf.state = .end
                }

                return
            }
        }
    }

    private func handlerPredictions(_ predictedResults: [VNClassificationObservation]) {
        let predictions = predictedResults.reduce(into: [String: Double]()) { dict, observation in
            dict[observation.identifier] = Double(observation.confidence)
        }

        handlerPredictions(predictions)
    }
}

extension HomeViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        //classifierWithoutVision(sampleBuffer: sampleBuffer, model: modelType)
        classifierWithVision(sampleBuffer: sampleBuffer, model: modelType)
    }
}

extension HomeViewController: UIPickerViewDelegate {
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        guard row < models.count else {
            return nil
        }

        return models[row].rawValue
    }
}

extension HomeViewController: UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return models.count
    }
}
