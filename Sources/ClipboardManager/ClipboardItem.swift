import Foundation
import SwiftUI
import AppKit
import ImageIO

enum ClipboardContentType: String, Codable {
    case text
    case url
    case color
    case image
    case file
}

struct ClipboardItem: Identifiable, Codable, Equatable {
    let id: UUID
    var text: String
    var type: ClipboardContentType
    var timestamp: Date
    var isPinned: Bool
    var imageData: Data?

    init(text: String, type: ClipboardContentType, imageData: Data? = nil, isPinned: Bool = false) {
        self.id = UUID()
        self.text = text
        self.type = type
        self.timestamp = Date()
        self.isPinned = isPinned
        self.imageData = imageData
    }

    static func detectType(from string: String) -> ClipboardContentType {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmed.contains(where: \.isWhitespace),
           let url = URL(string: trimmed), url.scheme != nil, url.host != nil {
            return .url
        }

        if isHexColor(trimmed) {
            return .color
        }

        return .text
    }

    static func isHexColor(_ string: String) -> Bool {
        guard string.hasPrefix("#") else { return false }
        let digits = string.dropFirst()
        guard digits.count == 6 || digits.count == 3 else { return false }
        return digits.allSatisfy { $0.isASCII && $0.isHexDigit }
    }

    var swiftUIColor: Color? {
        guard type == .color else { return nil }
        var hex = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }

        if hex.count == 3 {
            hex = hex.map { "\($0)\($0)" }.joined()
        }

        guard hex.count == 6, let intVal = Int(hex, radix: 16) else { return nil }
        let r = Double((intVal >> 16) & 0xFF) / 255
        let g = Double((intVal >> 8) & 0xFF) / 255
        let b = Double(intVal & 0xFF) / 255
        return Color(red: r, green: g, blue: b)
    }

    var nsImage: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    private static let thumbnailCache = NSCache<NSUUID, NSImage>()

    var thumbnail: NSImage? {
        let key = id as NSUUID
        if let cached = Self.thumbnailCache.object(forKey: key) { return cached }
        guard let data = imageData,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: 96
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cgImage, size: .zero)
        Self.thumbnailCache.setObject(image, forKey: key)
        return image
    }

    var fileURLs: [URL] {
        guard type == .file else { return [] }
        return text.split(separator: "\n").map { URL(fileURLWithPath: String($0)) }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }()

    func relativeTime(now: Date = Date()) -> String {
        if now.timeIntervalSince(timestamp) < 60 { return "just now" }
        return Self.relativeFormatter.localizedString(for: timestamp, relativeTo: now)
    }

    var previewText: String {
        if type == .file {
            let urls = fileURLs
            guard let first = urls.first else { return text }
            return urls.count > 1 ? "\(first.lastPathComponent) + \(urls.count - 1) more" : first.lastPathComponent
        }
        let head = text.prefix(400)
        let cleaned = head.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        if cleaned.count > 140 || text.count > head.count {
            return String(cleaned.prefix(140)) + "…"
        }
        return cleaned
    }

    var kindLabel: String {
        switch type {
        case .text: return "Text"
        case .url: return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))?.host ?? "Link"
        case .color: return "Color"
        case .image: return "Image"
        case .file: return fileURLs.count > 1 ? "Files" : "File"
        }
    }
}
