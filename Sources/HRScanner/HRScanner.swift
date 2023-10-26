import SwiftUI

public struct HRScanner {
    
    public init() {
        deleteSavedDataFile()
    }
    
    public var body: some View {
        InstructionsView()
    }
}


// Function to delete the file
func deleteSavedDataFile() {
    
    if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let fileURL = documentsDirectory.appendingPathComponent(StaticText.logsJSONFileName)
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("Error deleting file: \(error)")
        }
    }
}
