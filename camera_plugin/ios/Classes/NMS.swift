// NMS.swift
import Foundation
import CoreGraphics

func nonMaxSuppression(_ detections: [Detection], iouThreshold: Float) -> [Detection] {
    let sorted = detections.sorted { $0.confidence > $1.confidence }
    var keep: [Detection] = []
    
    for det in sorted {
        var overlap = false
        for k in keep {
            let iou = computeIOU(det.rect, k.rect)
            if iou > iouThreshold {
                overlap = true
                break
            }
        }
        if !overlap {
            keep.append(det)
        }
    }
    return keep
}

private func computeIOU(_ a: CGRect, _ b: CGRect) -> Float {
    let intersection = a.intersection(b)
    if intersection.isNull { return 0 }
    
    let intersectArea = intersection.width * intersection.height
    let unionArea = a.width * a.height + b.width * b.height - intersectArea
    
    return Float(intersectArea / unionArea)
}