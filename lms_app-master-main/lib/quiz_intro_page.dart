import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'quiz_taking_page.dart';

class QuizIntroPage extends StatefulWidget {
  final int quizId;
  final String quizTitle;

  const QuizIntroPage({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizIntroPage> createState() => _QuizIntroPageState();
}

class _QuizIntroPageState extends State<QuizIntroPage> {
  bool _isLoading = true;
  String _attemptsLeft = "Checking...";
  bool _canRetake = false;
  String? _pastAttemptId; // Store the ID for review mode

  @override
  void initState() {
    super.initState();
    _checkAttempts();
  }

  // --- MERGED LOGIC: Check Status & Past Attempts ---
  Future<void> _checkAttempts() async {
    setState(() => _isLoading = true);

    try {
      // 1. Fetch list of past attempts
      // Note: Ensure getQuizAttempts is defined in your ApiService!
      final attempts = await apiService.getQuizAttempts(widget.quizId);

      // 2. Analyze them
      if (attempts.isNotEmpty) {
        // Grab the latest attempt
        final latest = attempts.first;
        _pastAttemptId = latest['attempt_id'].toString();

        setState(() {
          _attemptsLeft = "Limit Reached";
          _canRetake = false; // Block new attempts
          _isLoading = false;
        });
      } else {
        // No attempts found -> User can start
        setState(() {
          _attemptsLeft = "1 Attempt Available";
          _canRetake = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback: If API fails or endpoint missing, assume available (Gatekeeper will catch later)
      debugPrint("Error checking attempts: $e");
      setState(() {
        _attemptsLeft = "Available";
        _canRetake = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F3E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F3E7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Quiz",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.quizTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2D2D2D),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFFEEEEEE), thickness: 1.5),
              const SizedBox(height: 24),

              _buildDetailRow("Questions:", "10"),
              // Show dynamic status based on check
              _buildDetailRow("Status:", _attemptsLeft),
              _buildDetailRow("Passing Grade:", "70%"),

              const SizedBox(height: 40),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        // Change color: Brown if Retake available, Grey if Review mode
                        backgroundColor: _canRetake
                            ? const Color(0xFF6D391E)
                            : Colors.grey[700],
                        disabledBackgroundColor: Colors.grey[400],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      // Disable if loading
                      onPressed: _isLoading
                          ? null
                          : () {
                              if (_canRetake) {
                                // ✅ START NEW QUIZ
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        QuizTakingPage(quizId: widget.quizId),
                                  ),
                                );
                              } else if (_pastAttemptId != null) {
                                // ✅ REVIEW PAST ATTEMPT
                                // Ensure QuizReviewPage is imported!
                                /* Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => QuizReviewPage(attemptId: _pastAttemptId!),
                            ),
                          );
                          */
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Review Mode Coming Soon!"),
                                  ),
                                );
                              }
                            },
                      child: Text(
                        _isLoading
                            ? "Loading..."
                            : (_canRetake ? "Start Quiz" : "Review Attempt"),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        foregroundColor: Colors.grey,
                      ),
                      child: const Text(
                        "Skip Quiz",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
