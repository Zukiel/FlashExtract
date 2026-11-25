import '../models/flashcard.dart';

/// Rating Scale:
/// 5 - Perfect response
/// 4 - Correct response after a hesitation
/// 3 - Correct response recalled with serious difficulty
/// 2 - Incorrect response; where the correct one seemed easy to recall
/// 1 - Incorrect response; the correct one remembered
/// 0 - Complete blackout
/// 
class SpacedRepetitionService {
  static Flashcard processReview(Flashcard card, int rating) {
    assert(rating >= 0 && rating <= 5, 'Rating must be between 0 and 5');

    int newRepetitions = card.repetitions;
    int newInterval = card.intervalDays;
    double newEaseFactor = card.easeFactor;

    if (rating >= 3) {
      // Successful recall
      if (newRepetitions == 0) {
        newInterval = 1;
      } else if (newRepetitions == 1) {
        newInterval = 6;
      } else {
        newInterval = (newInterval * newEaseFactor).round();
      }
      newRepetitions += 1;
    } else {
      // Failed recall - reset repetitions and review tomorrow
      newRepetitions = 0;
      newInterval = 1;
    }

    // Calculate new Ease Factor formula: EF' = EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))
    newEaseFactor = newEaseFactor + (0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02));
    
    // Minimum boundary for Ease Factor in SM-2 is 1.3
    if (newEaseFactor < 1.3) {
      newEaseFactor = 1.3;
    }

    card.repetitions = newRepetitions;
    card.intervalDays = newInterval;
    card.easeFactor = newEaseFactor;
    card.nextReviewDate = DateTime.now().add(Duration(days: newInterval));

    return card;
  }
}