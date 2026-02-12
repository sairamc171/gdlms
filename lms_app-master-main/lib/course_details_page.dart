import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'lesson_player_page.dart';
import 'quiz_intro_page.dart';

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _refreshCurriculum();
  }

  // Auto-refresh function to sync status from website
  Future<void> _refreshCurriculum() async {
    debugPrint(
      "🔄 [CourseDetails] Refreshing curriculum for Course ID: ${widget.courseId}",
    );
    setState(() => _isLoading = _topics == null);
    try {
      final data = await apiService.getCourseCurriculum(widget.courseId);
      if (mounted) {
        setState(() {
          _topics = data;
          _isLoading = false;
        });
        debugPrint("✅ [CourseDetails] Curriculum data successfully fetched.");
      }
    } catch (e) {
      debugPrint("❌ [CourseDetails] Refresh Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _toBool(dynamic value) {
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
              bool isLocked = _toBool(item['is_locked']);
              String type = item['type'] ?? 'tutor_lesson';
              bool isQuiz = type == 'tutor_quiz';

              return ListTile(
                enabled: !isLocked,
                leading: Icon(
                  isLocked
                      ? Icons.lock_outline
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
                  ),
                ),
                subtitle: isQuiz
                    ? const Text("Quiz", style: TextStyle(fontSize: 12))
                    : null,
                trailing: isLocked
                    ? const Icon(Icons.lock, size: 16, color: Colors.grey)
                    : null,
                onTap: isLocked
                    ? null
                    : () async {
                        bool? needsRefresh;
                        int itemId = int.parse(item['id'].toString());

                        debugPrint(
                          "🚀 [CourseDetails] Opening ${isQuiz ? 'Quiz' : 'Lesson'}: $itemId",
                        );

                        if (isQuiz) {
                          // Navigates to Quiz Intro which handles attempt checks
                          needsRefresh = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => QuizIntroPage(
                                quizId: itemId,
                                quizTitle: item['title'],
                              ),
                            ),
                          );
                        } else {
                          // Navigates to Lesson Player
                          needsRefresh = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => LessonPlayerPage(
                                lessonId: itemId,
                                allLessonIds: allItemIds,
                              ),
                            ),
                          );
                        }

                        // FIXED LOGIC: Detect completion and force a curriculum refresh
                        debugPrint(
                          "🏁 [CourseDetails] Returned from item. Refresh signal: $needsRefresh",
                        );

                        if (needsRefresh == true || isDone == false) {
                          debugPrint(
                            "🔄 [CourseDetails] Triggering curriculum refresh to sync completion...",
                          );
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
