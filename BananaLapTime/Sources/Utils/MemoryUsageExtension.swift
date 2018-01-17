//
//  MemoryUsageExtension.swift
//  BananaLapTime
//
//  Created by Do Duc on 17/01/2018.
//  Copyright © 2018 Duc. All rights reserved.
//

import Foundation

func getMemoryUsage() {
    var taskInfo = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
        $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
            task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
        }
    }

    if kerr == KERN_SUCCESS {
        print("Memory used in bytes: \(taskInfo.resident_size)")
    } else {
        print("Error with task_info(): " +
            (String(cString: mach_error_string(kerr), encoding: String.Encoding.ascii) ?? "unknown error"))
    }
}
