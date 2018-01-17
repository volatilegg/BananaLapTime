//
//  ModelType.swift
//  BananaLapTime
//
//  Created by Do Duc on 07/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

import CoreGraphics
import CoreML

enum ModelType: String {
    case inceptionV3
    case googLeNetPlace
    case mobileNet
    case vgg16
    case ageNet
    case food101
    case carRecognition
    case tinyYOLO

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
        case .ageNet:
            return 227
        case .food101:
            return 299
        case .carRecognition:
            return 224
        case .tinyYOLO:
            return 416
        }
    }
}
