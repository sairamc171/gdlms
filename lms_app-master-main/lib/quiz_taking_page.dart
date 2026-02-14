import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../services/api_service.dart';
import 'quiz_result_page.dart';

class QuizTakingPage extends StatefulWidget {
  final int quizId;
  const QuizTakingPage({super.key, required this.quizId});

  @override
  State<QuizTakingPage> createState() => _QuizTakingPageState();
}

class _QuizTakingPageState extends State<QuizTakingPage> {
  late Future<List<QuizQuestion>> _loadQuizFuture;
  int _currentIndex = 0;
  int? _selectedOptionHash;
  int _correctAnswersCount = 0;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadQuizFuture = _initQuizSequence();
  }

  Future<List<QuizQuestion>> _initQuizSequence() async {
    return await apiService.getQuizQuestions(widget.quizId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F3E7),
      appBar: AppBar(
        title: const Text("Quiz Practice Mode"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: FutureBuilder<List<QuizQuestion>>(
        future: _loadQuizFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6D391E)),
            );
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return const Center(child: Text("Error loading quiz questions."));
          }

          final questions = snapshot.data!;
          final currentQuestion = questions[_currentIndex];
          final bool isLastQuestion = _currentIndex == questions.length - 1;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Question: ${_currentIndex + 1}/${questions.length}",
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  "${_currentIndex + 1}. ${currentQuestion.text}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildOptions(currentQuestion),
                  ),
                ),
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
                    onPressed: _isSubmitting
                        ? null
                        : () async {
                            if (_selectedOptionHash == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please select an answer"),
                                ),
                              );
                              return;
                            }

                            final selectedOption = currentQuestion.options
                                .firstWhere(
                                  (o) => o.text.hashCode == _selectedOptionHash,
                                  orElse: () =>
                                      QuizOption(text: '', isCorrect: false),
                                );

                            if (selectedOption.isCorrect)
                              _correctAnswersCount++;

                            if (_currentIndex < questions.length - 1) {
                              setState(() {
                                _currentIndex++;
                                _selectedOptionHash = null;
                              });
                            } else {
                              setState(() => _isSubmitting = true);

                              final result = await apiService
                                  .syncLessonWithWebsite(
                                    widget.quizId,
                                    itemType: 'quiz',
                                    earnedMarks: _correctAnswersCount,
                                  );

                              if (!mounted) return;

                              if (result != null && result['success'] == true) {
                                // Wait for result from Result Page
                                final bool? refreshNeeded =
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => QuizResultPage(
                                          totalQuestions: questions.length,
                                          correctAnswers: _correctAnswersCount,
                                        ),
                                      ),
                                    );

                                // If ResultPage returned true, pop this page with true
                                if (mounted) {
                                  Navigator.pop(
                                    context,
                                    refreshNeeded ?? false,
                                  );
                                }
                              } else {
                                setState(() => _isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Server sync failed. Please check your connection.",
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            isLastQuestion ? "Finish Quiz" : "Next Question",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptions(QuizQuestion question) {
    return Column(
      children: question.options.map((option) {
        bool isSelected = _selectedOptionHash == option.text.hashCode;
        Color bgColor = Colors.white;
        Color borderColor = Colors.grey.shade300;
        IconData icon = Icons.radio_button_unchecked;

        if (_selectedOptionHash != null) {
          if (option.isCorrect) {
            bgColor = Colors.green.shade50;
            borderColor = Colors.green;
            icon = Icons.check_circle;
          } else if (isSelected) {
            bgColor = Colors.red.shade50;
            borderColor = Colors.red;
            icon = Icons.cancel;
          }
        } else if (isSelected) {
          borderColor = const Color(0xFF6D391E);
          icon = Icons.radio_button_checked;
        }

        return GestureDetector(
          onTap: () {
            if (_selectedOptionHash != null) return;
            setState(() => _selectedOptionHash = option.text.hashCode);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected || option.isCorrect
                      ? (option.isCorrect ? Colors.green : Colors.red)
                      : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}
