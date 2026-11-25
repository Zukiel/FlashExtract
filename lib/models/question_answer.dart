class QuestionAnswer {
  final String id;
  final String question;
  final String answer;

  QuestionAnswer({
    required this.id,
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'question': question,
      'answer': answer,
    };
  }

  factory QuestionAnswer.fromMap(Map<String, dynamic> map) {
    return QuestionAnswer(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
    );
  }
}