

import SwiftUI


public struct CameraReadingView: View  {
    
    @StateObject private var model = CameraReadingModel()
    @State private var pulseValueCountArray: [PulseValueCount] = []
    @State private var timer: Timer? = nil
    @State private var remainingTime = 60
    var readings : Int
    var backgroundColor : UIColor
    var disclaimerTitle : String
    var disclaimerText : String
    var instruction : String
    @State var isActive = false
    @State private var sumHeartRate = 0
    @State var averageHeartRate: String = ""
    private var timeDuration: Int
    @State private var backBtn: Bool = false
    @State private var count: Int = 0
    @State private var isCameraAppear: Bool = false
    
    public init(remainingTime: Int, readings: Int, backgroundColor: UIColor, disclaimerTitle: String, disclaimerText: String, instruction: String) {
        self.remainingTime = remainingTime
        self.readings = readings
        self.backgroundColor = backgroundColor
        self.disclaimerTitle = disclaimerTitle
        self.disclaimerText = disclaimerText
        self.instruction = instruction
        
        self.timeDuration = remainingTime
    }
    
    public var body: some View {
        NavigationView{
            ZStack{
                Color(Colors.appBackGroundColor).expandIgnoringSafeArea()
                // MARK: *** Disclaimer Text ***
                VStack{
                    
                    Text(StaticText.Disclaimer_title)
                        .font(.system(size: 26))
                        .foregroundColor(.white)
                        .padding(.top,20)
                    Text(StaticText.Disclaimer_txt)
                        .font(.system(size: 20))
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 5, leading: 30, bottom: 0, trailing: 30))
                        .multilineTextAlignment(.center)
                    // MARK: *** Timer Text ***
                    Text(formattedTime)
                        .font(.largeTitle)
                        .frame(maxWidth: .infinity,alignment: .trailing)
                        .foregroundColor(.white)
                        .padding(EdgeInsets(top: 15, leading: 0, bottom: 0, trailing: 30))
                    
                    // MARK: *** Circular Camera ***
                    ZStack(alignment: .top) {
                        FrameView(image: model.frame)
                            .frame(width: 280,height: 280)
                            .clipShape(Circle())
                            .padding(.top,45)
                            .onAppear {
                                isCameraAppear.toggle()
                            }
                            .onDisappear {
                                model.pulseTitle = StaticText.PlaceYourFinger
                                isCameraAppear.toggle()
                            }
                        if isCameraAppear {
                            VStack {
                                Text(model.pulseTitle)
                                    .foregroundColor(.white)
                                    .font(.system(size: 18))
                                    .padding(.top,100)
                                Text(model.pulselabel)
                                    .font(.system(size: 60))
                                    .bold()
                                    .foregroundColor(.white)
                                    .padding(.top, 35)
                            }
                        }
                    }
                    
                    VStack{
                        //MARK: *** Pushed to Phone camera settings ***
                        if model.showAlert == model.showAlert {
                            if #available(iOS 15.0, *) {
                                Text("")
                                    .alert(StaticText.Alert_txt, isPresented: $model.showAlert) {
                                        Button(StaticText.Alertbtn_txt) {
                                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                                if UIApplication.shared.canOpenURL(url) {
                                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                                }
                                            }
                                        }
                                    }
                            }
                        }
                        NavigationLink(destination: ShowMeasurementView(averageHeartRate: averageHeartRate, backBtn: $backBtn, pulseValueCountArray: pulseValueCountArray), isActive: $isActive) {
                            EmptyView()
                        }
                    }
                    Spacer()
                    // MARK: *** Instruction Text ***
                    VStack{
                        Text(StaticText.Instruction_txt)
                            .multilineTextAlignment(.center)
                            .padding(EdgeInsets(top: 0, leading: 30, bottom: 20, trailing: 30))
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                    }
                }
            }
            .onDisappear(perform: {
                model.timer.invalidate()
            })
            .onAppear {
                print(model.measurementStartedFlag)
                
                if isActive {
                    model.pulselabel = ""
                    model.heartRateConfigure()
                    remainingTime = timeDuration
                    if model.measurementStartedFlag && timer == nil {
                        restartTimer()
                    }
                }
            }
        }
        .navigationBarTitle("", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .navigationBarHidden(true)
            .onChangeBackwardsCompatible(of: model.measurementStartedFlag && model.isStartedCapturingPulseRate, perform: { startedFlag in
                if startedFlag && timer == nil {
                    startTimer()
                }
            })
    }
}


struct CameraReadingView_Previews: PreviewProvider {
    static var previews: some View {
        CameraReadingView(remainingTime: 60, readings: 0, backgroundColor: Colors.appBackGroundColor, disclaimerTitle: StaticText.Disclaimer_title, disclaimerText: StaticText.Disclaimer_txt, instruction: StaticText.Instruction_txt)
    }
}


extension CameraReadingView {
    
    var formattedTime: String {
        let seconds = remainingTime % 60
        return String(format: ":%02d", seconds)
    }
    
    // MARK: *** Starting Timer ***
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if remainingTime > 0 {
                if model.isFingerPlaced {
                    model.isTimeStarted = true
                    remainingTime -= 1
                    if let pulseValue = Int(model.pulselabel) {
                        sumHeartRate += pulseValue
                        count += 1
                        pulseValueCountArray.append(PulseValueCount(dateAndTime: getCurrentTimeDate(), pulseValue: pulseValue, timeStamp: getTimeMilliseconds(), count: count))
                    }
                } else {
                    self.timer?.invalidate()
                    self.timer = nil
                }
            } else {
                self.averageHeartRate = "\(sumHeartRate / count)"
                self.timer?.invalidate()
                timer = nil
                model.stopRunningCapture()
                sumHeartRate = 0
                count = 0
                self.isActive.toggle()
            }
        }
    }
    
    func restartTimer() {
        remainingTime = timeDuration
        startTimer()
    }
    
}
