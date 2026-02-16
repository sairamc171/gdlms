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
      setState(() {
        _reviews = data['reviews'] ?? [];
        _ratingAvg = (data['rating_avg'] ?? 0.0).toDouble();
        _ratingCount = (data['rating_count'] ?? 0);
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
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
                // Rating Summary
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

                // Reviews List
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

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: primaryBrown
                                                .withValues(alpha: 0.1),
                                            child: Icon(
                                              Icons.person,
                                              color: primaryBrown,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r['display_name'] ??
                                                      "Student",
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Row(
                                                  children: List.generate(
                                                    5,
                                                    (i) => Icon(
                                                      Icons.star,
                                                      size: 14,
                                                      color:
                                                          i <
                                                              reviewRating
                                                                  .floor()
                                                          ? Colors.orange
                                                          : Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),
                                      Text(r['comment_content'] ?? ""),
                                      const SizedBox(height: 8),
                                      Text(
                                        r['comment_date'] ?? "",
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),

                // Write Review Button
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
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
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
