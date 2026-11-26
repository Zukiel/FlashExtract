import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'parsed_document.dart';
import 'text_preprocessor.dart';
import 'dart:ui';

class PdfExtractionService {
  /// Picks a PDF file on Web and extracts/cleans its text
  Future<ParsedDocument?> pickAndExtractPdf() async {
    final PlatformFile? file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (file == null) {
      return null; // User canceled picker
    }

    final Uint8List bytes = await file.readAsBytes();
    return extractFromBytes(bytes, file.name);
  }
/// Builds a lightweight PDF containing ONLY the flagged image-heavy pages
  /// so we don't base64-encode and upload an entire 20-page file.
  Future<Uint8List> extractImagePagesAsPdf(
    Uint8List originalBytes,
    List<int> oneIndexedPages,
  ) async {
    final PdfDocument sourceDoc = PdfDocument(inputBytes: originalBytes);
    final PdfDocument subsetDoc = PdfDocument();
    subsetDoc.pageSettings.margins.all = 0;

    for (final pageNum in oneIndexedPages) {
      final int zeroIndex = pageNum - 1;
      if (zeroIndex >= 0 && zeroIndex < sourceDoc.pages.count) {
        final PdfPage sourcePage = sourceDoc.pages[zeroIndex];
        final PdfTemplate template = sourcePage.createTemplate();

        subsetDoc.pageSettings.size = sourcePage.size;
        subsetDoc.pageSettings.orientation =
            sourcePage.size.width > sourcePage.size.height
                ? PdfPageOrientation.landscape
                : PdfPageOrientation.portrait;

        final PdfPage newPage = subsetDoc.pages.add();
        newPage.graphics.drawPdfTemplate(template, Offset.zero);
      }
      // Yield briefly to keep Flutter Web UI responsive
      await Future.delayed(Duration.zero);
    }

    final List<int> savedBytes = await subsetDoc.save();
    sourceDoc.dispose();
    subsetDoc.dispose();

    return Uint8List.fromList(savedBytes);
  }
  /// Pure extraction method that flags both full-scan PDFs and mixed diagram pages
  Future<ParsedDocument> extractFromBytes(Uint8List bytes, String fileName) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final int pageCount = document.pages.count;
    final PdfTextExtractor extractor = PdfTextExtractor(document);

    final StringBuffer rawBuffer = StringBuffer();
    final List<int> imageHeavyPages = [];

    for (int i = 0; i < pageCount; i++) {
      final String pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);

      // Record 1-indexed page numbers that appear to be scans or image-only diagrams
      if (pageText.trim().length < 50) {
        imageHeavyPages.add(i + 1);
      }
      rawBuffer.writeln(pageText);
    }

    document.dispose();

    final String cleaned = TextPreprocessor.cleanText(rawBuffer.toString());
    final List<String> chunks = TextPreprocessor.chunkByWordCount(cleaned);

    // Flag full Vision fallback if >40% of pages lack selectable text
    final bool needsFullVision =
        pageCount > 0 && (imageHeavyPages.length / pageCount) > 0.4;

    return ParsedDocument(
      fileName: fileName,
      rawBytes: bytes,
      cleanedText: cleaned,
      chunks: chunks,
      requiresVisionFallback: needsFullVision,
      imageHeavyPageNumbers: imageHeavyPages,
      pageCount: pageCount,
    );
  }
  /// Picks one or more PDF files on Web and extracts/cleans their text
  Future<List<ParsedDocument>> pickAndExtractMultiplePdfs() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (files.isEmpty) {
      return []; // User canceled picker
    }

    final List<ParsedDocument> extractedDocs = [];
    for (final file in files) {
      final Uint8List bytes = await file.readAsBytes();
      final ParsedDocument doc = await extractFromBytes(bytes, file.name);
      extractedDocs.add(doc);
    }

    return extractedDocs;
  }
}