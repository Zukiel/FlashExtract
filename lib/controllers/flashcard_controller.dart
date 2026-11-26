import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/question_answer.dart';
import '../services/spaced_repetition_service.dart';
import '../services/document_parser/pdf_extraction_service.dart';
import '../services/document_parser/parsed_document.dart';

enum ExtractionState { idle, extracting, success, error }

class FlashcardController extends ChangeNotifier {
  final List<Deck> _decks = [];
  Deck? _activeDeck;
  
  ExtractionState _state = ExtractionState.idle;
  String? _errorMessage;

  // Getters for UI binding
  List<Deck> get decks => List.unmodifiable(_decks);
  Deck? get activeDeck => _activeDeck;
  ExtractionState get state => _state;
  String? get errorMessage => _errorMessage;

  /// Handles PDF/Slide document processing asynchronously without blocking UI
  Future<void> extractAndCreateDeck({
  required Uint8List fileBytes,
  required String fileName,
  required String deckTitle,
}) async {
  _state = ExtractionState.extracting;
  _errorMessage = null;
  notifyListeners();

  try {
    // 1. YOUR LAYER (Khrist): Extract & clean text (or flag for Vision fallback)
    final ParsedDocument parsedDoc = await PdfExtractionService().extractFromBytes(
      fileBytes,
      fileName,
    );

    // 2. GAB'S LAYER (AI): Generate Q&A pairs from chunks OR rawBytes (if image-heavy)
    // Until Gab's API is live, keep using mock data or wire it here:
    final List<QuestionAnswer> qaPairs = await _generateQaFromParsedDoc(parsedDoc, fileBytes);

    // 3. LANCE'S LAYER: Map to Flashcard models
    final List<Flashcard> generatedCards = qaPairs.map((qa) {
      return Flashcard(
        id: '${DateTime.now().microsecondsSinceEpoch}_${qa.id}',
        question: qa.question,
        answer: qa.answer,
      );
    }).toList();

    final Deck newDeck = Deck(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: deckTitle,
      sourceFileName: fileName,
      cards: generatedCards,
    );

    _decks.add(newDeck);
    _activeDeck = newDeck;
    _state = ExtractionState.success;
  } catch (e) {
    _state = ExtractionState.error;
    _errorMessage = 'Failed to process document: ${e.toString()}';
  } finally {
    notifyListeners();
  }
}

  /// Evaluates card response using Spaced Repetition logic
  void answerCard(Flashcard card, int rating) {
    SpacedRepetitionService.processReview(card, rating);
    notifyListeners();
  }

  void setActiveDeck(Deck deck) {
    _activeDeck = deck;
    notifyListeners();
  }

  /// Simulated Async Extractor Engine (Replace with your actual PDF parser/API client)
  Future<List<QuestionAnswer>> _parseDocumentAsync(String path) async {
    await Future.delayed(const Duration(seconds: 2)); // Simulate non-blocking execution

    if (path.contains('corrupted')) {
      throw Exception('Invalid or unreadable document format.');
    }

    return [
      QuestionAnswer(
        id: '1',
        question: 'What is Active Recall?',
        answer: 'A principle of learning that requires actively retrieving information from memory.',
      ),
      QuestionAnswer(
        id: '2',
        question: 'What is Spaced Repetition?',
        answer: 'A technique that incorporates increasing intervals of time between subsequent review of material.',
      ),
    ];
  }
}

/// Bridge between Khrist's ParsedDocument and Gab's AI Service.
  /// Currently generates mock Q&As from the extracted text so the app compiles
  /// and runs end-to-end before Gab's Gemini API is connected.
  Future<List<QuestionAnswer>> _generateQaFromParsedDoc(
    ParsedDocument parsedDoc,
    Uint8List fileBytes,
  ) async {
    // TODO (Gab): Replace this block with your Gemini API service call:
    // return await AiService().generateFlashcards(parsedDoc, fileBytes);

    await Future.delayed(const Duration(milliseconds: 500));

    if (parsedDoc.requiresVisionFallback) {
      return [
        QuestionAnswer(
          id: '1',
          question: 'Vision Fallback Triggered (${parsedDoc.fileName})',
          answer:
              'This PDF has ${parsedDoc.pageCount} pages with minimal selectable text. '
              'Ready to send raw bytes to Gemini 1.5 Flash multimodal.',
        ),
      ];
    }

    // Generate preview cards from your actual extracted & chunked text
    return List.generate(parsedDoc.chunks.length, (index) {
      final preview = parsedDoc.chunks[index].length > 120
          ? '${parsedDoc.chunks[index].substring(0, 120)}...'
          : parsedDoc.chunks[index];

      return QuestionAnswer(
        id: '${index + 1}',
        question: 'Extracted Chunk ${index + 1} (${parsedDoc.fileName})',
        answer: preview,
      );
    });
  }