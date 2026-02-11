import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'lesson_player_page.dart';

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
    setState(() => _isLoading = _topics == null);
    try {
      final data = await apiService.getCourseCurriculum(widget.courseId);
      if (mounted) {
        setState(() {
          _topics = data;
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

              return ListTile(
                leading: Icon(
                  isDone ? Icons.check_circle : Icons.play_circle_outline,
                  color: isDone ? Colors.green : primaryBrown,
                ),
                title: Text(
                  item['title'],
                  style: const TextStyle(color: Colors.black),
                ),
                onTap: () async {
                  // Await the navigation so we refresh when the user returns
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => LessonPlayerPage(
                        lessonId: int.parse(item['id'].toString()),
                        allLessonIds: allItemIds,
                      ),
                    ),
                  );
                  _refreshCurriculum();
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
