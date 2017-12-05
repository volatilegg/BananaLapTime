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

    // MARK: - ---------------------- Internal Properties --------------------------
    //

    // MARK: - ---------------------- UIViewController properties --------------------------
    //

    // MARK: - ---------------------- IBOutlets --------------------------
    //
    @IBOutlet weak var cameraWrapperView: UIView!

    // MARK: - ---------------------- Private Properties --------------------------
    //

    // MARK: - ---------------------- Public Methods --------------------------
    //

    // MARK: - ---------------------- UIViewController life cycle --------------------------
    // loadView > viewDidLoad > viewWillAppear > viewWillLayoutSubviews > viewDidLayoutSubviews > viewDidAppear
    override func viewDidLoad() {
        super.viewDidLoad()

        setupCamera()
    }

    // MARK: - ---------------------- UIViewController Methods --------------------------
    //

    // MARK: - ---------------------- IBActions --------------------------
    //

    // MARK: - ---------------------- Private Methods --------------------------
    //
    private func setupCamera() {
        let captureDevice = AVCaptureDevice.default(for: .video)
        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            print(error)
        }

    }
}
