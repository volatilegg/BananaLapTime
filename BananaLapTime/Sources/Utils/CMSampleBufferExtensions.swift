//
//  CMSampleBufferExtensions.swift
//  BananaLapTime
//
//  Created by Do Duc on 07/12/2017.
//  Copyright © 2017 Duc. All rights reserved.
//

import UIKit
import AVFoundation

extension CMSampleBuffer {
    func cvBuffer() -> CVPixelBuffer? {
        guard let buffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }

        return buffer
    }

    func image() -> UIImage? {
        guard let buffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }

        let ciImage = CIImage(cvPixelBuffer: buffer)
        let image = UIImage(ciImage: ciImage)
        return resize(image: image, newWidth: 299)
    }

    func resize(image: UIImage, ratio: CGFloat) -> UIImage? {
        let newSize: CGSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
        return resize(image: image, newSize: newSize)
    }

    func resize(image: UIImage, newWidth: CGFloat) -> UIImage? {
        let newSize: CGSize = CGSize(width: newWidth, height: newWidth)
        return resize(image: image, newSize: newSize)
    }

    func resize(image: UIImage, newSize: CGSize) -> UIImage? {
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }
}
