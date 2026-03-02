import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'lesson_player_page.dart';
import 'quiz_intro_page.dart';
import 'course_reviews_page.dart';

final RouteObserver<ModalRoute<void>> courseRouteObserver =
    RouteObserver<ModalRoute<void>>();

class CourseDetailsPage extends StatefulWidget {
  static const routeName = '/course-details';

  final int courseId;
  final String title;
  // Passed from EnrolledCoursesPage — already available, no extra fetch needed.
  final String? thumbnailUrl;

  const CourseDetailsPage({
    super.key,
    required this.courseId,
    required this.title,
    this.thumbnailUrl,
  });

  @override
  State<CourseDetailsPage> createState() => _CourseDetailsPageState();
}

class _CourseDetailsPageState extends State<CourseDetailsPage> with RouteAware {
  List<dynamic>? _topics;
  Map<String, dynamic>? _ratingData;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _dynamicThumbnailUrl; // Add this

  @override
  void initState() {
    super.initState();
    _dynamicThumbnailUrl = widget.thumbnailUrl;
    _refreshCurriculum();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    courseRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    courseRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    _refreshCurriculum();
  }

  Future<void> _refreshCurriculum() async {
    if (_topics == null) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isRefreshing = true);
    }

    try {
      final results = await Future.wait([
        apiService.getCourseCurriculum(widget.courseId),
        apiService.getCourseRatings(widget.courseId),
        apiService.getCourseDetails(widget.courseId), // New Call
      ]);

      if (mounted) {
        setState(() {
          _topics = results[0] as List<dynamic>?;
          _ratingData = results[1] as Map<String, dynamic>?;
          final courseData = results[2] as Map<String, dynamic>?;
          if (courseData != null && courseData['thumbnail'] != null) {
            _dynamicThumbnailUrl = courseData['thumbnail'];
          }
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  bool _toBool(dynamic value) {
    if (value == null) return false;
    return value == true ||
        value == '1' ||
        value == 1 ||
        value.toString().toLowerCase() == 'true';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(title: widget.title),
      body: RefreshIndicator(
        onRefresh: _refreshCurriculum,
        color: AppTheme.primary,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : Stack(
                children: [
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildThumbnail(),
                        _buildCurriculumHeader(),
                        _buildCurriculumList(),
                        _buildReviewsSection(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                  if (_isRefreshing)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(color: AppTheme.primary),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _buildThumbnail() {
    final url = _dynamicThumbnailUrl;
    return SizedBox(
      width: double.infinity,
      height: 200,
      child: (url != null && url.isNotEmpty)
          ? Image.network(
              url,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(color: AppTheme.placeholder);
              },
              errorBuilder: (_, __, ___) => _thumbnailPlaceholder(),
            )
          : _thumbnailPlaceholder(),
    );
  }

  Widget _thumbnailPlaceholder() {
    return Container(
      color: AppTheme.placeholder,
      child: const Center(
        child: Icon(Icons.school_outlined, size: 48, color: AppTheme.textHint),
      ),
    );
  }

  // ── Curriculum ─────────────────────────────────────────────────────────────

  Widget _buildCurriculumHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Course Content', style: AppTheme.headingMedium),
          const SizedBox(height: 6),
          Container(height: 3, width: 80, color: AppTheme.primary),
        ],
      ),
    );
  }

  Widget _buildCurriculumList() {
    if (_topics == null) return const SizedBox();

    final List<dynamic> allItems = [];
    for (var topic in _topics!) {
      allItems.addAll(topic['items'] ?? []);
    }
    final List<int> allItemIds = allItems
        .map((item) => int.parse(item['id'].toString()))
        .toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _topics!.length,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      itemBuilder: (context, index) {
        final topic = _topics![index];
        final lessons = topic['items'] as List? ?? [];

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: AppTheme.cardDecoration,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: true,
                backgroundColor: AppTheme.surface,
                collapsedBackgroundColor: AppTheme.surface,
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                title: Text(
                  topic['topic_title'] ?? 'Untitled Topic',
                  style: AppTheme.cardTitle.copyWith(color: AppTheme.primary),
                ),
                iconColor: AppTheme.primary,
                collapsedIconColor: AppTheme.textHint,
                children: [
                  const Divider(height: 1, color: AppTheme.divider),
                  ...lessons.map((item) {
                    final bool isDone = _toBool(item['is_completed']);
                    final bool isLocked = _toBool(item['is_locked']);
                    final String type = item['type'] ?? 'tutor_lesson';
                    final bool isQuiz = type == 'tutor_quiz';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isLocked
                              ? AppTheme.placeholder
                              : isDone
                              ? AppTheme.completed.withValues(alpha: 0.1)
                              : AppTheme.primary.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isLocked
                              ? Icons.lock_outline
                              : isDone
                              ? Icons.check_circle
                              : isQuiz
                              ? Icons.quiz_outlined
                              : Icons.play_circle_outline_rounded,
                          color: isLocked
                              ? AppTheme.textHint
                              : isDone
                              ? AppTheme.completed
                              : AppTheme.primary,
                          size: 18,
                        ),
                      ),
                      title: Text(
                        item['title'],
                        style: AppTheme.bodyMedium.copyWith(
                          color: isLocked
                              ? AppTheme.textHint
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: isQuiz
                          ? Text(
                              'Quiz',
                              style: AppTheme.labelSmall.copyWith(
                                color: AppTheme.primary,
                              ),
                            )
                          : null,
                      trailing: isDone
                          ? null
                          : isLocked
                          ? null
                          : const Icon(
                              Icons.chevron_right,
                              color: AppTheme.textHint,
                              size: 20,
                            ),
                      onTap: isLocked
                          ? () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Complete previous lessons to unlock this content.',
                                    style: AppTheme.labelMedium.copyWith(
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: AppTheme.primary,
                                  behavior: SnackBarBehavior.floating,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(
                                      Radius.circular(10),
                                    ),
                                  ),
                                ),
                              );
                            }
                          : () {
                              if (isQuiz) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => QuizIntroPage(
                                      quizId: int.parse(item['id'].toString()),
                                      quizTitle: item['title'],
                                      allLessonIds: allItemIds,
                                    ),
                                  ),
                                );
                              } else {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (c) => LessonPlayerPage(
                                      lessonId: int.parse(
                                        item['id'].toString(),
                                      ),
                                      allLessonIds: allItemIds,
                                    ),
                                  ),
                                );
                              }
                            },
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ── Reviews section ────────────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    final reviews = _ratingData?['reviews'] as List<dynamic>? ?? [];
    final double ratingAvg = (_ratingData?['rating_avg'] ?? 0.0).toDouble();
    final int ratingCount = (_ratingData?['rating_count'] ?? 0) as int;
    final String? currentUserName = apiService.user?['user_display_name'];
    final bool hasMyReview = reviews.any(
      (r) => r['display_name'] == currentUserName,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reviews', style: AppTheme.headingMedium),
                    const SizedBox(height: 6),
                    Container(height: 3, width: 60, color: AppTheme.primary),
                  ],
                ),
                // Only show "See All" at the top if there are actually reviews to see
                if (ratingCount > 0)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CourseReviewsPage(
                          courseId: widget.courseId,
                          courseTitle: widget.title,
                        ),
                      ),
                    ).then((_) => _refreshCurriculum()),
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 16,
                      color: AppTheme.primary,
                    ),
                    label: Text(
                      'See All',
                      style: AppTheme.labelMedium.copyWith(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Rating Summary Card
          if (ratingCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: AppTheme.cardDecoration,
              child: Row(
                children: [
                  Text(
                    ratingAvg.toStringAsFixed(1),
                    style: AppTheme.headingLarge.copyWith(
                      color: AppTheme.textPrimary,
                      fontSize: 36,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStars(ratingAvg, size: 16),
                      const SizedBox(height: 4),
                      Text(
                        '$ratingCount review${ratingCount != 1 ? 's' : ''}',
                        style: AppTheme.labelSmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // Empty State or Review List
          if (reviews.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: AppTheme.cardDecoration,
              child: Column(
                children: [
                  Icon(
                    Icons.rate_review_outlined,
                    size: 40,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No reviews yet',
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Be the first to share your thoughts',
                    style: AppTheme.labelSmall,
                  ),
                ],
              ),
            )
          else
            ...reviews.take(2).map((r) => _buildReviewCard(r)),

          // Primary "Write a Review" Button (Shown only if user hasn't reviewed yet)
          if (!hasMyReview) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CourseReviewsPage(
                      courseId: widget.courseId,
                      courseTitle: widget.title,
                    ),
                  ),
                ).then((_) => _refreshCurriculum()),
                icon: const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.surface,
                ),
                label: Text(
                  'Write a Review',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.surface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  elevation: 0,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReviewCard(dynamic r) {
    final String displayName = (r['display_name'] as String?) ?? 'Student';
    final double reviewRating = double.tryParse(r['rating'].toString()) ?? 0.0;
    final String content = (r['comment_content'] as String?) ?? '';
    final bool isMyReview =
        r['display_name'] == apiService.user?['user_display_name'];

    String photoUrl = (r['profile_photo'] as String?) ?? '';
    if (isMyReview) {
      final String? sessionPhoto = apiService.user?['profile_photo'] as String?;
      if (sessionPhoto != null &&
          sessionPhoto.isNotEmpty &&
          sessionPhoto.startsWith('http')) {
        photoUrl = sessionPhoto;
      }
    }

    final parts = displayName.trim().split(RegExp(r'\s+'));
    final String initials = displayName.trim().isEmpty
        ? '?'
        : parts.length >= 2
        ? '${parts.first[0]}${parts.last[0]}'.toUpperCase()
        : parts.first[0].toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isMyReview
            ? Border.all(
                color: AppTheme.primary.withValues(alpha: 0.2),
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              photoUrl.isNotEmpty && photoUrl.startsWith('http')
                  ? ClipOval(
                      child: Image.network(
                        photoUrl,
                        width: 38,
                        height: 38,
                        fit: BoxFit.cover,
                        headers: const {
                          'Cache-Control':
                              'no-cache, no-store, must-revalidate',
                          'Pragma': 'no-cache',
                        },
                        errorBuilder: (_, __, ___) =>
                            _initialsAvatar(initials, 19),
                      ),
                    )
                  : _initialsAvatar(initials, 19),
              const SizedBox(width: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        style: AppTheme.cardTitle.copyWith(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isMyReview)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'You',
                          style: AppTheme.labelSmall.copyWith(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildStars(reviewRating, size: 12),
            ],
          ),
          if (content.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppTheme.divider),
            const SizedBox(height: 8),
            Text(
              content,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodySmall.copyWith(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _initialsAvatar(String initials, double radius) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.primary,
      child: Text(
        initials,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.surface,
          fontWeight: FontWeight.w600,
          fontSize: radius * 0.75,
        ),
      ),
    );
  }

  Widget _buildStars(double rating, {double size = 14}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (rating >= i + 1) {
          return Icon(Icons.star_rounded, color: Colors.amber[500], size: size);
        } else if (rating > i && rating < i + 1) {
          return Icon(
            Icons.star_half_rounded,
            color: Colors.amber[500],
            size: size,
          );
        } else {
          return Icon(
            Icons.star_outline_rounded,
            color: Colors.grey[300],
            size: size,
          );
        }
      }),
    );
  }
}
