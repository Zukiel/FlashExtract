class TextPreprocessor {
  /// Cleans raw extracted text from academic slides and PDFs
  static String cleanText(String rawText) {
    // 1. Remove non-printable characters and weird bullet symbols
    String cleaned = rawText.replaceAll(RegExp(r'[^\x20-\x7E\n]'), ' ');

    // 2. Remove common slide artifacts (e.g., "Page 1 of 20", standalone slide numbers)
    cleaned = cleaned.replaceAll(
  RegExp(r'page\s+\d+\s+of\s+\d+', caseSensitive: false),
  '',
);
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+\s*$', multiLine: true), '');

    // 3. Collapse multiple spaces and excessive newlines
    cleaned = cleaned.replaceAll(RegExp(r'[ \t]+'), ' ');
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
  }

  /// Splits text into safe word-count chunks to prevent token exhaustion
  static List<String> chunkByWordCount(String text, {int maxWords = 1800}) {
    final words = text.split(RegExp(r'\s+'));
    if (words.isEmpty) return [];

    final List<String> chunks = [];
    for (int i = 0; i < words.length; i += maxWords) {
      final end = (i + maxWords < words.length) ? i + maxWords : words.length;
      chunks.add(words.sublist(i, end).join(' '));
    }
    return chunks;
  }
}