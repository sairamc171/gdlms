import 'package:flutter/material.dart';
import '../models/quiz_models.dart';
import '../services/api_service.dart';
import 'quiz_result_page.dart';

class QuizTakingPage extends StatefulWidget {
  final int quizId;
  final List<int> allLessonIds;
  const QuizTakingPage({
    super.key,
    required this.quizId,
    this.allLessonIds = const [],
  });

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
    _loadQuizFuture = apiService.getQuizQuestions(widget.quizId);
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

  void _animateNextQuestion() => _questionAnimController.forward(from: 0);

  void _resetQuiz() {
    setState(() {
      _currentIndex = 0;
      _selectedOptionHash = null;
      _correctAnswersCount = 0;
      _isSubmitting = false;
      _loadQuizFuture = apiService.getQuizQuestions(widget.quizId);
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
          allLessonIds: widget.allLessonIds,
          currentQuizId: widget.quizId,
          onBackToLesson: () {
            // Pop result page, then taking page, then intro page → lands on lesson player
            int count = 0;
            Navigator.of(context).popUntil((_) => count++ >= 3);
          },
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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Quiz",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        automaticallyImplyLeading: true,
      ),
      body: FutureBuilder<List<QuizQuestion>>(
        future: _loadQuizFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                "Could not load questions.",
                style: TextStyle(color: Colors.black54),
              ),
            );
          }

          final questions = snapshot.data!;
          final currentQuestion = questions[_currentIndex];
          final progress = (_currentIndex + 1) / questions.length;

          return SafeArea(
            child: isLandscape
                ? _buildLandscapeLayout(questions, currentQuestion, progress)
                : _buildPortraitLayout(questions, currentQuestion, progress),
          );
        },
      ),
    );
  }

  // ── Portrait: vertical column with scrollable options ───────────────────
  Widget _buildPortraitLayout(
    List<QuizQuestion> questions,
    QuizQuestion currentQuestion,
    double progress,
  ) {
    return Column(
      children: [
        _progressHeader(questions, progress),
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
                    _questionCard(currentQuestion),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView(children: _buildOptions(currentQuestion)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        _nextButton(questions, currentQuestion),
      ],
    );
  }

  // ── Landscape: question on left, options + button on right ──────────────
  Widget _buildLandscapeLayout(
    List<QuizQuestion> questions,
    QuizQuestion currentQuestion,
    double progress,
  ) {
    return Column(
      children: [
        _progressHeader(questions, progress, compact: true),
        Expanded(
          child: FadeTransition(
            opacity: _questionFade,
            child: SlideTransition(
              position: _questionSlide,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Left: question card
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                      child: _questionCard(currentQuestion),
                    ),
                  ),
                  // Right: options + button
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                            children: _buildOptions(
                              currentQuestion,
                              compact: true,
                            ),
                          ),
                        ),
                        _nextButton(questions, currentQuestion, compact: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _progressHeader(
    List<QuizQuestion> questions,
    double progress, {
    bool compact = false,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, compact ? 4 : 8, 24, 0),
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
                  color: Colors.black54,
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
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF6D391E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questionCard(QuizQuestion currentQuestion) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      child: Text(
        currentQuestion.text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _nextButton(
    List<QuizQuestion> questions,
    QuizQuestion currentQuestion, {
    bool compact = false,
  }) {
    final isLast = _currentIndex == questions.length - 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, compact ? 4 : 8, 24, compact ? 12 : 30),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (_selectedOptionHash != null)
              BoxShadow(
                color: const Color(0xFF6D391E).withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _selectedOptionHash != null
                ? const Color(0xFF6D391E)
                : Colors.grey.shade400,
            minimumSize: Size(double.infinity, compact ? 46 : 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
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
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  isLast ? "Finish Quiz" : "Next Question",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
        ),
      ),
    );
  }

  List<Widget> _buildOptions(QuizQuestion question, {bool compact = false}) {
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
          margin: EdgeInsets.only(bottom: compact ? 8 : 12),
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: compact ? 10 : 14,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF6D391E).withOpacity(0.08)
                : Colors.white,
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6D391E)
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
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
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: TextStyle(
                    fontSize: compact ? 14 : 15,
                    color: Colors.black87,
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
