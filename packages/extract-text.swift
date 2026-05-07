// adapted from https://github.com/kcorey/extract-text

import Vision
import PDFKit


enum FileCategory {
	case pdf
	case image
	case richText
	case plainText
}

func fileCategory(for path: String) -> FileCategory {
	let ext = (path as NSString).pathExtension.lowercased()
	switch ext {
		case "pdf":
			return .pdf
		case "png", "jpg", "jpeg", "tiff", "tif", "heic", "heics", "webp", "gif", "bmp", "jp2", "jxl":
			return .image
		case "docx", "doc", "odt", "rtf", "rtfd":
			return .richText
		default:
			return .plainText
	}
}

/// removes non-displayable Unicode characters while preserving legitimate Unicode
/// (CJK, emoji, accented Latin, Arabic, Cyrillic, etc.)
func sanitizeText(_ text: String) -> String {
	return String(text.unicodeScalars.filter { scalar in
		let cat = scalar.properties.generalCategory

		// remove control characters, except tab/newline/CR
		if cat == .control {
			return scalar.value == 0x09 || scalar.value == 0x0A || scalar.value == 0x0D
		}

		// remove Private Use Area (custom PDF glyphs with no standard rendering)
		if cat == .privateUse { return false }

		// remove format/invisible characters (zero-width spaces, soft hyphens, bidi marks, BOM)
		if cat == .format { return false }

		// remove replacement characters (U+FFFD box-with-question-mark, U+FFFC object replacement)
		if scalar.value == 0xFFFD || scalar.value == 0xFFFC { return false }

		return true
	})
}


func extractPDF(from url: URL) -> String {
	guard let doc = PDFDocument(url: url) else {
		return "[Could not open PDF]"
	}
	return doc.string ?? "[No text found in PDF]"
}

func extractImageOCR(from url: URL) -> String {
	guard let image = NSImage(contentsOf: url),
	      let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
	else {
		return "[Could not load image]"
	}

	let semaphore = DispatchSemaphore(value: 0)
	var recognizedText = ""

	let request = VNRecognizeTextRequest { request, error in
		defer { semaphore.signal() }
		guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
		recognizedText = observations
			.compactMap { $0.topCandidates(1).first?.string }
			.joined(separator: "\n")
	}
	request.recognitionLevel = .accurate
	request.usesLanguageCorrection = true

	let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
	try? handler.perform([request])
	semaphore.wait()

	return recognizedText.isEmpty ? "[No text recognized in image]" : recognizedText
}

func extractRichText(from url: URL) -> String {
	do {
		let attrString = try NSAttributedString(url: url, options: [:], documentAttributes: nil)
		return attrString.string
	} catch {
		return "[Could not read document: \(error.localizedDescription)]"
	}
}

func extractPlainText(from url: URL) -> String {
	if let text = try? String(contentsOf: url, encoding: .utf8) { return text }
	if let text = try? String(contentsOf: url, encoding: .macOSRoman) { return text }
	if let text = try? String(contentsOf: url, encoding: .isoLatin1) { return text }
	return "[Could not read file as text]"
}

func extractText(from path: String) -> String {
	let url = URL(fileURLWithPath: path)
	let raw: String
	switch fileCategory(for: path) {
		case .pdf:       raw = extractPDF(from: url)
		case .image:     raw = extractImageOCR(from: url)
		case .richText:  raw = extractRichText(from: url)
		case .plainText: raw = extractPlainText(from: url)
	}
	return sanitizeText(raw)
}


func combineTexts(from paths: [String]) -> String {
	var sections: [String] = []
	for path in paths {
		let text = extractText(from: path)
		sections.append(text)
	}
	return sections.joined(separator: "\n\n")
}


let args = Array(CommandLine.arguments.dropFirst())
guard !args.isEmpty else {
	fputs("Usage: extract-text <file1> [file2] ...\n", stderr)
	exit(1)
}

print(combineTexts(from: args))
