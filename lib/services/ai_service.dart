import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/question_answer.dart';
import 'document_parser/parsed_document.dart';
import 'document_parser/pdf_extraction_service.dart';

class AiService {
  final String apiKey;
  final PdfExtractionService _pdfHelper = PdfExtractionService();

  DateTime? _lastRequestStartTime;
  static const Duration _minRequestInterval = Duration(milliseconds: 4200);

  AiService({required this.apiKey});

  static const String _endpoint =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent';

  /// Enforces a minimum 4.2s start-to-start interval to stay under 15 RPM
  Future<void> _paceRequest() async {
    if (_lastRequestStartTime != null) {
      final elapsed = DateTime.now().difference(_lastRequestStartTime!);
      if (elapsed < _minRequestInterval) {
        await Future.delayed(_minRequestInterval - elapsed);
      }
    }
    _lastRequestStartTime = DateTime.now();
  }

  Future<List<QuestionAnswer>> generateFlashcardsFromBatch(
    List<ParsedDocument> docs, {
    int targetTotalCards = 15,
    void Function(String status)? onProgress,
  }) async {
    if (docs.isEmpty) return [];

    final List<QuestionAnswer> allCards = [];
    final int cardsPerDoc = (targetTotalCards / docs.length).ceil().clamp(3, 50);

    for (int d = 0; d < docs.length; d++) {
      final doc = docs[d];
      onProgress?.call('Processing "${doc.fileName}" (${d + 1}/${docs.length})...');

      // Route 1: Scan-heavy PDF -> Full document Vision pass
      if (doc.requiresVisionFallback) {
        final cards = await _callGeminiMultimodal(
          pdfBytes: doc.rawBytes,
          cardCount: cardsPerDoc,
          instruction:
              'Extract key academic concepts, diagrams, and notes from "${doc.fileName}" '
              'into exactly $cardsPerDoc concise study flashcards.',
        );
        allCards.addAll(cards);
        continue;
      }

      // Dynamic proportional split: 25% of doc budget goes to diagram pages if present
      final int chunkCount = doc.chunks.isEmpty ? 1 : doc.chunks.length;
      final int imageBudget = doc.hasAnyImagePages
          ? (cardsPerDoc * 0.25).round().clamp(2, 10)
          : 0;
      final int textBudget = (cardsPerDoc - imageBudget).clamp(2, 50);
      final int cardsPerChunk = (textBudget / chunkCount).ceil().clamp(1, 30);

      // Route 2: Digital text chunks
      for (int i = 0; i < doc.chunks.length; i++) {
        final chunkCards = await _callGeminiTextOnly(
          doc.chunks[i],
          cardCount: cardsPerChunk,
        );
        allCards.addAll(chunkCards);
      }

      // Route 3: Mixed PDF -> Slice image-heavy pages and generate proportional visual cards
      if (doc.hasAnyImagePages) {
        onProgress?.call(
          'Extracting ${doc.imageHeavyPageNumbers.length} image page(s) from "${doc.fileName}"...',
        );
        final Uint8List imageOnlyPdfBytes = await _pdfHelper.extractImagePagesAsPdf(
          doc.rawBytes,
          doc.imageHeavyPageNumbers,
        );

        final diagramCards = await _callGeminiMultimodal(
          pdfBytes: imageOnlyPdfBytes,
          cardCount: imageBudget,
          instruction:
              'These pages contain diagrams or images from "${doc.fileName}". '
              'Extract $imageBudget study flashcards explaining the visual concepts shown.',
        );
        allCards.addAll(diagramCards);
      }
    }

    // Enforce exact target count while keeping representation balanced across files
    if (allCards.length > targetTotalCards) {
      allCards.shuffle();
      return allCards.sublist(0, targetTotalCards);
    }

    return allCards;
  }

  Map<String, dynamic> _buildGenerationConfig() {
    return {
      'responseMimeType': 'application/json',
      'responseSchema': {
        'type': 'OBJECT',
        'properties': {
          'cards': {
            'type': 'ARRAY',
            'items': {
              'type': 'OBJECT',
              'properties': {
                'q': {'type': 'STRING'},
                'a': {'type': 'STRING'},
              },
              'required': ['q', 'a'],
            },
          },
        },
        'required': ['cards'],
      },
      'maxOutputTokens': 8192,
      'temperature': 0.3,
    };
  }

  Future<List<QuestionAnswer>> _callGeminiTextOnly(
    String textChunk, {
    required int cardCount,
  }) async {
    final prompt = '''
Generate exactly $cardCount high-impact active-recall Q&A flashcards covering distinct concepts from the lecture text below.
Keep each question and answer concise (1-2 sentences max).

Lecture Text:
$textChunk
''';

    return _sendRequest({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': _buildGenerationConfig(),
    });
  }

  Future<List<QuestionAnswer>> _callGeminiMultimodal({
    required Uint8List pdfBytes,
    required int cardCount,
    required String instruction,
  }) async {
    final String base64Pdf = base64Encode(pdfBytes);

    final prompt = '''
$instruction
Keep each question and answer concise (1-2 sentences max).
''';

    return _sendRequest({
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'application/pdf',
                'data': base64Pdf,
              }
            }
          ]
        }
      ],
      'generationConfig': _buildGenerationConfig(),
    });
  }

  Future<List<QuestionAnswer>> _sendRequest(Map<String, dynamic> body) async {
    await _paceRequest();

    final client = http.Client();
    try {
      final response = await client.post(
        Uri.parse('$_endpoint?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 429) {
        throw Exception('Free API rate limit reached. Wait 30 seconds and try again.');
      }
      if (response.statusCode != 200) {
        throw Exception('Gemini API Error (${response.statusCode}): ${response.body}');
      }

      final decoded = jsonDecode(response.body);
      String rawJsonText =
          decoded['candidates'][0]['content']['parts'][0]['text'];

      rawJsonText = rawJsonText
          .replaceAll(RegExp(r'^```json\s*', multiLine: true), '')
          .replaceAll(RegExp(r'^```\s*', multiLine: true), '')
          .trim();

      final Map<String, dynamic> parsedJson = _safeDecodeJson(rawJsonText);
      final List<dynamic> cardsList = parsedJson['cards'] ?? [];

      return List.generate(cardsList.length, (index) {
        final item = cardsList[index];
        return QuestionAnswer(
          id: '${DateTime.now().microsecondsSinceEpoch}_$index',
          question: (item['q'] ?? '').toString().trim(),
          answer: (item['a'] ?? '').toString().trim(),
        );
      });
    } catch (e, stackTrace) {
      debugPrint('=== AiService Error ===\n$e\n$stackTrace');
      rethrow;
    } finally {
      client.close();
    }
  }

  Map<String, dynamic> _safeDecodeJson(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      final int lastCompleteObj = raw.lastIndexOf('}');
      if (lastCompleteObj != -1) {
        final String salvaged = '${raw.substring(0, lastCompleteObj + 1)}]}';
        try {
          return jsonDecode(salvaged) as Map<String, dynamic>;
        } catch (_) {}
      }
      rethrow;
    }
  }
}