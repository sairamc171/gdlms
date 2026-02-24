import 'package:flutter/material.dart';

class QuizResultPage extends StatelessWidget {
  final int totalQuestions;
  final int correctAnswers;
  final int? quizId;
  final String? quizTitle;

  const QuizResultPage({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    this.quizId,
    this.quizTitle,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage = (totalQuestions > 0)
        ? (correctAnswers / totalQuestions) * 100
        : 0;
    final bool isPassed = percentage >= 70;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Quiz Results"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 150,
                  height: 150,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    color: isPassed ? Colors.green : Colors.red,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${percentage.toInt()}%",
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      isPassed ? "Passed" : "Failed",
                      style: TextStyle(
                        fontSize: 18,
                        color: isPassed ? Colors.green : Colors.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                _buildStatCard("Total", "$totalQuestions", Colors.blue),
                const SizedBox(width: 16),
                _buildStatCard("Correct", "$correctAnswers", Colors.green),
                const SizedBox(width: 16),
                _buildStatCard(
                  "Wrong",
                  "${totalQuestions - correctAnswers}",
                  Colors.red,
                ),
              ],
            ),
            const SizedBox(height: 30),
            Text(
              isPassed
                  ? "Excellent! You've passed this quiz."
                  : "You need 70% to pass. Review the material and try again!",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const Spacer(),
            // Retry button — only shown on failure
            if (!isPassed) ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6D391E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop('retake'),
                  child: const Text(
                    "Retry Quiz",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPassed
                      ? const Color(0xFF6D391E)
                      : Colors.grey[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(
                  "Back to Course",
                  style: TextStyle(
                    color: isPassed ? Colors.white : Colors.grey[700],
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
