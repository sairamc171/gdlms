import 'package:flutter/material.dart';
import 'services/api_service.dart';
import 'course_details_page.dart';
import 'course_reviews_page.dart';

class EnrolledCoursesPage extends StatefulWidget {
  const EnrolledCoursesPage({super.key});

  @override
  State<EnrolledCoursesPage> createState() => _EnrolledCoursesPageState();
}

class _EnrolledCoursesPageState extends State<EnrolledCoursesPage> {
  final Color primaryBrown = const Color(0xFF6D391E);
  late Future<List<dynamic>> _coursesFuture;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  void _loadCourses() {
    setState(() {
      _coursesFuture = apiService.getEnrolledCourses();
    });
  }

  Future<void> _handleRefresh() async {
    _loadCourses();
    await _coursesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      appBar: AppBar(
        title: const Text(
          "My Learning",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: primaryBrown,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
            tooltip: 'Reload Courses',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: primaryBrown,
        child: FutureBuilder<List<dynamic>>(
          future: _coursesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(
                child: CircularProgressIndicator(color: primaryBrown),
              );
            }

            final allCourses = snapshot.data ?? [];
            if (allCourses.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 100),
                  Center(
                    child: Text("No courses found. Pull down to refresh."),
                  ),
                ],
              );
            }

            final inProgress = allCourses
                .where(
                  (c) =>
                      (double.tryParse(c['progress'].toString()) ?? 0.0) < 100,
                )
                .toList();
            final completed = allCourses
                .where(
                  (c) =>
                      (double.tryParse(c['progress'].toString()) ?? 0.0) >= 100,
                )
                .toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (inProgress.isNotEmpty) ...[
                  const Text(
                    "In Progress",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...inProgress.map((course) => _buildCourseCard(course)),
                ],
                if (completed.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    "Completed",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...completed.map(
                    (course) => _buildCourseCard(course, isCompleted: true),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildCourseCard(dynamic course, {bool isCompleted = false}) {
    final double progress =
        double.tryParse(course['progress'].toString()) ?? 0.0;
    final double rating =
        double.tryParse(course['rating_avg']?.toString() ?? '0') ?? 0.0;
    final int reviewCount =
        int.tryParse(course['rating_count']?.toString() ?? '0') ?? 0;

    return GestureDetector(
      onTap: () async {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (c) => CourseDetailsPage(
              courseId: course['id'],
              title: course['title'],
            ),
          ),
        );
        _handleRefresh();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isCompleted
                ? Colors.green.withValues(alpha: 0.3)
                : primaryBrown.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child:
                      course['thumbnail'] != null &&
                          course['thumbnail'].isNotEmpty
                      ? Image.network(
                          course['thumbnail'],
                          height: 160,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => _buildPlaceholder(),
                        )
                      : _buildPlaceholder(),
                ),
                if (isCompleted)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 16,
                          ),
                          SizedBox(width: 4),
                          Text(
                            "COMPLETED",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                course['title'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),

            // Star Rating with Navigation to Reviews
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => CourseReviewsPage(
                        courseId: course['id'],
                        courseTitle: course['title'],
                      ),
                    ),
                  );
                },
                child: Row(
                  children: [
                    ...List.generate(5, (index) {
                      return Icon(
                        index < rating.floor() ? Icons.star : Icons.star_border,
                        color: rating > 0 ? Colors.orange : Colors.grey[300],
                        size: 16,
                      );
                    }),
                    const SizedBox(width: 8),
                    Text(
                      "${rating.toStringAsFixed(1)} ($reviewCount Reviews)",
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: progress / 100,
                        backgroundColor: Colors.grey[200],
                        color: isCompleted ? Colors.green : primaryBrown,
                        minHeight: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    isCompleted ? "Done!" : "${progress.toInt()}%",
                    style: TextStyle(
                      fontSize: 13,
                      color: isCompleted ? Colors.green : Colors.black54,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      height: 160,
      width: double.infinity,
      color: const Color(0xFFF5F5F5),
      child: const Icon(Icons.image_outlined, size: 40, color: Colors.grey),
    );
  }
}
