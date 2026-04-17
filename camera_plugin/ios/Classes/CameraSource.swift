import AVFoundation
import CoreVideo

final class CameraSource: NSObject {

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()

    private var onFrame: ((CVPixelBuffer) -> Void)?
    private let sessionQueue = DispatchQueue(label: "camera.session.queue", qos: .userInitiated)

    override init() {
        super.init()
    }

    // MARK: - Public API

    func start(onFrame: @escaping (CVPixelBuffer) -> Void) {
        self.onFrame = onFrame

        let status = AVCaptureDevice.authorizationStatus(for: .video)

        print("CAMERA AUTH:", status.rawValue)

        switch status {

        case .authorized:
            configureAndStartSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self = self else { return }

                print("CAMERA GRANTED:", granted)

                guard granted else { return }

                self.configureAndStartSession()
            }

        default:
            print("CAMERA DENIED / RESTRICTED")
            return
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }

            if self.session.isRunning {
                self.session.stopRunning()
            }
        }

        onFrame = nil
    }

    // MARK: - Session setup
    private func configureAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            self.session.sessionPreset = .hd1280x720
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: .back),
                let input = try? AVCaptureDeviceInput(device: device) else {
                print("CAMERA DEVICE ERROR")
                self.session.commitConfiguration()
                return
            }
            
            if self.session.inputs.isEmpty {
                self.session.addInput(input)
            }
            
            self.output.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
            self.output.alwaysDiscardsLateVideoFrames = true
            
            if self.output.connection(with: .video) == nil {
                self.output.setSampleBufferDelegate(self,
                                                queue: DispatchQueue(label: "camera.queue",
                                                                        qos: .userInitiated))
                self.session.addOutput(self.output)
            }
            
            // ФИКС ОРИЕНТАЦИИ
            if let connection = self.output.connection(with: .video) {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                if connection.isVideoMirroringSupported {
                    connection.isVideoMirrored = false
                }
            }
            
            self.session.commitConfiguration()
            self.session.startRunning()
            
            print("AVCaptureSession running: \(self.session.isRunning)")
        }
    }
}

// MARK: - Frame output

extension CameraSource: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        onFrame?(pixelBuffer)
    }
}