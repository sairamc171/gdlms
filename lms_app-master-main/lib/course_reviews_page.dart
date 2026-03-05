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

  // ── Avatar helper ──────────────────────────────────────────────────────────

  String _resolveAvatarUrl(dynamic review) {
    final bool isMyReview = review['is_mine'] == true;
    if (isMyReview) {
      final String? sessionPhoto = apiService.user?['profile_photo'] as String?;
      if (sessionPhoto != null &&
          sessionPhoto.isNotEmpty &&
          sessionPhoto.startsWith('http')) {
        return sessionPhoto;
      }
    }
    final String avatarUrl = (review['avatar_url'] as String?) ?? '';
    if (avatarUrl.isNotEmpty && avatarUrl.startsWith('http')) return avatarUrl;
    return (review['profile_photo'] as String?) ?? '';
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  Future<void> _fetchReviews({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);
    final data = await apiService.getCourseRatings(widget.courseId);
    if (mounted && data != null) {
      final List<dynamic> allReviews = data['reviews'] ?? [];
      final myExistingReview = allReviews.firstWhere(
        (r) => r['is_mine'] == true,
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
      final bool success = await apiService.deleteReview(widget.courseId);
      if (mounted) {
        await _fetchReviews(showLoader: true);
        if (mounted) {
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
    final bool success = await apiService.submitReview(
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
      if (mounted) {
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
      if (mounted) {
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
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      // Scaffold shrinks its body when keyboard opens.
      // Combined with a single-ListView landscape layout, nothing overflows.
      resizeToAvoidBottomInset: true,
      appBar: AppTheme.buildAppBar(title: 'Reviews'),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : isLandscape
          ? _buildLandscapeBody()
          : _buildPortraitBody(),
    );
  }

  // ── Portrait: pinned header + scrollable list ──────────────────────────────

  Widget _buildPortraitBody() {
    return Column(
      children: [
        _buildSummaryHeader(),
        Container(height: 1, color: AppTheme.divider),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _fetchReviews(showLoader: false),
            color: AppTheme.primary,
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              children: _buildListContent(compact: false),
            ),
          ),
        ),
      ],
    );
  }

  // ── Landscape: ONE big scrollable — header scrolls too ────────────────────
  //
  // Root cause of the overflow: in landscape the AppBar (~56 px) + keyboard
  // (~260 px) can leave as little as 60 px of body height. A Column with a
  // pinned summary header (≈ 90 px) + Expanded ListView has zero room.
  // Solution: remove the pinned header entirely in landscape and let the whole
  // page scroll as a single ListView. The keyboard simply scrolls content up.

  Widget _buildLandscapeBody() {
    return RefreshIndicator(
      onRefresh: () => _fetchReviews(showLoader: false),
      color: AppTheme.primary,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          _buildSummaryHeader(compact: true),
          const SizedBox(height: 8),
          Container(height: 1, color: AppTheme.divider),
          const SizedBox(height: 12),
          ..._buildListContent(compact: true),
        ],
      ),
    );
  }

  // ── Shared review list + write/delete widget ───────────────────────────────

  List<Widget> _buildListContent({required bool compact}) {
    return [
      if (_reviews.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 32, bottom: 24),
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
                  style: AppTheme.bodyMedium.copyWith(color: Colors.grey[400]),
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
      ..._reviews.map((r) => _buildReviewCard(r)),
      const SizedBox(height: 8),
      if (_myReview == null)
        _buildWriteReviewSection(compact: compact)
      else
        _buildDeleteReviewSection(),
    ];
  }

  // ── Rating summary header ──────────────────────────────────────────────────

  Widget _buildSummaryHeader({bool compact = false}) {
    return Container(
      color: AppTheme.surface,
      padding: EdgeInsets.symmetric(
        horizontal: 24,
        vertical: compact ? 10 : 16,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Score + stars
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _ratingAvg.toStringAsFixed(1),
                  style: GoogleFonts.poppins(
                    fontSize: compact ? 36 : 48,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                    height: 1.0,
                    letterSpacing: -2,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStars(_ratingAvg, size: compact ? 14 : 18),
                const SizedBox(height: 4),
                Text(
                  '$_ratingCount review${_ratingCount != 1 ? 's' : ''}',
                  style: AppTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(width: 20),
            const VerticalDivider(
              width: 1,
              thickness: 1,
              color: AppTheme.divider,
            ),
            const SizedBox(width: 20),
            // Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Course Rating',
                    style: AppTheme.overline.copyWith(letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.courseTitle,
                    style: AppTheme.cardTitle,
                    maxLines: compact ? 2 : 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Review card ────────────────────────────────────────────────────────────

  Widget _buildReviewCard(dynamic r) {
    final double reviewRating = double.tryParse(r['rating'].toString()) ?? 0.0;
    final String displayName = (r['display_name'] as String?) ?? 'Student';
    final String content = (r['comment_content'] as String?) ?? '';
    final String date = _formatDate(r['comment_date'] ?? '');
    final bool isMyReview = r['is_mine'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
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
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildReviewerAvatar(r),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              displayName,
                              style: AppTheme.cardTitle.copyWith(fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isMyReview)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
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
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildStars(reviewRating, size: 13),
                          const SizedBox(width: 8),
                          Text(date, style: AppTheme.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (content.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppTheme.divider),
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
  }

  // ── Write-a-review card ────────────────────────────────────────────────────

  Widget _buildWriteReviewSection({bool compact = false}) {
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
      child: compact
          ? _buildWriteReviewLandscape()
          : _buildWriteReviewPortrait(),
    );
  }

  Widget _buildWriteReviewPortrait() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reviewFormHeader(),
        const SizedBox(height: 16),
        _starSelector(horizontal: true),
        const SizedBox(height: 16),
        _commentField(minLines: 4),
        const SizedBox(height: 16),
        _submitButton(),
      ],
    );
  }

  // Landscape: header → stars (horizontal row) → text field → button
  // All stacked vertically, same as portrait but with reduced spacing/minLines
  Widget _buildWriteReviewLandscape() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _reviewFormHeader(),
        const SizedBox(height: 12),
        _starSelector(horizontal: true),
        const SizedBox(height: 12),
        _commentField(minLines: 2),
        const SizedBox(height: 12),
        _submitButton(),
      ],
    );
  }

  Widget _reviewFormHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
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
      ],
    );
  }

  Widget _starSelector({required bool horizontal}) {
    final stars = List.generate(5, (index) {
      final filled = index < _selectedRating;
      return GestureDetector(
        onTap: () => setState(() => _selectedRating = index + 1.0),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            color: filled ? Colors.amber[500] : Colors.grey[300],
            size: 32,
          ),
        ),
      );
    });

    return horizontal
        ? Row(mainAxisAlignment: MainAxisAlignment.start, children: stars)
        : Column(mainAxisAlignment: MainAxisAlignment.center, children: stars);
  }

  Widget _commentField({int minLines = 4}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: TextField(
        controller: _commentController,
        style: AppTheme.bodyMedium,
        minLines: minLines,
        maxLines: null,
        textInputAction: TextInputAction.newline,
        decoration: InputDecoration(
          hintText: 'Share your experience with this course...',
          hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textHint),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(14),
        ),
      ),
    );
  }

  Widget _submitButton() {
    return SizedBox(
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
    );
  }

  // ── Delete section ─────────────────────────────────────────────────────────

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
