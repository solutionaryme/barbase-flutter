// Detection.swift
import Foundation
import CoreGraphics

struct Detection {
    let rect: CGRect
    let confidence: Float
    let classId: Int
    var skuId: Int?
    
    init(rect: CGRect, confidence: Float, classId: Int, skuId: Int? = nil) {
        self.rect = rect
        self.confidence = confidence
        self.classId = classId
        self.skuId = skuId
    }
}