import 'dart:typed_data';

class ParsedDocument {
  final String fileName;
  final Uint8List rawBytes;
  final String cleanedText;
  final List<String> chunks;
  final bool requiresVisionFallback;
  final List<int> imageHeavyPageNumbers;
  final int pageCount;

  ParsedDocument({
    required this.fileName,
    required this.rawBytes,
    required this.cleanedText,
    required this.chunks,
    required this.requiresVisionFallback,
    required this.imageHeavyPageNumbers,
    required this.pageCount,
  });

  bool get hasAnyImagePages => imageHeavyPageNumbers.isNotEmpty;
}