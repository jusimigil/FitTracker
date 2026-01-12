import SwiftUI

class ImageManager {
    static let shared = ImageManager()
    
    // Get the folder where we save images
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func saveImage(_ image: UIImage) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        if let data = image.jpegData(compressionQuality: 0.5) {
            do {
                try data.write(to: fileURL)
                return fileName
            } catch {
                print("Error saving image: \(error)")
                return nil
            }
        }
        return nil
    }
    
    func loadImage(fileName: String) -> UIImage? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        do {
            let data = try Data(contentsOf: fileURL)
            return UIImage(data: data)
        } catch {
            print("Error loading image: \(error)")
            return nil
        }
    }
    
    func deleteImage(fileName: String) {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
