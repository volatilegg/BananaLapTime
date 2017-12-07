//
//  DoubleExtensions.swift
//  BananaLapTime
//
//  Created by Do Duc on 07/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

extension Double {
    var percentage: String {
        let number = (self <= 1) ? (self * 100) : self
        return String(format: "%.2f", number)
    }
}
