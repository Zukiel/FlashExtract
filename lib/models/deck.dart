import 'flashcard.dart';

class Deck {
  final String id;
  final String title;
  final String sourceFileName;
  final DateTime createdAt;
  final List<Flashcard> cards;

  Deck({
    required this.id,
    required this.title,
    required this.sourceFileName,
    DateTime? createdAt,
    List<Flashcard>? cards,
  })  : createdAt = createdAt ?? DateTime.now(),
        cards = cards ?? [];

  int get dueCardsCount => cards.where((card) => card.isDueForReview).length;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'sourceFileName': sourceFileName,
      'createdAt': createdAt.toIso8601String(),
      'cards': cards.map((c) => c.toMap()).toList(),
    };
  }

  factory Deck.fromMap(Map<String, dynamic> map) {
    return Deck(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      sourceFileName: map['sourceFileName'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      cards: map['cards'] != null
          ? List<Flashcard>.from(
              (map['cards'] as List).map((c) => Flashcard.fromMap(c)),
            )
          : [],
    );
  }
}