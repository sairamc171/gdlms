import 'package:flutter/material.dart';
import '../services/api_service.dart';

class QuizAttemptsPage extends StatefulWidget {
  const QuizAttemptsPage({super.key});

  @override
  State<QuizAttemptsPage> createState() => _QuizAttemptsPageState();
}

class _QuizAttemptsPageState extends State<QuizAttemptsPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allAttempts = [];

  @override
  void initState() {
    super.initState();
    _loadAllAttempts();
  }

  Future<void> _loadAllAttempts() async {
    setState(() => _isLoading = true);

    try {
      // Get all quiz attempts for the current user
      final attempts = await apiService.getAllUserQuizAttempts();

      setState(() {
        _allAttempts = attempts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading quiz attempts: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F3E7),
      appBar: AppBar(
        title: const Text("Quiz Attempts"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6D391E)),
            )
          : _allAttempts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    "No quiz attempts yet",
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllAttempts,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _allAttempts.length,
                itemBuilder: (context, index) {
                  final attempt = _allAttempts[index];
                  return _buildAttemptCard(attempt);
                },
              ),
            ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final quizTitle = attempt['quiz_title'] ?? 'Unknown Quiz';
    final totalQuestions = attempt['total_questions'] ?? 0;
    final totalCorrect = attempt['total_correct'] ?? 0;

    // Handle both string and numeric values from API
    final totalMarks = _parseDouble(attempt['total_marks']);
    final earnedMarks = _parseDouble(attempt['earned_marks']);

    final attemptStatus = attempt['attempt_status'] ?? 'completed';
    final attemptDate =
        attempt['attempt_ended_at'] ?? attempt['attempt_started_at'] ?? '';

    // Calculate percentage
    final percentage = totalMarks > 0 ? (earnedMarks / totalMarks) * 100 : 0;

    // Check pass status from BOTH calculation AND database status
    final calculatedPass = percentage >= 70;
    final databasePass = attemptStatus.toLowerCase() == 'passed';
    final isPassed = calculatedPass || databasePass;

    debugPrint('Quiz: $quizTitle');
    debugPrint('Marks: $earnedMarks/$totalMarks');
    debugPrint('Percentage: $percentage%');
    debugPrint('Status from DB: $attemptStatus');
    debugPrint(
      'Calculated Pass: $calculatedPass, DB Pass: $databasePass, Final: $isPassed',
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    quizTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D2D2D),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isPassed
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isPassed
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    isPassed ? "Passed" : "Failed",
                    style: TextStyle(
                      color: isPassed ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  "Score",
                  "${percentage.toInt()}%",
                  isPassed ? Colors.green : Colors.red,
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _buildStatItem(
                  "Correct",
                  "$totalCorrect/$totalQuestions",
                  Colors.blue,
                ),
                Container(width: 1, height: 40, color: Colors.grey[300]),
                _buildStatItem(
                  "Marks",
                  "${earnedMarks.toInt()}/${totalMarks.toInt()}",
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  _formatDate(attemptDate),
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const Spacer(),
                Text(
                  attemptStatus.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return 'Unknown date';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
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
}
