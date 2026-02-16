import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'quiz_taking_page.dart';
import 'quiz_result_page.dart';

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
  Map<String, dynamic>? _latestAttempt;

  @override
  void initState() {
    super.initState();
    _checkAttempts();
  }

  Future<void> _checkAttempts() async {
    setState(() => _isLoading = true);
    try {
      final attempts = await apiService.getQuizAttempts(widget.quizId);
      if (attempts.isNotEmpty) {
        final latest = attempts.first;
        _latestAttempt = latest;

        // Check if quiz was passed - handle both string and numeric types
        final totalMarks = _parseDouble(latest['total_marks']);
        final earnedMarks = _parseDouble(latest['earned_marks']);
        final percentage = totalMarks > 0
            ? (earnedMarks / totalMarks) * 100
            : 0;

        // Also check the database status
        final attemptStatus = (latest['attempt_status'] ?? '')
            .toString()
            .toLowerCase();
        final calculatedPass = percentage >= 70;
        final databasePass = attemptStatus == 'passed';
        final isPassed = calculatedPass || databasePass;

        debugPrint('=== Quiz Intro Check ===');
        debugPrint('Quiz ID: ${widget.quizId}');
        debugPrint('Marks: $earnedMarks/$totalMarks');
        debugPrint('Percentage: $percentage%');
        debugPrint('Status from DB: $attemptStatus');
        debugPrint('Final Pass Status: $isPassed');

        setState(() {
          _attemptsLeft = isPassed ? "Passed" : "Failed";
          _canRetake = false;
          _isLoading = false;
        });

        // Automatically navigate to results page after a brief delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && !_canRetake && _latestAttempt != null) {
            debugPrint('Auto-navigating to results...');
            _showResults();
          }
        });
      } else {
        setState(() {
          _attemptsLeft = "1 Attempt Available";
          _canRetake = true;
          _isLoading = false;
          _latestAttempt = null;
        });
      }
    } catch (e) {
      debugPrint('Error checking attempts: $e');
      setState(() {
        _attemptsLeft = "Available";
        _canRetake = true;
        _isLoading = false;
        _latestAttempt = null;
      });
    }
  }

  void _showResults() {
    if (_latestAttempt == null) {
      debugPrint('Cannot show results - no attempt data');
      return;
    }

    // Safely parse integers from attempt data
    final totalQuestions = _parseInt(_latestAttempt!['total_questions']);
    final totalCorrect = _parseInt(_latestAttempt!['total_correct']);

    debugPrint('Navigating to results: $totalCorrect/$totalQuestions');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultPage(
          totalQuestions: totalQuestions,
          correctAnswers: totalCorrect,
        ),
      ),
    ).then((_) {
      // Pop back to course details after viewing results
      if (mounted) {
        Navigator.pop(context, false);
      }
    });
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
          onPressed: () => Navigator.pop(context, false),
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
              _buildDetailRow("Status:", _attemptsLeft),
              _buildDetailRow("Passing Grade:", "70%"),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _canRetake
                        ? const Color(0xFF6D391E)
                        : Colors.grey[700],
                    disabledBackgroundColor: Colors.grey[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (_canRetake) {
                            // Navigate to quiz and wait for completion signal
                            final bool? completed = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    QuizTakingPage(quizId: widget.quizId),
                              ),
                            );

                            // If completed successfully, pop this intro page and return true to course details
                            if (completed == true && mounted) {
                              Navigator.pop(context, true);
                            }
                          } else if (_latestAttempt != null) {
                            // Show results for completed quiz
                            _showResults();
                          }
                        },
                  child: Text(
                    _isLoading
                        ? "Loading..."
                        : (_canRetake ? "Start Quiz" : "View Results"),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
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

  /// Helper method to safely parse double values from API
  /// Handles both string and numeric types
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Helper method to safely parse integer values from API
  /// Handles both string and numeric types
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
