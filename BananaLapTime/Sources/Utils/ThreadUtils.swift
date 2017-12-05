//
//  ThreadUtils.swift
//  BananaLapTime
//
//  Created by Do Duc on 05/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

import Foundation

/// Executing task on background
public func runOnBackGround(task: @escaping () -> Void) {
    DispatchQueue.global(qos: .background).async(execute: task)
}

/// Executing task on main thread
public func runOnMainThread(task: @escaping () -> Void) {
    if Thread.isMainThread {
        task()
    } else {
        DispatchQueue.main.async(execute: task)
    }
}

/// Excuting task on main thread after x seconds
public func runOnMainThread(after: TimeInterval, task: @escaping () -> Void) {
    DispatchQueue.main.asyncAfter(deadline: .now() + after, execute: task)
}
