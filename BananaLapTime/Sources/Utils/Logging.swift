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

    if !FileManager.default.fileExists(atPath: pathURL.path) {
        FileManager.default.createFile(atPath: pathURL.path, contents: nil, attributes: nil)
        do {
            let fileHandle = try FileHandle(forWritingTo: pathURL)
            fileHandle.write("elapse_time,memory_used,frames_dropped\n".data(using: String.Encoding.utf8)!)
            // Write contents to file
            // try s.write(toFile: pathURL.path, atomically: false, encoding: String.Encoding.utf8)
        } catch let error as NSError {
            print("Ooops! Something went wrong: \(error)")
        }
    }

    do {
        let fileHandle = try FileHandle(forWritingTo: pathURL)
        fileHandle.seekToEndOfFile()

        fileHandle.write("\(s)\n".data(using: String.Encoding.utf8)!)
        // Write contents to file
        // try s.write(toFile: pathURL.path, atomically: false, encoding: String.Encoding.utf8)
    } catch let error as NSError {
        print("Ooops! Something went wrong: \(error)")
    }

}

func getDocumentsDirectory() -> URL {
    let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
    return paths[0]
}
