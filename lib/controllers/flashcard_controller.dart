import 'package:flutter/foundation.dart';
import '../models/deck.dart';
import '../models/flashcard.dart';
import '../models/question_answer.dart';
import '../services/spaced_repetition_service.dart';

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
    required String filePath,
    required String deckTitle,
  }) async {
    _state = ExtractionState.extracting;
    _errorMessage = null;
    notifyListeners();

    try {
      // Simulate asynchronous document parsing & AI Q&A generation
      List<QuestionAnswer> qaPairs = await _parseDocumentAsync(filePath);

      // Convert Q&A items to Flashcard models
      List<Flashcard> generatedCards = qaPairs.map((qa) {
        return Flashcard(
          id: DateTime.now().microsecondsSinceEpoch.toString() + qa.id,
          question: qa.question,
          answer: qa.answer,
        );
      }).toList();

      // Create new deck and add to system
      Deck newDeck = Deck(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: deckTitle,
        sourceFileName: filePath.split('/').last,
        cards: generatedCards,
      );

      _decks.add(newDeck);
      _activeDeck = newDeck;
      _state = ExtractionState.success;
    } catch (e) {
      _state = ExtractionState.error;
      _errorMessage = 'Failed to extract text from document: ${e.toString()}';
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