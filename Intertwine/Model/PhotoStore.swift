import UIKit

/// Event photos the couple picks, saved as JPEGs next to the app's data file.
/// Events refer to them by file name (`WeddingEvent.photoFileName`).
enum PhotoStore {
    /// Longest side of a saved photo, in pixels. Big enough for a full-width cover.
    private static let maxPixelSize: CGFloat = 1600
    private static let cache = NSCache<NSString, UIImage>()

    private static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Shrinks and saves picked image data. Returns the new file name, or nil if it isn't an image.
    static func save(_ data: Data) -> String? {
        guard let original = UIImage(data: data) else { return nil }
        let scale = min(1, maxPixelSize / max(original.size.width, original.size.height))
        let size = CGSize(width: original.size.width * scale, height: original.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            original.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.8) else { return nil }
        let name = UUID().uuidString + ".jpg"
        do {
            try jpeg.write(to: folder.appendingPathComponent(name), options: .atomic)
        } catch {
            print("Couldn't save photo: \(error)")
            return nil
        }
        cache.setObject(resized, forKey: name as NSString)
        return name
    }

    /// The saved JPEG itself, for uploading.
    static func data(named name: String) -> Data? {
        try? Data(contentsOf: folder.appendingPathComponent(name))
    }

    static func image(named name: String) -> UIImage? {
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: folder.appendingPathComponent(name).path) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    // MARK: Photos picked on another phone

    /// Copies of photos that live online (picked on the partner's phone). Kept in Caches, so
    /// iOS may clear them; they're downloaded again on the next sync.
    private static var remoteFolder: URL {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = base.appendingPathComponent("RemotePhotos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private static func remoteFile(_ address: String) -> URL {
        // The address ends in the photo's own unique file name (see Supabase.photoURL).
        let name = URL(string: address)?.lastPathComponent ?? UUID().uuidString
        return remoteFolder.appendingPathComponent(name)
    }

    static func remoteImage(_ address: String) -> UIImage? {
        if let cached = cache.object(forKey: address as NSString) { return cached }
        guard let image = UIImage(contentsOfFile: remoteFile(address).path) else { return nil }
        cache.setObject(image, forKey: address as NSString)
        return image
    }

    /// Downloads any of these photos this phone doesn't have yet. Failures are skipped quietly;
    /// the photo simply shows up after a later sync.
    static func download(_ addresses: [String]) async {
        for address in Set(addresses) where !FileManager.default.fileExists(atPath: remoteFile(address).path) {
            guard let url = URL(string: address),
                  let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  UIImage(data: data) != nil else { continue }
            try? data.write(to: remoteFile(address), options: .atomic)
        }
    }

    /// Deletes saved photos that no event uses any more (replaced, removed or reset).
    static func removeUnused(keeping used: Set<String>) {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        for file in files where !used.contains(file) {
            try? FileManager.default.removeItem(at: folder.appendingPathComponent(file))
            cache.removeObject(forKey: file as NSString)
        }
    }
}
