import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'app_theme.dart';
import 'lesson_player_page.dart';
import 'quiz_intro_page.dart';
import 'services/api_service.dart';
import 'course_details_page.dart';

class QuizResultPage extends StatefulWidget {
  final int totalQuestions;
  final int correctAnswers;
  final List<int> allLessonIds;
  final int currentQuizId;

  const QuizResultPage({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    this.allLessonIds = const [],
    this.currentQuizId = 0,
  });

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scoreAnim, _fadeAnim;
  late Animation<Offset> _slideAnim;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scoreAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
    );
    _fadeAnim = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Adjacent item IDs ──────────────────────────────────────────────────────

  int? get _previousId {
    if (widget.allLessonIds.isEmpty || widget.currentQuizId == 0) return null;
    final idx = widget.allLessonIds.indexOf(widget.currentQuizId);
    if (idx <= 0) return null;
    return widget.allLessonIds[idx - 1];
  }

  int? get _nextId {
    if (widget.allLessonIds.isEmpty || widget.currentQuizId == 0) return null;
    final idx = widget.allLessonIds.indexOf(widget.currentQuizId);
    if (idx < 0 || idx >= widget.allLessonIds.length - 1) return null;
    return widget.allLessonIds[idx + 1];
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  /// Navigate to a lesson or quiz by id.
  /// Uses cache first, falls back to API. Shows error on failure.
  Future<void> _navigateToId(int targetId) async {
    if (_isNavigating || !mounted) return;
    setState(() => _isNavigating = true);

    try {
      Map<String, dynamic>? data = LessonCache.get(targetId);
      data ??= await apiService.getLessonDetails(targetId);

      if (!mounted) return;

      if (data == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not load content. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      LessonCache.put(targetId, data);
      final String type = data['type']?.toString() ?? '';
      final bool isQuiz = type == 'tutor_quiz' || type == 'quiz';

      if (isQuiz) {
        // Check for existing attempts to decide: QuizIntroPage
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) => QuizIntroPage(
              quizId: targetId,
              quizTitle: data!['title']?.toString() ?? 'Quiz',
              allLessonIds: widget.allLessonIds,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (c) => LessonPlayerPage(
              lessonId: targetId,
              allLessonIds: widget.allLessonIds,
              initialData: data,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isNavigating = false);
    }
  }

  /// Back to Course Details page
  void _backToCourse() {
    Navigator.popUntil(
      context,
      (route) =>
          route.settings.name == CourseDetailsPage.routeName || route.isFirst,
    );
  }

  /// Retry: go back to QuizIntroPage for this quiz
  void _retryQuiz() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (c) => QuizIntroPage(
          quizId: widget.currentQuizId,
          quizTitle: 'Quiz',
          allLessonIds: widget.allLessonIds,
        ),
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final double percent = widget.totalQuestions > 0
        ? widget.correctAnswers / widget.totalQuestions
        : 0;
    final bool isPassed = percent >= 0.7;
    final int percentInt = (percent * 100).toInt();
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(title: 'Results'),
      body: SafeArea(
        child: isLandscape
            ? _buildLandscapeBody(percent, isPassed, percentInt)
            : _buildPortraitBody(percent, isPassed, percentInt),
      ),
    );
  }

  Widget _buildPortraitBody(double percent, bool isPassed, int percentInt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          _scoreRing(percent, isPassed, percentInt, size: 180),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Column(
                children: [
                  _statsRow(isPassed),
                  const SizedBox(height: 32),
                  _buttons(isPassed),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandscapeBody(double percent, bool isPassed, int percentInt) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Center(
              child: _scoreRing(percent, isPassed, percentInt, size: 140),
            ),
          ),
        ),
        Expanded(
          flex: 6,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(0, 16, 28, 16),
              child: SizedBox(
                width: constraints.maxWidth,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _statsRow(isPassed),
                        const SizedBox(height: 16),
                        _buttons(isPassed, buttonHeight: 44),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _scoreRing(
    double percent,
    bool isPassed,
    int percentInt, {
    required double size,
  }) {
    final color = isPassed ? AppTheme.completed : Colors.red[700]!;
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (context, _) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ScoreRingPainter(
            progress: _scoreAnim.value * percent,
            isPassed: isPassed,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(_scoreAnim.value * percentInt).toInt()}%',
                  style: AppTheme.headingLarge.copyWith(
                    fontSize: size * 0.22,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  isPassed ? 'Passed' : 'Failed',
                  style: AppTheme.labelSmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statsRow(bool isPassed) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Correct',
            value: '${widget.correctAnswers}',
            color: AppTheme.completed,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Wrong',
            value: '${widget.totalQuestions - widget.correctAnswers}',
            color: Colors.red[700]!,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            label: 'Total',
            value: '${widget.totalQuestions}',
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buttons(bool isPassed, {double buttonHeight = 52}) {
    final hasPrev = _previousId != null && !_isNavigating;
    final hasNext = _nextId != null && !_isNavigating;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Retry button (only when failed)
        if (!isPassed) ...[
          ElevatedButton.icon(
            icon: const Icon(
              Icons.replay_rounded,
              color: AppTheme.surface,
              size: 20,
            ),
            label: Text(
              'Retry Quiz',
              style: AppTheme.bodyMedium.copyWith(
                color: AppTheme.surface,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: Size(double.infinity, buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            onPressed: _retryQuiz,
          ),
          const SizedBox(height: 10),
        ],

        // Back to Course
        OutlinedButton.icon(
          icon: const Icon(
            Icons.home_outlined,
            color: AppTheme.primary,
            size: 20,
          ),
          label: Text(
            'Back to Course',
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: const BorderSide(color: AppTheme.primary, width: 1.5),
          ),
          onPressed: _backToCourse,
        ),

        const SizedBox(height: 10),

        // Previous / Next
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasPrev ? () => _navigateToId(_previousId!) : null,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 13),
                label: Text(
                  'Previous',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasPrev ? AppTheme.primary : Colors.grey[350],
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  disabledForegroundColor: Colors.grey[350],
                  side: BorderSide(
                    color: hasPrev
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : Colors.grey[200]!,
                  ),
                  minimumSize: Size(0, buttonHeight < 52 ? 40 : 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasNext ? () => _navigateToId(_nextId!) : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
                iconAlignment: IconAlignment.end,
                label: Text(
                  'Next',
                  style: AppTheme.labelMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: hasNext ? AppTheme.primary : Colors.grey[350],
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  disabledForegroundColor: Colors.grey[350],
                  side: BorderSide(
                    color: hasNext
                        ? AppTheme.primary.withValues(alpha: 0.5)
                        : Colors.grey[200]!,
                  ),
                  minimumSize: Size(0, buttonHeight < 52 ? 40 : 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Supporting widgets ─────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label, value;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color.withValues(alpha: 0.18)),
    ),
    child: Column(
      children: [
        Text(
          value,
          style: AppTheme.statCount.copyWith(fontSize: 22, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTheme.labelSmall),
      ],
    ),
  );
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final bool isPassed;

  _ScoreRingPainter({required this.progress, required this.isPassed});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 20) / 2;
    const strokeWidth = 12.0;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.grey.shade200
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      Paint()
        ..color = isPassed ? AppTheme.completed : Colors.red[700]!
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}
