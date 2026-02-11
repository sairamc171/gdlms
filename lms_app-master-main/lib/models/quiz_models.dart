class QuizQuestion {
  final int id;
  final String text;
  final String type;
  final List<QuizOption> options;

  QuizQuestion({
    required this.id,
    required this.text,
    required this.type,
    required this.options,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: int.parse(json['id'].toString()), // FIX: Prevents TypeError
      text: json['text'] ?? '',
      type: json['type'] ?? '',
      options: (json['options'] as List)
          .map((o) => QuizOption.fromJson(o))
          .toList(),
    );
  }
}

class QuizOption {
  final String text;
  final bool isCorrect;

  QuizOption({required this.text, required this.isCorrect});

  factory QuizOption.fromJson(Map<String, dynamic> json) {
    return QuizOption(
      text: json['text'] ?? '',
      isCorrect: json['is_correct'] == true,
    );
  }
}
