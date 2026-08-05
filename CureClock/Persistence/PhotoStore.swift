//
//  PhotoStore.swift
//  CureClock
//
//  Stores captured/imported photos as JPEG blobs in Documents/Photos and
//  references them by filename only (absolute paths break across reinstalls).
//  A small bounded in-memory cache avoids re-decoding while scrolling. iOS 14 safe.
//

import UIKit

final class PhotoStore {
    static let shared = PhotoStore()

    /// A modern iPhone frame is 12 MP; storing it whole gives a 3–5 MB JPEG and a
    /// ~48 MB decoded bitmap for a thumbnail nobody views larger than 200 pt.
    private let maxDimension: CGFloat = 1600
    private let jpegQuality: CGFloat = 0.8

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        // Unbounded, an album's worth of full-resolution bitmaps sits in memory.
        cache.countLimit = 40
        cache.totalCostLimit = 32 * 1024 * 1024      // bytes of decoded bitmap
    }

    private var photosDir: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: base.path) {
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        }
        return base
    }

    @discardableResult
    func save(_ image: UIImage) -> String? {
        let name = "\(UUID().uuidString).jpg"
        let scaled = Self.downscaled(image, maxDimension: maxDimension)
        guard let data = scaled.jpegData(compressionQuality: jpegQuality) else { return nil }
        let url = photosDir.appendingPathComponent(name)
        do {
            try data.write(to: url, options: [.atomic])
            store(scaled, as: name)
            return name
        } catch { return nil }
    }

    func loadImage(named name: String?) -> UIImage? {
        guard let name = name else { return nil }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        let url = photosDir.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        store(image, as: name)
        return image
    }

    func delete(named name: String?) {
        guard let name = name else { return }
        cache.removeObject(forKey: name as NSString)
        try? FileManager.default.removeItem(at: photosDir.appendingPathComponent(name))
    }

    func clearAll() {
        cache.removeAllObjects()
        if let files = try? FileManager.default.contentsOfDirectory(at: photosDir, includingPropertiesForKeys: nil) {
            files.forEach { try? FileManager.default.removeItem(at: $0) }
        }
    }

    // MARK: - Helpers

    private func store(_ image: UIImage, as name: String) {
        cache.setObject(image, forKey: name as NSString, cost: Self.byteCost(of: image))
    }

    private static func byteCost(of image: UIImage) -> Int {
        let px = image.size.width * image.scale * image.size.height * image.scale
        return Int(px * 4)
    }

    /// Proportionally shrinks so the longest edge is at most `maxDimension`.
    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = maxDimension / longest
        let target = CGSize(width: (size.width * scale).rounded(),
                            height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
