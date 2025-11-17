import Foundation
import UIKit

final class ImageStore {
    static func saveImage(_ image: UIImage, name: String = UUID().uuidString) -> String? {
        let data = image.jpegData(compressionQuality: 0.9) ?? image.pngData()
        guard let data else { return nil }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let file = url.appendingPathComponent(name).appendingPathExtension("jpg")
        do { try data.write(to: file); return file.path } catch { return nil }
    }
}