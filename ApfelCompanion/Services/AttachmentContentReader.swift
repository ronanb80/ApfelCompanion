import Foundation
#if canImport(PDFKit)
import PDFKit
#endif

enum AttachmentContentReader {
    static func readFileContent(url: URL) -> String? {
        let maxSize = 100 * 1024 // 100KB limit
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing { url.stopAccessingSecurityScopedResource() }
        }

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let fileSize = attributes[.size] as? Int,
              fileSize <= maxSize else {
            return nil
        }

        if url.pathExtension.lowercased() == "pdf" {
            return readPDFContent(url: url)
        }

        return try? String(contentsOf: url, encoding: .utf8)
    }

    static func readPDFContent(url: URL) -> String? {
        #if canImport(PDFKit)
        guard let document = PDFDocument(url: url) else {
            return nil
        }

        let text = (0..<document.pageCount)
            .compactMap { document.page(at: $0) }
            .map { page in
                let pageText = page.string?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !pageText.isEmpty {
                    return pageText
                }

                let annotationText = page.annotations
                    .compactMap(\.contents)
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return annotationText
            }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        return text.isEmpty ? nil : text
        #else
        return nil
        #endif
    }
}
