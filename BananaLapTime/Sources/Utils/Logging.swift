//
//  Logging.swift
//  BananaLapTime
//
//  Created by Do Duc on 22/01/2018.
//  Copyright © 2018 Duc. All rights reserved.
//

import Foundation

func logging(_ s: String, fileName: String) {
    let documents = getDocumentsDirectory()
    let pathURL = documents.appendingPathComponent(fileName)

    /// Create a new log file and insert first header row if file is not exist yet
    /// elapse_time,memory_used,frames_dropped
    if !FileManager.default.fileExists(atPath: pathURL.path) {
        FileManager.default.createFile(atPath: pathURL.path, contents: nil, attributes: nil)
        do {
            let fileHandle = try FileHandle(forWritingTo: pathURL)
            fileHandle.write("elapse_time,memory_used,frames_dropped\n".data(using: String.Encoding.utf8)!)
        } catch let error as NSError {
            print("[LogError]: Ooops! Something went while creating log file file wrong \n[LogError]: \(error)")
        }
    }

    /// Insert log data to the bottom of log file
    do {
        let fileHandle = try FileHandle(forWritingTo: pathURL)
        fileHandle.seekToEndOfFile()

        fileHandle.write("\(s)\n".data(using: String.Encoding.utf8)!)
    } catch let error as NSError {
        print("[LogError] Ooops! Something went wrong while adding content \n[LogError]: \(error)")
    }

}

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}
