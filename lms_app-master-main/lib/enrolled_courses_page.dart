import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'course_details_page.dart';
import 'course_reviews_page.dart';

class EnrolledCoursesPage extends StatefulWidget {
  const EnrolledCoursesPage({super.key});

  @override
  State<EnrolledCoursesPage> createState() => _EnrolledCoursesPageState();
}

class _EnrolledCoursesPageState extends State<EnrolledCoursesPage> {
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
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(
        title: "My Learning",
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: _handleRefresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        color: AppTheme.primary,
        child: FutureBuilder<List<dynamic>>(
          future: _coursesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              );
            }

            final allCourses = snapshot.data ?? [];
            if (allCourses.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 160),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          "No courses yet",
                          style: AppTheme.bodyMedium.copyWith(
                            color: Colors.grey[400],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Pull down to refresh",
                          style: AppTheme.labelSmall,
                        ),
                      ],
                    ),
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
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (inProgress.isNotEmpty) ...[
                  _buildSectionLabel("IN PROGRESS", inProgress.length),
                  const SizedBox(height: 14),
                  ...inProgress.map((c) => _buildCourseCard(c)),
                ],
                if (completed.isNotEmpty) ...[
                  if (inProgress.isNotEmpty) const SizedBox(height: 32),
                  _buildSectionLabel("COMPLETED", completed.length),
                  const SizedBox(height: 14),
                  ...completed.map(
                    (c) => _buildCourseCard(c, isCompleted: true),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label, int count) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: AppTheme.overline),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: AppTheme.sectionPillDecoration,
          child: Text(
            "$count",
            style: AppTheme.overline.copyWith(
              letterSpacing: 0,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCourseCard(dynamic course, {bool isCompleted = false}) {
    final double progress =
        double.tryParse(course['progress'].toString()) ?? 0.0;
    final double rating =
        double.tryParse(course['rating_avg']?.toString() ?? '0') ?? 0.0;
    final int reviewCount =
        int.tryParse(course['rating_count']?.toString() ?? '0') ?? 0;
    final bool hasThumbnail =
        course['thumbnail'] != null && course['thumbnail'].isNotEmpty;

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
        margin: const EdgeInsets.only(bottom: 18),
        decoration: AppTheme.cardDecoration,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              SizedBox(
                height: 168,
                width: double.infinity,
                child: hasThumbnail
                    ? Image.network(
                        course['thumbnail'],
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => _placeholder(),
                      )
                    : _placeholder(),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course['title'],
                      style: AppTheme.cardTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 10),

                    // Rating
                    GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => CourseReviewsPage(
                            courseId: course['id'],
                            courseTitle: course['title'],
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          ...List.generate(5, (i) {
                            if (rating >= i + 1) {
                              return Icon(
                                Icons.star_rounded,
                                color: Colors.amber[500],
                                size: 13,
                              );
                            } else if (rating > i && rating < i + 1) {
                              return Icon(
                                Icons.star_half_rounded,
                                color: Colors.amber[500],
                                size: 13,
                              );
                            } else {
                              return Icon(
                                Icons.star_outline_rounded,
                                color: Colors.grey[300],
                                size: 13,
                              );
                            }
                          }),
                          const SizedBox(width: 7),
                          Text(
                            rating > 0
                                ? "${rating.toStringAsFixed(1)}  ·  $reviewCount review${reviewCount != 1 ? 's' : ''}"
                                : "No reviews yet",
                            style: AppTheme.labelSmall.copyWith(
                              color: rating > 0
                                  ? Colors.blue[600]
                                  : Colors.grey[400],
                              decoration: rating > 0
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    AppTheme.cardDivider,
                    const SizedBox(height: 14),

                    AppTheme.buildProgressBar(
                      progress,
                      isCompleted: isCompleted,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      height: 168,
      width: double.infinity,
      color: AppTheme.placeholder,
    );
  }
}
