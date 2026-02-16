import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'lesson_player_page.dart';
import 'quiz_intro_page.dart'; // Added for smart routing consistency

class CourseDetailsPage extends StatefulWidget {
  final int courseId;
  final String title;

  const CourseDetailsPage({
    super.key,
    required this.courseId,
    required this.title,
  });

  @override
  State<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends State<CourseDetailsPage> {
  final Color primaryBrown = const Color(0xFF6D391E);
  final Color headerFillColor = const Color(0xFFF3F4F9);

  List<dynamic>? _topics;
  Map<String, dynamic>? _ratingData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshCurriculum();
  }

  Future<void> _refreshCurriculum() async {
    setState(() => _isLoading = _topics == null);
    try {
      final results = await Future.wait([
        apiService.getCourseCurriculum(widget.courseId),
        apiService.getCourseRatings(widget.courseId),
      ]);

      if (mounted) {
        setState(() {
          _topics = results[0] as List<dynamic>?;
          _ratingData = results[1] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;
    return value == true ||
        value == "1" ||
        value == 1 ||
        value.toString().toLowerCase() == "true";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshCurriculum,
        color: primaryBrown,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 20),
                    _buildThumbnail(),
                    _buildCurriculumHeader(),
                    _buildCurriculumList(),
                    const Divider(
                      height: 40,
                      thickness: 1,
                      indent: 20,
                      endIndent: 20,
                    ),
                    if (_ratingData != null && _ratingData!['reviews'] != null)
                      _buildReviewList(_ratingData!['reviews']),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCurriculumList() {
    if (_topics == null) return const SizedBox();

    List<dynamic> allItems = [];
    for (var topic in _topics!) {
      allItems.addAll(topic['items'] ?? []);
    }
    List<int> allItemIds = allItems
        .map((item) => int.parse(item['id'].toString()))
        .toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _topics!.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        final topic = _topics![index];
        final lessons = topic['items'] as List? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: ExpansionTile(
            initiallyExpanded: true,
            collapsedBackgroundColor: headerFillColor,
            title: Text(
              topic['topic_title'] ?? "Untitled Topic",
              style: TextStyle(
                color: primaryBrown,
                fontWeight: FontWeight.bold,
              ),
            ),
            children: lessons.map((item) {
              bool isDone = _toBool(item['is_completed']);
              bool isLocked = _toBool(
                item['is_locked'],
              ); // STRICT SEQUENTIAL CHECK
              String type = item['type'] ?? 'tutor_lesson';
              bool isQuiz = type == 'tutor_quiz';

              return ListTile(
                // Sequential Logic: Show lock if locked, checkmark if done, play if available
                leading: Icon(
                  isLocked
                      ? Icons.lock
                      : (isDone
                            ? Icons.check_circle
                            : (isQuiz
                                  ? Icons.help_outline
                                  : Icons.play_circle_outline)),
                  color: isLocked
                      ? Colors.grey
                      : (isDone ? Colors.green : primaryBrown),
                ),
                title: Text(
                  item['title'],
                  style: TextStyle(
                    color: isLocked ? Colors.grey : Colors.black,
                    fontWeight: isLocked ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
                subtitle: isQuiz
                    ? const Text("Quiz", style: TextStyle(fontSize: 11))
                    : null,
                onTap: isLocked
                    ? () {
                        // Visual feedback if user taps a locked item
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Complete previous lessons to unlock this content.",
                            ),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    : () async {
                        bool? needsRefresh;
                        if (isQuiz) {
                          needsRefresh = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => QuizIntroPage(
                                quizId: int.parse(item['id'].toString()),
                                quizTitle: item['title'],
                              ),
                            ),
                          );
                        } else {
                          needsRefresh = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => LessonPlayerPage(
                                lessonId: int.parse(item['id'].toString()),
                                allLessonIds: allItemIds,
                              ),
                            ),
                          );
                        }

                        if (needsRefresh == true) {
                          _refreshCurriculum();
                        }
                      },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // --- EXISTING UI HELPER METHODS ---

  Widget _buildReviewList(List<dynamic> reviews) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            "Reviews",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final review = reviews[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: primaryBrown.withOpacity(0.1),
                child: Icon(Icons.person, color: primaryBrown),
              ),
              title: Text(
                review['display_name'] ?? review['comment_author'] ?? "Student",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 4),
                  _buildStarRating(
                    double.tryParse(review['rating'].toString()) ?? 0.0,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review['comment_content'] ?? "",
                    style: const TextStyle(color: Colors.black87),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review['comment_date'] ?? "",
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Icon(
          index < rating.floor() ? Icons.star : Icons.star_border,
          color: Colors.orange,
          size: 16,
        );
      }),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            "Diploma Programs",
            style: TextStyle(
              color: primaryBrown,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail() {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(
            "https://lms.gdcollege.ca/wp-content/uploads/2025/09/Makeup-Artist-Hair-Stylist-Banner-300x198.jpg",
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildCurriculumHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Course Content",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: primaryBrown,
            ),
          ),
          const SizedBox(height: 6),
          Container(height: 3, width: 90, color: primaryBrown),
        ],
      ),
    );
  }
}
