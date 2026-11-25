class Flashcard {
  final String id;
  final String question;
  final String answer;

  // Spaced Repetition Parameters (SM-2 Algorithm)
  int repetitions;
  double easeFactor;
  int intervalDays; // Interval in days until next review
  DateTime nextReviewDate;

  Flashcard({
    required this.id,
    required this.question,
    required this.answer,
    this.repetitions = 0,
    this.easeFactor = 2.5, // Standard SM-2 starting ease factor
    this.intervalDays = 0,
    DateTime? nextReviewDate,
  }) : nextReviewDate = nextReviewDate ?? DateTime.now();

  bool get isDueForReview => DateTime.now().isAfter(nextReviewDate);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
      'repetitions': repetitions,
      'easeFactor': easeFactor,
      'intervalDays': intervalDays,
      'nextReviewDate': nextReviewDate.toIso8601String(),
    };
  }

  factory Flashcard.fromMap(Map<String, dynamic> map) {
    return Flashcard(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
      repetitions: map['repetitions'] ?? 0,
      easeFactor: (map['easeFactor'] as num?)?.toDouble() ?? 2.5,
      intervalDays: map['intervalDays'] ?? 0,
      nextReviewDate: map['nextReviewDate'] != null
          ? DateTime.parse(map['nextReviewDate'])
          : DateTime.now(),
    );
  }
}