import Metal
import MetalPerformanceShaders
import MetalKit
import Vision

protocol ImageProcessor {
    func isBlurry(_ image: UIImage) -> Bool
}

final class ImageProcessorImpl: ImageProcessor {

    private let mtlDevice = MTLCreateSystemDefaultDevice()
    private lazy var mtlCommandQueue = mtlDevice?.makeCommandQueue()

    func isBlurry(_ image: UIImage) -> Bool {
        guard
            let mtlDevice = self.mtlDevice,
            // Create a command buffer for the transformation pipeline
            let commandBuffer = self.mtlCommandQueue?.makeCommandBuffer(),
            let cgImage = image.cgImage
        else {
            return false
        }

        // These are the two built-in shaders we will use
        let laplacian = MPSImageLaplacian(device: mtlDevice)
        let meanAndVariance = MPSImageStatisticsMeanAndVariance(device: mtlDevice)

        // Load the captured pixel buffer as a texture
        let textureLoader = MTKTextureLoader(device: mtlDevice)
        guard let sourceTexture = try? textureLoader.newTexture(cgImage: cgImage, options: nil) else { return false }

        // Create the destination texture for the laplacian transformation
        let lapDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: sourceTexture.pixelFormat, width: sourceTexture.width, height: sourceTexture.height, mipmapped: false)
        lapDesc.usage = [.shaderWrite, .shaderRead]
        guard let lapTex = mtlDevice.makeTexture(descriptor: lapDesc) else { return false }

        // Encode this as the first transformation to perform
        laplacian.encode(commandBuffer: commandBuffer, sourceTexture: sourceTexture, destinationTexture: lapTex)

        // Create the destination texture for storing the variance.
        let varianceTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: sourceTexture.pixelFormat, width: 2, height: 1, mipmapped: false)
        varianceTextureDescriptor.usage = [.shaderWrite, .shaderRead]
        guard let varianceTexture = mtlDevice.makeTexture(descriptor: varianceTextureDescriptor) else { return false }

        // Encode this as the second transformation
        meanAndVariance.encode(commandBuffer: commandBuffer, sourceTexture: lapTex, destinationTexture: varianceTexture)

        // Run the command buffer on the GPU and wait for the results
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // The output will be just 2 pixels, one with the mean, the other the variance.
        var result = [Int8](repeatElement(0, count: 2))
        let region = MTLRegionMake2D(0, 0, 2, 1)
        varianceTexture.getBytes(&result, bytesPerRow: 1 * 2 * 4, from: region, mipmapLevel: 0)
        guard let variance = result.last else { return false }

        return variance < 3
    }

    // MARK: - Similarity

    func kMeansClustering(_ images: [UIImage], numClusters: Int, similarityFunction: (UIImage, UIImage) -> Double) -> [[UIImage]] {
        var centroids = Array(images.prefix(numClusters))

        var clusters: [[UIImage]] = Array(repeating: [], count: numClusters)

        var iterationCount = 0

        while true {
            iterationCount += 1

            for image in images {
                var minDistance = Double.infinity
                var bestCentroidIndex = -1

                for (i, centroid) in centroids.enumerated() {
                    let distance = similarityFunction(image, centroid)

                    if distance < minDistance {
                        minDistance = distance
                        bestCentroidIndex = i
                    }
                }

                clusters[bestCentroidIndex].append(image)
            }

            let oldCentroids = centroids

            for (i, cluster) in clusters.enumerated() {
                if !cluster.isEmpty {
                    let sumOfColors = cluster.reduce(CGFloat(0)) { (result, image) -> CGFloat in
                        let colorComponents = image.averageColor!.cgColor.components!
                        let totalR = CGFloat(colorComponents[0]) + result
                        let totalG = CGFloat(colorComponents[1]) + result
                        let totalB = CGFloat(colorComponents[2]) + result
                        return totalR + totalG + totalB
                    }

                    let newRed = sumOfColors / CGFloat(cluster.count * 3)
                    let newGreen = sumOfColors / CGFloat(cluster.count * 3)
                    let newBlue = sumOfColors / CGFloat(cluster.count * 3)

                    let newAverageColor = UIColor(
                        red: newRed,
                        green: newGreen,
                        blue: newBlue,
                        alpha: 1.0
                    )

                    centroids[i] = UIImage.colorImage(color: newAverageColor, size: centroids[i].size)
                }
            }

            if centroids.elementsEqual(oldCentroids, by: { (image1, image2) -> Bool in
                similarityFunction(image1, image2) == 0.0
            }) {
                break
            }

            clusters = Array(repeating: [], count: numClusters)
        }

        return clusters.filter { !$0.isEmpty }
    }

    private func distance(from source: UIImage, to image: UIImage) -> Float? {
        guard
            let sourceObservation = source.vnFeatureprintObservation,
            let imageObservation = image.vnFeatureprintObservation
        else {
            return nil
        }
        do {
            var distance: Float = 0
            try imageObservation.computeDistance(&distance, to: sourceObservation)
            return distance
        } catch {
            return nil
        }
    }
}

extension UIImage {
    static func colorImage(color: UIColor, size: CGSize) -> UIImage {
        let rect = CGRect(origin: .zero, size: size)

        UIGraphicsBeginImageContextWithOptions(rect.size, false, 0.0)

        color.setFill()
        UIRectFill(rect)

        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return image!
    }

    var vnFeatureprintObservation: VNFeaturePrintObservation? {
        guard let cgImage = self.cgImage else { return nil }
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNGenerateImageFeaturePrintRequest()
        do {
            try requestHandler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    var averageColor: UIColor? {
        guard let inputImage = CIImage(image: self) else { return nil }
        let extentVector = CIVector(x: inputImage.extent.origin.x, y: inputImage.extent.origin.y, z: inputImage.extent.size.width, w: inputImage.extent.size.height)

        guard let filter = CIFilter(name: "CIAreaAverage", parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]) else { return nil }
        guard let outputImage = filter.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext(options: [.workingColorSpace: kCFNull!])
        context.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        return UIColor(red: CGFloat(bitmap[0]) / 255, green: CGFloat(bitmap[1]) / 255, blue: CGFloat(bitmap[2]) / 255, alpha: CGFloat(bitmap[3]) / 255)
    }

    var pixelBuffer: CVPixelBuffer? {
      let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
      var pixelBuffer : CVPixelBuffer?
      let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(self.size.width), Int(self.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
      guard (status == kCVReturnSuccess) else {
        return nil
      }

      CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
      let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)

      let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
      let context = CGContext(data: pixelData, width: Int(self.size.width), height: Int(self.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)

      context?.translateBy(x: 0, y: self.size.height)
      context?.scaleBy(x: 1.0, y: -1.0)

      UIGraphicsPushContext(context!)
      self.draw(in: CGRect(x: 0, y: 0, width: self.size.width, height: self.size.height))
      UIGraphicsPopContext()
      CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))

      return pixelBuffer
    }
}
