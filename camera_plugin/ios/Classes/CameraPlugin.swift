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
        let bufferWidth = CGFloat(CVPixelBufferGetWidth(buffer))   // 720
        let bufferHeight = CGFloat(CVPixelBufferGetHeight(buffer)) // 1280

          aiQueue.async { [weak self] in
            guard let self = self else { return }
            guard capturedNow - self.lastAITime > self.minAIInterval else { return }
            guard !self.aiIsProcessing else { return }
            
            self.lastAITime = capturedNow
            self.aiIsProcessing = true
            
            self.aiPipeline?.processFrame(buffer) { [weak self] detections in
                guard let self = self else { return }
                self.aiIsProcessing = false
                
                let results: [[String: Any]] = detections.compactMap { detection in
                    // Конвертация из 640x640 в координаты кадра
                    let modelSize: CGFloat = 640.0
                    
                    // YOLO вернул координаты относительно 640x640 (с паддингом)
                    var normX = detection.rect.origin.x
                    var normY = detection.rect.origin.y
                    var normW = detection.rect.width
                    var normH = detection.rect.height
                    
                    // Учитываем letterbox/padding который YOLO добавляет
                    // Камера 720x1280 -> YOLO масштабирует до 640x640 с паддингом
                    let frameAspect = bufferWidth / bufferHeight  // 720/1280 = 0.5625
                    let modelAspect: CGFloat = 1.0  // 640/640 = 1.0
                    
                    if frameAspect < modelAspect {
                        // Портретный режим: паддинг по горизонтали
                        let paddedWidth = bufferHeight * modelAspect  // 1280 * 1 = 1280
                        let paddingX = (paddedWidth - bufferWidth) / 2  // (1280-720)/2 = 280
                        
                        // Конвертируем координаты YOLO (640x640) в координаты кадра с паддингом
                        let frameWithPadding = paddedWidth  // 1280
                        let scale = frameWithPadding / modelSize  // 1280/640 = 2.0
                        
                        // YOLO координаты в пикселях кадра с паддингом
                        let pixelX = normX * frameWithPadding - paddingX
                        let pixelY = normY * frameWithPadding
                        let pixelW = normW * frameWithPadding
                        let pixelH = normH * frameWithPadding
                        
                        // Нормализуем обратно к размерам буфера
                        normX = pixelX / bufferWidth
                        normY = pixelY / bufferHeight
                        normW = pixelW / bufferWidth
                        normH = pixelH / bufferHeight
                    } else {
                        // Ландшафтный режим: паддинг по вертикали
                        let paddedHeight = bufferWidth / modelAspect
                        let paddingY = (paddedHeight - bufferHeight) / 2
                        
                        let frameWithPadding = paddedHeight
                        let scale = frameWithPadding / modelSize
                        
                        let pixelX = normX * frameWithPadding
                        let pixelY = normY * frameWithPadding - paddingY
                        let pixelW = normW * frameWithPadding
                        let pixelH = normH * frameWithPadding
                        
                        normX = pixelX / bufferWidth
                        normY = pixelY / bufferHeight
                        normW = pixelW / bufferWidth
                        normH = pixelH / bufferHeight
                    }
                    
                    // Клиппинг
                    normX = max(0, min(1 - normW, normX))
                    normY = max(0, min(1 - normH, normY))
                    normW = min(normW, 1 - normX)
                    normH = min(normH, 1 - normY)
                    
                    print("[CameraPlugin] Adjusted: x=\(normX), y=\(normY), w=\(normW), h=\(normH)")
                    
                    guard normW > 0.02, normH > 0.02 else { return nil }
                    
                    return [
                        "x": normX,
                        "y": normY,
                        "width": normW,
                        "height": normH,
                        "confidence": detection.confidence,
                        "skuId": detection.skuId ?? -1,
                        "classId": detection.classId
                    ]
                }
                
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