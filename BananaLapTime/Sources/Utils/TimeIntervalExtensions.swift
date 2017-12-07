//
//  TimeIntervalExtensions.swift
//  BananaLapTime
//
//  Created by Do Duc on 07/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//
import Foundation

extension Timer {
    var lapTime: String {
        return fireDate.addingTimeInterval(tolerance).timeIntervalSinceNow.clockFormat
    }
}

extension TimeInterval {
    var clockFormat: String {
        let ti = abs(Int32(self))
        let ms = abs(Int32((self.remainder(dividingBy: 1.0) * 10).rounded()))

        let seconds = ti % 60
        let minutes = (ti / 60) % 60
        let hours = (ti / 3600)

        return String(format: "%0.2d:%0.2d:%0.2d.%0.1d", hours, minutes, seconds, ms)
    }
}
