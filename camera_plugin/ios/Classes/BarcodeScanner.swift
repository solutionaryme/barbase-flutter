// BarcodeScanner.swift
import AVFoundation
import Vision

final class BarcodeScanner: NSObject {

    // Scan region: center strip, 70% width, 15% height
    private let scanRegionRatio = CGRect(
        x: 0.15,
        y: 0.425,
        width: 0.70,
        height: 0.15
    )

    func scan(_ buffer: CVPixelBuffer) -> [String]? {
        let request = VNDetectBarcodesRequest()

        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up)
        do {
            try handler.perform([request])
        } catch {
            print("Barcode scan error: \(error)")
            return nil
        }

        // CRITICAL FIX: guard must come AFTER perform, not before accessing results
        guard let results = request.results, !results.isEmpty else {
            return nil
        }

        print("Found \(results.count) potential barcodes")

        let roi = scanRegionRatio
        let validCodes: [String] = results.compactMap { observation in
            guard let payload = observation.payloadStringValue else { return nil }
            let bbox = observation.boundingBox
            // Vision bounding boxes are bottom-left origin; CGRect intersection still works
            let inROI = bbox.intersects(roi)
                && bbox.midX >= roi.minX - 0.05
                && bbox.midX <= roi.maxX + 0.05
                && bbox.midY >= roi.minY - 0.05
                && bbox.midY <= roi.maxY + 0.05
            return inROI ? payload : nil
        }

        guard !validCodes.isEmpty else {
            print("No valid codes after ROI filter")
            return nil
        }

        print("Valid codes: \(validCodes)")
        return Array(Set(validCodes))
    }

    func getScanRegion() -> CGRect {
        return scanRegionRatio
    }
}