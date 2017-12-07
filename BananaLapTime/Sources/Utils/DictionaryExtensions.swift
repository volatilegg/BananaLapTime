//
//  DictionaryExtensions.swift
//  BananaLapTime
//
//  Created by Do Duc on 07/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

extension Dictionary where Key == String, Value == Double {
    var display: String {
        var returnedText = ""
        for iterator in self {
            returnedText = returnedText + "\(iterator.value.percentage)%: \(iterator.key)\n"
        }
        return returnedText
    }
}
