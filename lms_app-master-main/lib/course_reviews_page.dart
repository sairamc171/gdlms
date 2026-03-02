import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_theme.dart';
import 'services/api_service.dart';

class CourseReviewsPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;

  const CourseReviewsPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
  });

  @override
  State<CourseReviewsPage> createState() => _CourseReviewsPageState();
}

class _CourseReviewsPageState extends State<CourseReviewsPage> {
  List<dynamic> _reviews = [];
  Map<String, dynamic>? _myReview;
  double _ratingAvg = 0.0;
  int _ratingCount = 0;
  bool _isLoading = true;

  // Inline write-a-review state
  double _selectedRating = 5.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ── Avatar helper — works for both "my review" and other reviews ───────────

  /// Tries to get the current user's own profile photo from apiService first,
  /// then falls back to whatever the review record contains.
  String _resolveAvatarUrl(dynamic review) {
    final String? currentUserName = apiService.user?['user_display_name'];
    final String displayName = (review['display_name'] as String?) ?? '';

    // If this is my review, prefer the photo from the live user session.
    if (displayName == currentUserName) {
      final String? sessionPhoto = apiService.user?['profile_photo'] as String?;
      if (sessionPhoto != null &&
          sessionPhoto.isNotEmpty &&
          sessionPhoto.startsWith('http')) {
        return sessionPhoto;
      }
    }

    // Fallback: whatever the review API returned.
    return (review['profile_photo'] as String?) ?? '';
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetchReviews({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);
    final data = await apiService.getCourseRatings(widget.courseId);
    if (mounted && data != null) {
      final List<dynamic> allReviews = data['reviews'] ?? [];
      final String? currentUserName = apiService.user?['user_display_name'];
      final myExistingReview = allReviews.firstWhere(
        (r) => r['display_name'] == currentUserName,
        orElse: () => null,
      );
      setState(() {
        _reviews = allReviews;
        _myReview = myExistingReview;
        _ratingAvg = (data['rating_avg'] ?? 0.0).toDouble();
        _ratingCount = (data['rating_count'] ?? 0);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleDeleteReview() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete review?', style: AppTheme.cardTitle),
        content: Text(
          'This will remove your rating so you can write a new one.',
          style: AppTheme.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTheme.labelMedium.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: AppTheme.labelMedium.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      bool success = await apiService.deleteReview(widget.courseId);
      if (mounted) {
        await _fetchReviews(showLoader: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success ? 'Review removed.' : 'List updated.',
                style: AppTheme.labelMedium.copyWith(color: Colors.white),
              ),
              backgroundColor: AppTheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleSubmitReview() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please write a comment first.',
            style: AppTheme.labelMedium.copyWith(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }
    setState(() => _isSubmitting = true);
    bool success = await apiService.submitReview(
      widget.courseId,
      _selectedRating,
      _commentController.text,
    );
    if (!mounted) return;
    if (success) {
      _commentController.clear();
      setState(() {
        _selectedRating = 5.0;
        _isSubmitting = false;
      });
      await _fetchReviews(showLoader: false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Review submitted!',
              style: AppTheme.labelMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: AppTheme.completed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } else {
      setState(() => _isSubmitting = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You may have already reviewed this course.',
              style: AppTheme.labelMedium.copyWith(color: Colors.white),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2)
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return parts.first[0].toUpperCase();
  }

  Widget _buildReviewerAvatar(dynamic review) {
    final String photoUrl = _resolveAvatarUrl(review);
    final String name = (review['display_name'] as String?) ?? 'Student';
    final String initials = _getInitials(name);

    if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: 42,
          height: 42,
          fit: BoxFit.cover,
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 42,
              height: 42,
              color: AppTheme.placeholder,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.primary,
                ),
              ),
            );
          },
          errorBuilder: (_, __, ___) => _buildInitialsAvatar(initials),
        ),
      );
    }
    return _buildInitialsAvatar(initials);
  }

  Widget _buildInitialsAvatar(String initials) {
    return CircleAvatar(
      radius: 21,
      backgroundColor: AppTheme.primary,
      child: Text(
        initials,
        style: AppTheme.bodySmall.copyWith(
          color: AppTheme.surface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  String _formatDate(String raw) {
    if (raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    } catch (_) {
      return raw;
    }
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(title: 'Reviews'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : Column(
              children: [
                // ── Rating summary header ──────────────────────────
                Container(
                  color: AppTheme.surface,
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            _ratingAvg.toStringAsFixed(1),
                            style: GoogleFonts.poppins(
                              fontSize: 52,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                              height: 1.0,
                              letterSpacing: -2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          _buildStars(_ratingAvg, size: 18),
                          const SizedBox(height: 4),
                          Text(
                            '$_ratingCount review${_ratingCount != 1 ? 's' : ''}',
                            style: AppTheme.labelSmall,
                          ),
                        ],
                      ),
                      const SizedBox(width: 24),
                      Container(width: 1, height: 72, color: AppTheme.divider),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Course Rating',
                              style: AppTheme.overline.copyWith(
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              widget.courseTitle,
                              style: AppTheme.cardTitle,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                Container(height: 1, color: AppTheme.divider),

                // ── Scrollable body: reviews + write/delete section ────
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _fetchReviews(showLoader: false),
                    color: AppTheme.primary,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        // Empty state
                        if (_reviews.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 48, bottom: 32),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.rate_review_outlined,
                                    size: 52,
                                    color: Colors.grey[300],
                                  ),
                                  const SizedBox(height: 12),
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
                            ),
                          ),

                        // Review cards
                        ...List.generate(_reviews.length, (index) {
                          final r = _reviews[index];
                          final double reviewRating =
                              double.tryParse(r['rating'].toString()) ?? 0.0;
                          final String displayName =
                              (r['display_name'] as String?) ?? 'Student';
                          final String content =
                              (r['comment_content'] as String?) ?? '';
                          final String date = _formatDate(
                            r['comment_date'] ?? '',
                          );
                          final bool isMyReview =
                              r['display_name'] ==
                              apiService.user?['user_display_name'];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: isMyReview
                                    ? Border.all(
                                        color: AppTheme.primary.withValues(
                                          alpha: 0.2,
                                        ),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      _buildReviewerAvatar(r),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    displayName,
                                                    style: AppTheme.cardTitle
                                                        .copyWith(fontSize: 14),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (isMyReview)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 7,
                                                          vertical: 2,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.primary
                                                          .withValues(
                                                            alpha: 0.1,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'You',
                                                      style: AppTheme.labelSmall
                                                          .copyWith(
                                                            color: AppTheme
                                                                .primary,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                _buildStars(
                                                  reviewRating,
                                                  size: 13,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  date,
                                                  style: AppTheme.labelSmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (content.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    Divider(height: 1, color: AppTheme.divider),
                                    const SizedBox(height: 12),
                                    Text(
                                      content,
                                      style: AppTheme.bodySmall.copyWith(
                                        color: AppTheme.textSecondary,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }),

                        const SizedBox(height: 8),

                        // ── Write a Review OR Delete My Review ────────
                        if (_myReview == null)
                          _buildWriteReviewSection()
                        else
                          _buildDeleteReviewSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // ── Inline write-a-review card ─────────────────────────────────────────────

  Widget _buildWriteReviewSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.primary.withValues(alpha: 0.15),
          width: 1.5,
        ),
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
              Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                'Write a Review',
                style: AppTheme.headingMedium.copyWith(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.courseTitle,
            style: AppTheme.labelSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 16),

          // Star selector
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final filled = index < _selectedRating;
                return GestureDetector(
                  onTap: () => setState(() => _selectedRating = index + 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      filled ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: filled ? Colors.amber[500] : Colors.grey[300],
                      size: 36,
                    ),
                  ),
                );
              }),
            ),
          ),

          const SizedBox(height: 16),

          // Comment field
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: TextField(
              controller: _commentController,
              style: AppTheme.bodyMedium,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Share your experience with this course...',
                hintStyle: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textHint,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Submit button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSubmitting
                    ? AppTheme.placeholder
                    : AppTheme.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _isSubmitting ? null : _handleSubmitReview,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: AppTheme.surface,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      'Post Review',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.surface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteReviewSection() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _handleDeleteReview,
        icon: const Icon(
          Icons.delete_outline_rounded,
          size: 18,
          color: Colors.red,
        ),
        label: Text(
          'Delete My Review',
          style: AppTheme.bodyMedium.copyWith(
            color: Colors.red,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Colors.red, width: 1.2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
