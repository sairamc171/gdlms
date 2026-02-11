import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../services/api_service.dart';
import 'quiz_result_page.dart'; // Ensure this exists

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

  // 🆕 TRACK SCORE
  int _correctAnswersCount = 0;

  @override
  void initState() {
    super.initState();
    // Use the Custom API directly
    _loadQuizFuture = _initQuizSequence();
  }

  Future<List<QuizQuestion>> _initQuizSequence() async {
    try {
      return await apiService.getQuizQuestions(widget.quizId);
    } catch (e) {
      return [];
    }
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
        automaticallyImplyLeading: false, // Prevents accidental back navigation
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
                // Header
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
                    const Text(
                      "Instant Feedback",
                      style: TextStyle(
                        color: Color(0xFF6D391E),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Question Text
                Text(
                  "${_currentIndex + 1}. ${currentQuestion.text}",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 30),

                // Options List
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildOptions(currentQuestion),
                  ),
                ),

                // Navigation Button
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
                    // 🚀 NEXT / FINISH LOGIC
                    onPressed: () async {
                      if (_selectedOptionHash == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Please select an answer"),
                          ),
                        );
                        return;
                      }

                      final selectedOption = currentQuestion.options.firstWhere(
                        (o) => o.text.hashCode == _selectedOptionHash,
                        orElse: () => QuizOption(text: '', isCorrect: false),
                      );

                      if (selectedOption.isCorrect) _correctAnswersCount++;

                      if (_currentIndex < questions.length - 1) {
                        setState(() {
                          _currentIndex++;
                          _selectedOptionHash = null;
                        });
                      } else {
                        // 🏁 SYNC PROGRESS WITH THE WEBSITE
                        // Pass 'itemType: quiz' to trigger Tutor LMS completion
                        await apiService.syncLessonWithWebsite(
                          widget.quizId,
                          itemType: 'quiz',
                        );

                        if (!mounted) return;
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuizResultPage(
                              totalQuestions: questions.length,
                              correctAnswers: _correctAnswersCount,
                            ),
                          ),
                        );
                      }
                    },
                    child: Text(
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

  // Instant Feedback UI
  Widget _buildOptions(QuizQuestion question) {
    return Column(
      children: question.options.map((option) {
        bool isSelected = _selectedOptionHash == option.text.hashCode;

        // FEEDBACK LOGIC
        Color bgColor = Colors.white;
        Color borderColor = Colors.grey.shade300;
        IconData icon = Icons.radio_button_unchecked;
        Color iconColor = Colors.grey;

        if (_selectedOptionHash != null) {
          if (option.isCorrect) {
            // Always show correct answer in green
            bgColor = Colors.green.shade50;
            borderColor = Colors.green;
            icon = Icons.check_circle;
            iconColor = Colors.green;
          } else if (isSelected) {
            // Show wrong selection in red
            bgColor = Colors.red.shade50;
            borderColor = Colors.red;
            icon = Icons.cancel;
            iconColor = Colors.red;
          }
        } else if (isSelected) {
          borderColor = const Color(0xFF6D391E);
          icon = Icons.radio_button_checked;
          iconColor = const Color(0xFF6D391E);
        }

        return GestureDetector(
          onTap: () {
            if (_selectedOptionHash != null) return; // Prevent changing answer
            setState(() {
              _selectedOptionHash = option.text.hashCode;
            });
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
                Icon(icon, color: iconColor, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    option.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isSelected || _selectedOptionHash != null
                          ? Colors.black87
                          : Colors.black54,
                    ),
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
