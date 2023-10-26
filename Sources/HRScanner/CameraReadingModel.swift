
import SwiftUI
import AVFoundation
import CoreGraphics
import VideoToolbox

@objc class CameraReadingModel: NSObject, ObservableObject {
    
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>

    @Published var frame: CGImage?
    @Published var timer = Timer()
    @Published var showAlert = false
    var pulselabel: String = ""
    var pulseTitle: String = StaticText.PlaceYourFinger
    @Published var isTimeStarted: Bool = false
    public var isFingerPlaced = false
    private var hueFilter = HRFilter()
    private var hrDetector = HRDetector()
    var validFrameCounter = 0
    var inputs: [CGFloat] = []
    public var measurementStartedFlag = false
    public var isStartedCapturingPulseRate = false
    private var heartRateManager: HeartRateManager!
    private var skipTime: Int = 0;
    
    override init() {
        super.init()
        //MARK: *** Camera Request ***
        Helper.shared.requestCameraAccess { [self] iscompleted in
            if iscompleted == true {
                heartRateConfigure()
            }else{
               self.showAlert = true
            }
        }
    }
    
    public func heartRateConfigure() {
         let specs = VideoSpec(fps: 30)
         heartRateManager = HeartRateManager(preferredSpec: specs)
         self.heartRateManager.imageBufferHandler = { [unowned self] (imageBuffer) in
             if let pixelBuffer = CMSampleBufferGetImageBuffer(imageBuffer) {
                 if let cgImage = CGImage.create(from: pixelBuffer) {
                     DispatchQueue.main.async {
                         self.frame = cgImage
                     }
                 }
                 self.handle(buffer: imageBuffer)
             } else {
                 print("Failed to obtain pixelBuffer from CMSampleBuffer.")
             }
         }
     }
    
    //MARK: *** Stop Camera Session ***
    func stopRunningCapture() {
        DispatchQueue.main.async {
            self.cameraTourchAction(status: false)
            self.isFingerPlaced = false
            self.isTimeStarted = false
            self.pulseTitle = StaticText.PlaceYourFinger
            self.skipTime = 0
            self.pulselabel = ""
            self.timer.invalidate()
            self.hrDetector.reset()
            self.validFrameCounter = 0
            self.inputs = []
            self.measurementStartedFlag = false
            self.isStartedCapturingPulseRate = false
            self.heartRateManager.stopCapture()
        }
    }
    
    //MARK: *** Camera Flash light ***
     func cameraTourchAction(status: Bool){
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            print("No video capture device available")
            return
        }
        if captureDevice.hasTorch {
            do {
                try captureDevice.lockForConfiguration()
                try captureDevice.setTorchModeOn(level: 1.0)
                captureDevice.torchMode = status ? .on : .off
                captureDevice.unlockForConfiguration()
            } catch {
                print("Error enabling flashlight: \(error.localizedDescription)")
            }
        }
    }
  
}

extension CameraReadingModel {
    
    fileprivate func handle(buffer: CMSampleBuffer) {
        self.cameraTourchAction(status: true)
        var redmean:CGFloat = 0.0;
        var greenmean:CGFloat = 0.0;
        var bluemean:CGFloat = 0.0;

        let pixelBuffer = CMSampleBufferGetImageBuffer(buffer)
        let cameraImage = CIImage(cvPixelBuffer: pixelBuffer!)

        let extent = cameraImage.extent
        let inputExtent = CIVector(x: extent.origin.x, y: extent.origin.y, z: extent.size.width, w: extent.size.height)
        let averageFilter = CIFilter(name: "CIAreaAverage",
                              parameters: [kCIInputImageKey: cameraImage, kCIInputExtentKey: inputExtent])!
        let outputImage = averageFilter.outputImage!

        let ctx = CIContext(options:nil)
        let cgImage = ctx.createCGImage(outputImage, from:outputImage.extent)!

        let rawData:NSData = cgImage.dataProvider!.data!
        let pixels = rawData.bytes.assumingMemoryBound(to: UInt8.self)
        let bytes = UnsafeBufferPointer<UInt8>(start:pixels, count:rawData.length)
        var BGRA_index = 0
        for pixel in UnsafeBufferPointer(start: bytes.baseAddress, count: bytes.count) {
            switch BGRA_index {
            case 0:
                bluemean = CGFloat (pixel)
            case 1:
                greenmean = CGFloat (pixel)
            case 2:
                redmean = CGFloat (pixel)
            case 3:
                break
            default:
                break
            }
            BGRA_index += 1
        }

        let hsv = rgb2hsv((red: redmean, green: greenmean, blue: bluemean, alpha: 1.0))
        
        // MARK: BELOW CONDITION EXAMINE FINGER IS PLACED OVER CAMERA OR NOT
        if (hsv.1 > 0.5 && hsv.2 > 0.5) {
            isFingerPlaced = true
            if !isStartedCapturingPulseRate{
                self.pulseTitle = StaticText.DetectingPulse
            }
           
            DispatchQueue.main.async {
                if !self.measurementStartedFlag {
                    self.startMeasurement()
                }
            }
            validFrameCounter += 1
            inputs.append(hsv.0)
            let filtered = hueFilter.processValue(value: Double(hsv.0))
            
            if validFrameCounter > 60 {
                self.measurementStartedFlag = true
                _ = self.hrDetector.addNewValue(newVal: filtered, atTime: CACurrentMediaTime())
            }
        } else {
            self.pulseTitle = StaticText.PlaceYourFinger
            isFingerPlaced = false
            validFrameCounter = 0
            hrDetector.reset()
            measurementStartedFlag = false
        }
    }
    
    private func startMeasurement() {
        DispatchQueue.main.async {
            // This is important to stop time when called multiple times
            self.timer.invalidate()
            
            self.timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true, block: { [weak self] (timer) in
                guard let self = self else { return }
                let average = self.hrDetector.getAverage()
                let pulse = 60.0/average
                if pulse == -60 {
                    // Check all condition when heart rate is invalid
                    if self.isTimeStarted {
                        self.pulseTitle = self.isFingerPlaced ? StaticText.DetectingPulse : StaticText.PlaceYourFinger
                        if !self.isFingerPlaced {
                            self.timer.invalidate()
                        }
                    } else {
                        self.pulseTitle = StaticText.DetectingPulse
                    }
                    self.isStartedCapturingPulseRate = false
                    print("Invalid pulse rate")
                } else {
                    DispatchQueue.main.async {
                        let actualReading = lround(Double(pulse))
                        // MARK: - SKIPPED 8 SECONDS TO GET MORE ACCURATE READINGs/RESULTs
                        self.pulselabel = self.skipTime <= 8 ? "" : "\(lround(Double(pulse)))"
                        self.isStartedCapturingPulseRate = self.skipTime <= 8 ? false : true
                        // MARK: POST NOTIFICATION TO GET LIVESTREAMING OF HEART RATE ON ANY SCREEN
                        NotificationCenter.default.post(name: Notification.Name.ReadHeartRate, object: actualReading)
                    }
                    self.skipTime += 1
                    print(String(lroundf(pulse)))
                }
            })
        }
    }
    
    // MARK: THIS METHOD IS DEFINED TO INITIATE/START MEASURING HR READING ON ANY SCREEN
    public func initiateHRMeasuring() {
        measurementStartedFlag = true
        heartRateConfigure()
    }

}
