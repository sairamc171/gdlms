class Course {
  final int id;
  final String title;
  final String thumbnail;
  final int progress;

  Course({
    required this.id,
    required this.title,
    required this.thumbnail,
    required this.progress,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] ?? json['ID'] ?? 0,
      title: json['title'] ?? json['post_title'] ?? 'Untitled Course',
      thumbnail: (json['thumbnail'] is String)
          ? json['thumbnail']
          : (json['thumbnail_url'] ?? ''),
      progress:
          int.tryParse(
            json['progress']?.toString() ??
                json['completed_percent']?.toString() ??
                '0',
          ) ??
          0,
    );
  }
}

// Added this to handle the curriculum list logic specifically
class CurriculumItem {
  final int id;
  final String title;
  final String type; // 'tutor_lesson' or 'tutor_quiz'
  final bool isCompleted;

  CurriculumItem({
    required this.id,
    required this.title,
    required this.type,
    required this.isCompleted,
  });

  bool get isQuiz => type == 'tutor_quiz';
}
