import 'package:flutter/material.dart';
import 'app_theme.dart';
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
      backgroundColor: AppTheme.surface,
      appBar: AppTheme.buildAppBar(title: "Quiz"),
      body: FutureBuilder<List<QuizQuestion>>(
        future: _loadQuizFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                "Could not load questions.",
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
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
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _questionCard(currentQuestion),
                    const SizedBox(height: 16),
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
                  Expanded(
                    flex: 4,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                      child: _questionCard(currentQuestion),
                    ),
                  ),
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
      padding: EdgeInsets.fromLTRB(20, compact ? 4 : 10, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Question ${_currentIndex + 1} of ${questions.length}",
                style: AppTheme.overline.copyWith(
                  letterSpacing: 0.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              Text(
                "${(progress * 100).toInt()}%",
                style: AppTheme.labelSmall.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
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
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Text(
        currentQuestion.text,
        style: AppTheme.bodyMedium.copyWith(
          fontSize: 16,
          fontWeight: FontWeight.w600,
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
    final enabled = _selectedOptionHash != null && !_isSubmitting;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, compact ? 4 : 8, 20, compact ? 12 : 28),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: SizedBox(
          width: double.infinity,
          height: compact ? 44 : 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled ? AppTheme.primary : Colors.grey[300],
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
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    isLast ? "Finish Quiz" : "Next Question",
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.surface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildOptions(QuizQuestion question, {bool compact = false}) {
    final labels = ['A', 'B', 'C', 'D', 'E', 'F'];
    return question.options.asMap().entries.map((entry) {
      final index = entry.key;
      final option = entry.value;
      final isSelected = _selectedOptionHash == option.text.hashCode;
      final label = index < labels.length ? labels[index] : '${index + 1}';

      return GestureDetector(
        onTap: () => setState(() => _selectedOptionHash = option.text.hashCode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(bottom: compact ? 8 : 10),
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 10 : 13,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.07)
                : AppTheme.surface,
            border: Border.all(
              color: isSelected ? AppTheme.primary : Colors.grey[200]!,
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.background,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: AppTheme.labelSmall.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? AppTheme.surface
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.text,
                  style: AppTheme.bodySmall.copyWith(
                    fontSize: compact ? 13 : 14,
                    color: AppTheme.textPrimary,
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
