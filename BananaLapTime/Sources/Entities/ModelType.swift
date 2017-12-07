//
//  ModelType.swift
//  BananaLapTime
//
//  Created by Do Duc on 07/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

import CoreGraphics

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
