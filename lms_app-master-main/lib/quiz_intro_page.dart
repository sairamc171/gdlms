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
  bool _hasPreviousAttempt = false;
  bool _isPassed = false;
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

      // Filter to only real completed attempts (must have ended_at and marks)
      final completedAttempts = attempts.where((a) {
        final endedAt = a['attempt_ended_at']?.toString() ?? '';
        final status = a['attempt_status']?.toString().toLowerCase() ?? '';
        final earnedMarks = _parseDouble(a['earned_marks']);
        final totalMarks = _parseDouble(a['total_marks']);

        // A real attempt must have: a finished status AND total marks > 0
        final hasValidStatus = [
          'finished',
          'passed',
          'failed',
          'attempt_ended',
        ].contains(status);
        final hasMarks = totalMarks > 0;
        final hasEndTime =
            endedAt.isNotEmpty && endedAt != '0000-00-00 00:00:00';

        return hasValidStatus && hasMarks && hasEndTime;
      }).toList();

      if (completedAttempts.isNotEmpty) {
        final latest = completedAttempts.first;
        _latestAttempt = latest;

        final totalMarks = _parseDouble(latest['total_marks']);
        final earnedMarks = _parseDouble(latest['earned_marks']);
        final percentage = totalMarks > 0
            ? (earnedMarks / totalMarks) * 100
            : 0;
        final dbStatus =
            latest['attempt_status']?.toString().toLowerCase() ?? '';

        final isPassed = percentage >= 70 || dbStatus == 'passed';

        setState(() {
          _hasPreviousAttempt = true;
          _isPassed = isPassed;
          _isLoading = false;
        });

        // Only auto-navigate to results if passed (failed = allow retry)
        if (isPassed) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) _showResults();
          });
        }
      } else {
        setState(() {
          _hasPreviousAttempt = false;
          _isPassed = false;
          _isLoading = false;
          _latestAttempt = null;
        });
      }
    } catch (e) {
      debugPrint('Error checking attempts: $e');
      setState(() {
        _hasPreviousAttempt = false;
        _isPassed = false;
        _isLoading = false;
        _latestAttempt = null;
      });
    }
  }

  void _showResults() {
    if (_latestAttempt == null) return;

    final totalQuestions = _parseInt(_latestAttempt!['total_questions']);
    final totalCorrect = _parseInt(_latestAttempt!['total_correct']);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultPage(
          totalQuestions: totalQuestions,
          correctAnswers: totalCorrect,
          quizId: widget.quizId,
          quizTitle: widget.quizTitle,
        ),
      ),
    ).then((result) {
      if (!mounted) return;
      if (result == 'retake') {
        // User wants to retake — go to quiz taking page
        _startQuiz();
      } else {
        Navigator.pop(context, result == true);
      }
    });
  }

  Future<void> _startQuiz() async {
    final bool? completed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizTakingPage(quizId: widget.quizId),
      ),
    );
    if (completed == true && mounted) {
      Navigator.pop(context, true);
    } else if (mounted) {
      // Refresh attempt status after retake
      _checkAttempts();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine button label and action
    String buttonLabel;
    if (_isLoading) {
      buttonLabel = "Loading...";
    } else if (!_hasPreviousAttempt) {
      buttonLabel = "Start Quiz";
    } else if (_isPassed) {
      buttonLabel = "View Results";
    } else {
      buttonLabel = "Retry Quiz";
    }

    String statusLabel;
    if (_isLoading) {
      statusLabel = "Checking...";
    } else if (!_hasPreviousAttempt) {
      statusLabel = "Not attempted";
    } else if (_isPassed) {
      statusLabel = "Passed ✓";
    } else {
      statusLabel = "Failed — Retry available";
    }

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
              _buildDetailRow("Status:", statusLabel),
              _buildDetailRow("Passing Grade:", "70%"),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D391E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: _isLoading
                      ? null
                      : () {
                          if (_hasPreviousAttempt && _isPassed) {
                            _showResults();
                          } else {
                            _startQuiz();
                          }
                        },
                  child: Text(
                    buttonLabel,
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

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
