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
      // Standard Tutor LMS v1 uses 'ID' and 'post_title'
      id: json['ID'] ?? 0,
      title: json['post_title'] ?? 'Untitled Course',
      thumbnail: (json['thumbnail_url'] is String) ? json['thumbnail_url'] : '',
      // 'completed_percent' is used for the progress bar and stats
      progress: int.tryParse(json['completed_percent']?.toString() ?? '0') ?? 0,
    );
  }
}
