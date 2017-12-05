//
//  ViewController.swift
//  BananaLapTime
//
//  Created by Do Duc on 30/11/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

import UIKit
import AVFoundation

final class HomeViewController: UIViewController {

    // MARK: - ---------------------- IBOutlets --------------------------
    //
    @IBOutlet weak var cameraWrapperView: UIView!

    // MARK: - ---------------------- Public Properties --------------------------
    //

    // MARK: - ---------------------- Private Properties --------------------------
    //
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

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

    // MARK: - ---------------------- Private Methods --------------------------
    // fileprivate, private
    private func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            return
        }

        captureSession = AVCaptureSession()

        guard let captureSession = captureSession else {
            return
        }

        captureSession.addInput(input)
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)

        guard let videoPreviewLayer = videoPreviewLayer else {
            return
        }

        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = cameraWrapperView.layer.bounds
        cameraWrapperView.layer.addSublayer(videoPreviewLayer)
        captureSession.startRunning()
    }
}
