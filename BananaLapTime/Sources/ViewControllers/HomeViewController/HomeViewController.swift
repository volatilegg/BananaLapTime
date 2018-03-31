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
    @IBOutlet private weak var detailsLabel: UILabel!
    @IBOutlet private weak var currentObjectLabel: UILabel!
    @IBOutlet private weak var currentModelTypeLabel: UILabel!
    @IBOutlet private weak var lapTimeLabel: UILabel!
    @IBOutlet private weak var lapClockLabel: UILabel!
    @IBOutlet private weak var memoryUsageLabel: UILabel!
    @IBOutlet private weak var elapsedTimeLabel: UILabel!
    @IBOutlet private weak var framesDropLabel: UILabel!
    @IBOutlet private weak var modelSelectionPickerView: UIPickerView!
    @IBOutlet private weak var selectModelButton: UIButton!

    // MARK: - ---------------------- Private Properties --------------------------
    //
    private let kMinimumLaptime: TimeInterval = 3.0
    private let kLapTimerInterval: TimeInterval = 0.1 // timer only has a resolution 50ms-100ms
    private let kMemoryTimerInterval: TimeInterval = 1.0
    private let kDefaultClockText: String = "00:00:00.0"
    private var prediction: Double = 0
    private var useVision: Bool = true
    private var fileName: String = "dummy-\(Int(Date.timeIntervalSinceReferenceDate)).txt"
    private var framesDropped: Int = 0 {
        didSet {
            handlerFrameDropped()
        }
    }

    private var processTime: Double? {
        didSet {
            guard let processTime = processTime else {
                return
            }

            handlerProcessTime(processTime)
        }
    }
    private var modelType: ModelType = .inceptionV3 {
        didSet {
            guard modelType != oldValue else {
                return
            }

            modelTypeChange()
        }
    }

    private var lapTimer: Timer = Timer()
    private var memoryTimer: Timer = Timer()
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
    lazy private var yolo = YOLO()
    lazy private var fruitResNet = FruitClassifierResNet()
    lazy private var fruitSqueezeNet = FruitClassifierSqueezeNet()

    lazy private var models: [ModelType] = {
        return [ModelType.inceptionV3, ModelType.vgg16, ModelType.googLeNetPlace, ModelType.mobileNet, ModelType.ageNet, ModelType.food101, ModelType.tinyYOLO, ModelType.carRecognition, ModelType.fruitResNet, ModelType.fruitSqueezeNet]
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
        setUpBoundingBoxes()
        setupCamera()
        setUpMemoryDisplay()
        modelTypeChange()

        // Initialise state
        stateDidChange()
    }

    deinit {
        lapTimer.invalidate()
        memoryTimer.invalidate()
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

    @IBAction func visionSegmentControlValueChanged(_ sender: Any) {
        useVision.toggle()
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

    func classifierFruitResNet(image: CVPixelBuffer) {
        guard let predictedResult = try? fruitResNet.prediction(image: image) else {
            return
        }

        handlerPredictions(predictedResult.fruitProbability)
    }

    func classifierFruitSqueezeNet(image: CVPixelBuffer) {
        guard let predictedResult = try? fruitSqueezeNet.prediction(image: image) else {
            return
        }

        handlerPredictions(predictedResult.fruitProbability)
    }

    var boundingBoxes = [BoundingBox]()
    var colors: [UIColor] = []

    func classifierTinyYOLO(image: CVPixelBuffer) {
        guard let predictedResult = try? yolo.predict(image: image) else {
            return
        }

        runOnMainThread { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.show(predictions: predictedResult)
            //gridImageView.image = predictedResult.grid.image(offset: 0.0, scale: 416)
        }

        // TODO: Handler grid
        //handlerData(predictedResult: predictedResult.featureNames)
    }

    func show(predictions: [YOLO.Prediction]) {
        for i in 0..<boundingBoxes.count {
            if i < predictions.count {
                let prediction = predictions[i]

                // The predicted bounding box is in the coordinate space of the input
                // image, which is a square image of 416x416 pixels. We want to show it
                // on the video preview, which is as wide as the screen and has a 4:3
                // aspect ratio. The video preview also may be letterboxed at the top
                // and bottom.
                let width = cameraWrapperView.frame.width
                let height = width 
                let scaleX = width / CGFloat(YOLO.inputWidth)
                let scaleY = height / CGFloat(YOLO.inputHeight)
                let top = (cameraWrapperView.frame.height - height) / 2

                // Translate and scale the rectangle to our own coordinate system.
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY

                // Show the bounding box.
                let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                let color = colors[prediction.classIndex]
                boundingBoxes[i].show(frame: rect, label: label, color: color)
            } else {
                boundingBoxes[i].hide()
            }
        }
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
    private func setUpBoundingBoxes() {
        for _ in 0..<YOLO.maxBoundingBoxes {
            boundingBoxes.append(BoundingBox())
        }

        // Make colors for the bounding boxes. There is one color for each class,
        // 20 classes in total.
        for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
            for g: CGFloat in [0.3, 0.7] {
                for b: CGFloat in [0.4, 0.8] {
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1)
                    colors.append(color)
                }
            }
        }
    }

    private func setUpMemoryDisplay() {
        memoryTimer = Timer.scheduledTimer(timeInterval: kMemoryTimerInterval, target: self, selector: #selector(updateMemoryUsage), userInfo: nil, repeats: true)
    }

    @objc private func updateMemoryUsage() {
        memoryUsageLabel.text = getMemoryUsage()
    }

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

        // Add the bounding box layers to the UI, on top of the video preview.
        /*for box in self.boundingBoxes {
            box.addToLayer(cameraWrapperView.layer)
        }*/

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

        visionRequest = VNCoreMLRequest(model: visionModel, completionHandler: { [weak self] request, _ in
            let processStartTime = CACurrentMediaTime()

            defer {
                let processEndTime = CACurrentMediaTime()
                self?.processTime = processEndTime - processStartTime
            }

            guard let strongSelf = self else {
                return
            }

            if let observations = request.results as? [VNClassificationObservation] {
                strongSelf.handlerPredictions(observations)
                return
            }

            /*if let observation = request.results?.first as? VNCoreMLFeatureValueObservation, let mlMultiArray = observation.featureValue.multiArrayValue {
                let boundingBoxes = strongSelf.yolo.computeBoundingBoxes(features: mlMultiArray)
                runOnMainThread {
                    strongSelf.show(predictions: boundingBoxes)
                }

            }*/

        })

        visionRequest?.imageCropAndScaleOption = .scaleFill
    }

    private func modelTypeChange() {

        currentModelTypeLabel.text = modelType.rawValue
        fileName = "\(modelType.rawValue)-\(Int(Date.timeIntervalSinceReferenceDate)).txt"
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
        case .fruitResNet:
            coreMLModel = fruitResNet.model
        case .fruitSqueezeNet:
            coreMLModel = fruitSqueezeNet.model
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
        let processStartTime = CACurrentMediaTime()

        defer {
            let processEndTime = CACurrentMediaTime()
            processTime = processEndTime - processStartTime
        }

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
        case .fruitResNet:
            classifierFruitResNet(image: buffer)
        case .fruitSqueezeNet:
            classifierFruitSqueezeNet(image: buffer)
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

    private func handlerProcessTime(_ processTime: Double) {
        runOnMainThread { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.elapsedTimeLabel.text = String(format: "Elapsed time: %.8f s", processTime)
            logging("\(processTime),\(getMemoryUsage()),\(strongSelf.framesDropped)", fileName: strongSelf.fileName)
            //print("[Process]: \(processTime) seconds")
        }
    }

    private func handlerFrameDropped() {
        runOnMainThread { [weak self] in
            guard let strongSelf = self else {
                return
            }

            strongSelf.framesDropLabel.text = "Frames dropped: \(strongSelf.framesDropped)"
            //print("[Frames drop]: \(self.framesDropped)")
        }
    }
}

extension HomeViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {

        guard useVision else {
            classifierWithoutVision(sampleBuffer: sampleBuffer, model: modelType)
            return
        }
        
        classifierWithVision(sampleBuffer: sampleBuffer, model: modelType)
    }

    func captureOutput(_ output: AVCaptureOutput, didDrop sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        framesDropped += 1
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
