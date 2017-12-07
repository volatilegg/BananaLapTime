//
//  ArraySliceExtensions.swift
//  BananaLapTime
//
//  Created by Do Duc on 07/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

extension ArraySlice where Element == (key: String, value: Double) {
    var display: String {
        var returnedText = ""
        for element in self {
            returnedText = returnedText + "\(element.value.percentage)%: \(element.key)\n"
        }
        return returnedText
    }
}
