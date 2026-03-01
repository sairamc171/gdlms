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

class _QuizTakingPageState extends State<QuizTakingPage>
    with SingleTickerProviderStateMixin {
  late Future<List<QuizQuestion>> _loadQuizFuture;
  int _currentIndex = 0;
  int? _selectedOptionHash;
  int _correctAnswersCount = 0;
  bool _isSubmitting = false;
  late AnimationController _questionAnimController;
  late Animation<double> _questionFade;
  late Animation<Offset> _questionSlide;

  @override
  void initState() {
    super.initState();
    _loadQuizFuture = _initQuizSequence();
    _questionAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _questionFade = CurvedAnimation(
      parent: _questionAnimController,
      curve: Curves.easeOut,
    );
    _questionSlide =
        Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _questionAnimController,
            curve: Curves.easeOut,
          ),
        );
    _questionAnimController.forward();
  }

  @override
  void dispose() {
    _questionAnimController.dispose();
    super.dispose();
  }

  Future<List<QuizQuestion>> _initQuizSequence() async {
    return await apiService.getQuizQuestions(widget.quizId);
  }

  void _animateNextQuestion() {
    _questionAnimController.forward(from: 0);
  }

  void _resetQuiz() {
    setState(() {
      _currentIndex = 0;
      _selectedOptionHash = null;
      _correctAnswersCount = 0;
      _isSubmitting = false;
      _loadQuizFuture = _initQuizSequence();
    });
    _questionAnimController.forward(from: 0);
  }

  Future<void> _handleFinish(int totalQuestions) async {
    setState(() => _isSubmitting = true);

    await apiService.syncLessonWithWebsite(
      widget.quizId,
      itemType: 'quiz',
      earnedMarks: _correctAnswersCount,
    );

    if (!mounted) return;

    final dynamic quizResult = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizResultPage(
          totalQuestions: totalQuestions,
          correctAnswers: _correctAnswersCount,
        ),
      ),
    );

    if (mounted) {
      if (quizResult == 'retake') {
        _resetQuiz();
      } else {
        Navigator.pop(context, quizResult ?? false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F3E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F3E7),
        elevation: 0,
        foregroundColor: const Color(0xFF2C1A0E),
        title: const Text(
          "Quiz",
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C1A0E),
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: FutureBuilder<List<QuizQuestion>>(
        future: _loadQuizFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF6D391E),
                strokeWidth: 2.5,
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Could not load questions.",
                style: TextStyle(color: Color(0xFF6D391E)),
              ),
            );
          }

          final questions = snapshot.data!;
          final currentQuestion = questions[_currentIndex];
          final progress = (_currentIndex + 1) / questions.length;

          return SafeArea(
            child: Column(
              children: [
                // Progress bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Question ${_currentIndex + 1} of ${questions.length}",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9E7B5A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            "${(progress * 100).toInt()}%",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6D391E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE8D8C4),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF6D391E),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                Expanded(
                  child: FadeTransition(
                    opacity: _questionFade,
                    child: SlideTransition(
                      position: _questionSlide,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Question card
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF6D391E,
                                    ).withOpacity(0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Text(
                                currentQuestion.text,
                                style: const TextStyle(
                                  fontFamily: 'Georgia',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2C1A0E),
                                  height: 1.5,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Options
                            Expanded(
                              child: ListView(
                                children: _buildOptions(currentQuestion),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Bottom button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedOptionHash != null
                          ? const Color(0xFF6D391E)
                          : const Color(0xFFBFA080),
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: (_isSubmitting || _selectedOptionHash == null)
                        ? null
                        : () async {
                            final selected = currentQuestion.options.firstWhere(
                              (o) => o.text.hashCode == _selectedOptionHash,
                            );
                            if (selected.isCorrect) _correctAnswersCount++;

                            if (_currentIndex < questions.length - 1) {
                              setState(() {
                                _currentIndex++;
                                _selectedOptionHash = null;
                              });
                              _animateNextQuestion();
                            } else {
                              _handleFinish(questions.length);
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _currentIndex == questions.length - 1
                                ? "Finish Quiz"
                                : "Next Question",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
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

  List<Widget> _buildOptions(QuizQuestion question) {
    return question.options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isSelected = _selectedOptionHash == option.text.hashCode;
      final labels = ['A', 'B', 'C', 'D', 'E', 'F'];
      final label = index < labels.length ? labels[index] : '${index + 1}';

      return GestureDetector(
        onTap: () => setState(() => _selectedOptionHash = option.text.hashCode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6D391E).withOpacity(0.08)
                : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6D391E)
                  : const Color(0xFFE0CDB8),
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF6D391E).withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF6D391E)
                      : const Color(0xFFF0E6D8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF9E7B5A),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isSelected
                        ? const Color(0xFF2C1A0E)
                        : const Color(0xFF4A3728),
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
