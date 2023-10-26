

import Foundation
import AVFoundation


struct VideoSpec {
    var fps: Int32?
}

typealias ImageBufferHandler = ((_ imageBuffer: CMSampleBuffer) -> ())

class HeartRateManager: NSObject {
    
    private let captureSession = AVCaptureSession()
    private var videoDevice: AVCaptureDevice!
    private var videoConnection: AVCaptureConnection!
    
    @Published var cameraAccessDenied = false
    var imageBufferHandler: ImageBufferHandler?
    
    init(preferredSpec: VideoSpec?) {
        super.init()
        // MARK: - Setup Video Format
        do {
            captureSession.sessionPreset = .low
        }
        self.configureCaptureSession()
    }
    
    //MARK: *** Camera Capture Session ***
     func configureCaptureSession() {
         
         if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
             videoDevice = device
         } else if let device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) {
             videoDevice = device
         } else if let device = AVCaptureDevice.default(.builtInTelephotoCamera, for: .video, position: .back) {
             videoDevice = device
         }

        do {
            let input = try AVCaptureDeviceInput(device: videoDevice)
            captureSession.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: DispatchQueue.global(qos: .background))
            captureSession.addOutput(output)
            DispatchQueue.global(qos: .background).async { [weak self] in
                self?.captureSession.startRunning()
            }
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    func startCapture() {
        if captureSession.isRunning {
            print("Capture Session is already running 🏃‍♂️.")
            return
        }
        captureSession.startRunning()
    }
    
    func stopCapture() {
        if !captureSession.isRunning {
            print("Capture Session has already stopped 🛑.")
            return
        }
        captureSession.stopRunning()
    }
}

extension HeartRateManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        if connection.videoOrientation != .portrait {
            connection.videoOrientation = .portrait
            return
        }
        if let imageBufferHandler = imageBufferHandler {
            imageBufferHandler(sampleBuffer)
        }
    }
}
