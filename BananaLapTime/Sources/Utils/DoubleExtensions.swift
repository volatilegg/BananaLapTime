//
//  DoubleExtensions.swift
//  BananaLapTime
//
//  Created by Do Duc on 07/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

let kPredictionDela: Double = 0.6 // 60%

extension Double {
    var percentage: String {
        let number = (self <= 1) ? (self * 100) : self
        return String(format: "%.2f", number)
    }

    func acceptablePrediction(with otherPrediction: Double) -> Bool {
        if self == 0 || otherPrediction == 0 {
            return false
        }

        if self + kPredictionDela >= otherPrediction || self - kPredictionDela <= otherPrediction {
            return true
        }

        return false
    }
}
