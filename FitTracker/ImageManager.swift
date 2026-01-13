import SwiftUI
import ImageIO

class ImageManager {
    static let shared = ImageManager()
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // 1. STANDARD SAVE (Unchanged)
    func saveImage(_ image: UIImage) -> String? {
        let fileName = UUID().uuidString + ".jpg"
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // Compress to 0.5 to save disk space immediately
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
    
    // 2. OPTIMIZED LOAD (Downsampling)
    // pointSize: The size you want the image to be on screen (e.g., CGSize(width: 60, height: 60))
    // scale: The screen scale (usually UIScreen.main.scale, which is 2.0 or 3.0)
    func loadImage(fileName: String, pointSize: CGSize? = nil, scale: CGFloat = UIScreen.main.scale) -> UIImage? {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        
        // If no size requested, load full image (Legacy support)
        guard let size = pointSize else {
            do {
                let data = try Data(contentsOf: fileURL)
                return UIImage(data: data)
            } catch {
                return nil
            }
        }
        
        // Low-Memory Downsampling Logic
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height) * scale
        ]
        
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        
        return UIImage(cgImage: thumbnail)
    }
    
    func deleteImage(fileName: String) {
        let fileURL = documentsDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }
}
