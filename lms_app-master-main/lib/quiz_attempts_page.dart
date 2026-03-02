import 'package:flutter/material.dart';
import 'app_theme.dart';
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
      final attempts = await apiService.getAllUserQuizAttempts();
      setState(() {
        _allAttempts = attempts;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading quiz attempts: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(title: "Quiz Attempts"),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            )
          : _allAttempts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.quiz_outlined, size: 56, color: Colors.grey[300]),
                  const SizedBox(height: 14),
                  Text(
                    "No quiz attempts yet",
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Complete a quiz to see results here",
                    style: AppTheme.labelSmall,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAllAttempts,
              color: AppTheme.primary,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
                itemCount: _allAttempts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) =>
                    _buildAttemptCard(_allAttempts[index]),
              ),
            ),
    );
  }

  Widget _buildAttemptCard(Map<String, dynamic> attempt) {
    final quizTitle = attempt['quiz_title'] ?? 'Unknown Quiz';
    final totalQuestions = attempt['total_questions'] ?? 0;
    final totalCorrect = attempt['total_correct'] ?? 0;
    final totalMarks = _parseDouble(attempt['total_marks']);
    final earnedMarks = _parseDouble(attempt['earned_marks']);
    final double percentage = totalMarks > 0
        ? (earnedMarks / totalMarks) * 100
        : 0;
    final bool isPassed = percentage >= 70;
    final Color statusColor = isPassed ? AppTheme.completed : Colors.red[700]!;

    return Container(
      decoration: AppTheme.cardDecoration,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header strip ────────────────────────────────
            Container(
              width: double.infinity,
              height: 4,
              color: statusColor.withValues(alpha: 0.6),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title + status pill
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          quizTitle,
                          style: AppTheme.cardTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          isPassed ? "Passed" : "Failed",
                          style: AppTheme.labelSmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  AppTheme.cardDivider,
                  const SizedBox(height: 16),

                  // Stats row
                  Row(
                    children: [
                      Expanded(
                        child: _buildStat(
                          "Score",
                          "${percentage.toInt()}%",
                          statusColor,
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppTheme.divider),
                      Expanded(
                        child: _buildStat(
                          "Correct",
                          "$totalCorrect / $totalQuestions",
                          AppTheme.primary,
                        ),
                      ),
                      Container(width: 1, height: 36, color: AppTheme.divider),
                      Expanded(
                        child: _buildStat(
                          "Marks",
                          "${earnedMarks.toInt()} / ${totalMarks.toInt()}",
                          AppTheme.inProgress,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: AppTheme.statCount.copyWith(fontSize: 20, color: color),
        ),
        const SizedBox(height: 3),
        Text(label, style: AppTheme.labelSmall),
      ],
    );
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
