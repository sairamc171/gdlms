import 'package:flutter/material.dart';
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
  Map<String, dynamic>? _myReview; // Track current user's review
  double _ratingAvg = 0.0;
  int _ratingCount = 0;
  bool _isLoading = true;
  final Color primaryBrown = const Color(0xFF6D391E);

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  Future<void> _fetchReviews({bool showLoader = true}) async {
    if (showLoader) setState(() => _isLoading = true);

    final data = await apiService.getCourseRatings(widget.courseId);

    if (mounted && data != null) {
      final List<dynamic> allReviews = data['reviews'] ?? [];

      // Identify current user's review by matching display_name from ApiService
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

  // --- New Delete Review Logic ---
  Future<void> _handleDeleteReview() async {
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete your review?"),
        content: const Text(
          "This will remove your previous rating so you can write a new one.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Delete",
              style: TextStyle(color: Color(0xFF6D391E)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);

      // Attempt to delete
      bool success = await apiService.deleteReview(widget.courseId);

      if (mounted) {
        // POLISH: Even if it fails (because the review was already deleted),
        // we refresh the list to clear "ghost" reviews from the UI.
        await _fetchReviews(showLoader: true);

        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Review removed.")));
        } else {
          // If it failed but the refresh cleared the review, the user is still happy.
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("List updated.")));
        }
      }
    }
  }

  void _showWriteReviewSheet() {
    double selectedRating = 5.0;
    final TextEditingController commentController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: StatefulBuilder(
          builder: (builderContext, setInternalState) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Rate this Course",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return IconButton(
                      icon: Icon(
                        index < selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.orange,
                        size: 36,
                      ),
                      onPressed: () =>
                          setInternalState(() => selectedRating = index + 1.0),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentController,
                  decoration: const InputDecoration(
                    hintText: "Write your experience...",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isSubmitting
                          ? Colors.grey
                          : primaryBrown,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (commentController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please write a comment first.",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            setInternalState(() => isSubmitting = true);

                            bool success = await apiService.submitReview(
                              widget.courseId,
                              selectedRating,
                              commentController.text,
                            );

                            if (!builderContext.mounted) return;

                            if (success) {
                              Navigator.pop(modalContext);
                              await Future.delayed(
                                const Duration(milliseconds: 500),
                              );
                              if (mounted) {
                                _fetchReviews();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Review submitted successfully!",
                                      ),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              }
                            } else {
                              setInternalState(() => isSubmitting = false);
                              ScaffoldMessenger.of(modalContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Failed to post review. You may have already reviewed this course.",
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            "Post Review",
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  Widget _buildReviewerAvatar(dynamic review) {
    final String photoUrl = (review['profile_photo'] as String?) ?? '';
    final String name = (review['display_name'] as String?) ?? 'Student';
    final String initials = _getInitials(name);

    if (photoUrl.isNotEmpty && photoUrl.startsWith('http')) {
      return ClipOval(
        child: Image.network(
          photoUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          headers: const {
            'Cache-Control': 'no-cache, no-store, must-revalidate',
            'Pragma': 'no-cache',
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 44,
              height: 44,
              color: Colors.grey[200],
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: primaryBrown,
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                      : null,
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
      radius: 22,
      backgroundColor: primaryBrown,
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Reviews"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  color: Colors.grey[100],
                  child: Row(
                    children: [
                      Text(
                        _ratingAvg.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < _ratingAvg.floor()
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.orange,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "$_ratingCount Reviews",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => _fetchReviews(showLoader: false),
                    child: _reviews.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 100),
                              Center(
                                child: Text("No reviews yet. Be the first!"),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _reviews.length,
                            itemBuilder: (context, index) {
                              final r = _reviews[index];
                              final double reviewRating =
                                  double.tryParse(r['rating'].toString()) ??
                                  0.0;
                              final String displayName =
                                  (r['display_name'] as String?) ?? 'Student';
                              final String content =
                                  (r['comment_content'] as String?) ?? '';
                              final String date = _formatDate(
                                r['comment_date'] ?? '',
                              );

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                                Text(
                                                  displayName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 15,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: List.generate(
                                                    5,
                                                    (i) => Icon(
                                                      i < reviewRating.floor()
                                                          ? Icons.star
                                                          : Icons.star_border,
                                                      size: 15,
                                                      color:
                                                          i <
                                                              reviewRating
                                                                  .floor()
                                                          ? Colors.orange
                                                          : Colors.grey[400],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Text(
                                            date,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (content.isNotEmpty) ...[
                                        const SizedBox(height: 12),
                                        Text(
                                          content,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: _myReview == null
                        ? ElevatedButton(
                            onPressed: _showWriteReviewSheet,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBrown,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              "Write a Review",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _handleDeleteReview,
                            icon: const Icon(
                              Icons.delete,
                              color: Color(0xFF6D391E),
                            ),
                            label: const Text(
                              "Delete My Review",
                              style: TextStyle(
                                color: Color(0xFF6D391E),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              elevation: 2,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(
                                color: Color(0xFF6D391E),
                                width: 1,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}
