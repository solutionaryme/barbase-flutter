// CameraPlugin.swift
import Flutter
import AVFoundation
import Vision

public class CameraPlugin: NSObject, FlutterPlugin, FlutterTexture {

    // MARK: - Queues
    // Each pipeline gets its own dedicated serial queue — they never block each other
    private let barcodeQueue = DispatchQueue(label: "pipeline.barcode", qos: .userInitiated)
    private let aiQueue      = DispatchQueue(label: "pipeline.ai",      qos: .userInitiated)

    // MARK: - Throttle timestamps (accessed only from their respective queues)
    private var lastBarcodeTime: CFTimeInterval = 0
    private var lastAITime:      CFTimeInterval = 0

    private let minBarcodeInterval: CFTimeInterval = 1.0 / 15.0  // 15 FPS
    private let minAIInterval:      CFTimeInterval = 1.0 / 2.5   // 4 FPS

    // MARK: - Texture / frame
    private var latestPixelBuffer: CVPixelBuffer?
    private let textureLock = NSLock()

    private var lastFrameTime: CFTimeInterval = 0
    private let minFrameInterval: CFTimeInterval = 1.0 / 30.0    // 30 FPS display

    private var textureId: Int64 = 0

    // MARK: - Registrar / registry
    private var registrar: FlutterPluginRegistrar?
    private var textureRegistry: FlutterTextureRegistry?

    // MARK: - Sub-components
    private var cameraSource:  CameraSource?
    private var barcodeScanner: BarcodeScanner?
    private var aiPipeline:    PipelineOrchestrator?

    // MARK: - AI busy flag (only used by aiQueue, so no lock needed)
    private var aiIsProcessing = false

    // MARK: - Debug counters (aiQueue / barcodeQueue only)
    private var barcodeFrameCount = 0

    // MARK: - Event sinks
    var barcodeEventSink: FlutterEventSink?
    var aiEventSink:      FlutterEventSink?

    // MARK: - Register

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = CameraPlugin()
        instance.registrar      = registrar
        instance.textureRegistry = registrar.textures()

        let channel = FlutterMethodChannel(
            name: "com.yourapp/camera",
            binaryMessenger: registrar.messenger()
        )
        let barcodeChannel = FlutterEventChannel(
            name: "com.yourapp/camera/barcodes",
            binaryMessenger: registrar.messenger()
        )
        let aiChannel = FlutterEventChannel(
            name: "com.yourapp/camera/ai_results",
            binaryMessenger: registrar.messenger()
        )

        registrar.addMethodCallDelegate(instance, channel: channel)
        barcodeChannel.setStreamHandler(BarcodeStreamHandler(instance: instance))
        aiChannel.setStreamHandler(AIStreamHandler(instance: instance))

        instance.textureId = registrar.textures().register(instance)
    }

    // MARK: - Method channel

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {

        case "start":
            print("[Camera] start requested")
            do {
                let locator = ModelLocator(registrar: registrar!)
                aiPipeline    = try PipelineOrchestrator(modelLocator: locator)
                barcodeScanner = BarcodeScanner()
                cameraSource   = CameraSource()

                lastFrameTime = CACurrentMediaTime()

                cameraSource?.start { [weak self] buffer in
                    self?.processFrame(buffer)
                }

                print("[Camera] started, textureId: \(textureId)")
                result(textureId)

            } catch {
                print("[Camera] init error: \(error)")
                result(FlutterError(code: "INIT_ERROR",
                                    message: error.localizedDescription,
                                    details: nil))
            }

        case "loadAllProductsToHNSW":
            if let args = call.arguments as? [[String: Any]] {
                for item in args {
                    if let skuId     = item["skuId"] as? Int,
                       let embedding = item["embedding"] as? [Float] {
                        aiPipeline?.addToIndex(skuId: skuId, embedding: embedding)
                    }
                }
                result(true)
            } else {
                result(false)
            }

        case "getScanRegion":
            if let scanner = barcodeScanner {
                let r = scanner.getScanRegion()
                result(["x": r.origin.x, "y": r.origin.y,
                        "width": r.width,  "height": r.height])
            } else {
                result(nil)
            }

        case "stop":
            print("[Camera] stop requested")
            
            // 1. Отключаем обработку новых кадров
            cameraSource?.stop()
            
            // 2. Очищаем буферы
            textureLock.lock()
            latestPixelBuffer = nil
            textureLock.unlock()
            
            // 3. Отменяем AI операции
            aiPipeline?.cancel()
            aiPipeline = nil
            
            // 4. Очищаем сканеры
            barcodeScanner = nil
            
            // 5. Ждем завершения операций
            let group = DispatchGroup()
            group.enter()
            aiQueue.async {
                group.leave()
            }
            group.enter()
            barcodeQueue.async {
                group.leave()
            }
            
            group.wait(timeout: .now() + 0.5)
            
            print("[Camera] stop completed")
            result(true)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Frame processing

    private func processFrame(_ buffer: CVPixelBuffer) {
        let now = CACurrentMediaTime()

        // --- Texture update (30 FPS) ---
        guard now - lastFrameTime > minFrameInterval else { return }
        lastFrameTime = now

        textureLock.lock()
        latestPixelBuffer = buffer
        textureLock.unlock()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.textureRegistry?.textureFrameAvailable(self.textureId)
        }

        // --- BARCODE pipeline (independent, always active) ---
        // We capture `now` in a local so the async closure uses the same value
        let capturedNow = now
        barcodeQueue.async { [weak self] in
            guard let self = self else { return }
            guard capturedNow - self.lastBarcodeTime > self.minBarcodeInterval else { return }
            self.lastBarcodeTime = capturedNow

            self.barcodeFrameCount += 1
            if self.barcodeFrameCount % 30 == 0 {
                print("[Barcode] scanning… frame #\(self.barcodeFrameCount)")
            }

            guard let scanner = self.barcodeScanner else { return }

            if let codes = scanner.scan(buffer), !codes.isEmpty {
                print("BARCODE FOUND: \(codes)")
                DispatchQueue.main.async {
                    self.barcodeEventSink?(codes)
                }
            }
        }

        // --- AI pipeline (independent, skip if busy) ---
        let bufferWidth  = CVPixelBufferGetWidth(buffer)
        let bufferHeight = CVPixelBufferGetHeight(buffer)

        aiQueue.async { [weak self] in
            guard let self = self else { return }
            guard capturedNow - self.lastAITime > self.minAIInterval else { return }
            // Skip frame if previous inference is still running
            guard !self.aiIsProcessing else { return }

            self.lastAITime    = capturedNow
            self.aiIsProcessing = true
            print("[CameraPlugin] Calling pipeline.processFrame")
            self.aiPipeline?.processFrame(buffer) { [weak self] detections in
            print("[CameraPlugin] Pipeline callback with \(detections.count) detections")
                guard let self = self else { return }
                self.aiIsProcessing = false
                
                print("[CameraPlugin] Received \(detections.count) detections from pipeline")
                
                let results: [[String: Any]] = detections.map {
                    // YOLO уже вернул нормализованные координаты 0...1!
                    let normX = $0.rect.origin.x  // НЕ ДЕЛИТЕ!
                    let normY = $0.rect.origin.y  // НЕ ДЕЛИТЕ!
                    let normW = $0.rect.width     // НЕ ДЕЛИТЕ!
                    let normH = $0.rect.height    // НЕ ДЕЛИТЕ!
                    
                    print("[CameraPlugin] Detection: x=\(normX), y=\(normY), w=\(normW), h=\(normH), conf=\($0.confidence)")
                    
                    // Убедитесь, что координаты не нулевые
                    if normX == 0 && normY == 0 {
                        print("[CameraPlugin] ⚠️ Warning: Detection at (0,0) - possible coordinate issue")
                    }
    
                    // Размеры боксов
                    guard normX >= 0 && normX <= 1.0 && normY >= 0 && normY <= 1.0 &&
                        normW > 0.01 && normH > 0.01 && normW < 1.0 && normH < 1.0 else {
                        print("[CameraPlugin] Filtered out detection")
                        return nil
                    }
                    
                    return [
                        "x": normX,
                        "y": normY,
                        "width": normW,
                        "height": normH,
                        "confidence": $0.confidence,
                        "skuId": $0.skuId ?? -1,
                        "classId": $0.classId
                    ]
                }.compactMap { $0 }
                
                print("[CameraPlugin] Sending \(results.count) results to Flutter")
                self.aiEventSink?(results)
            }
        }
    }

    // MARK: - FlutterTexture

    public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
        textureLock.lock()
        defer { textureLock.unlock() }
        guard let buffer = latestPixelBuffer else { return nil }
        return Unmanaged.passRetained(buffer)
    }
}

// MARK: - Stream Handlers

final class BarcodeStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: CameraPlugin?
    init(instance: CameraPlugin) { plugin = instance }

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("BarcodeStreamHandler: listening")
        plugin?.barcodeEventSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("BarcodeStreamHandler: cancelled")
        plugin?.barcodeEventSink = nil
        return nil
    }
}

final class AIStreamHandler: NSObject, FlutterStreamHandler {
    weak var plugin: CameraPlugin?
    init(instance: CameraPlugin) { plugin = instance }

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("AIStreamHandler: listening")
        plugin?.aiEventSink = events
        return nil
    }
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("AIStreamHandler: cancelled")
        plugin?.aiEventSink = nil
        return nil
    }
}