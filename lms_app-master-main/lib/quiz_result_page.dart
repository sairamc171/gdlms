import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'lesson_player_page.dart';
import 'quiz_intro_page.dart';
import 'services/api_service.dart';

class QuizResultPage extends StatefulWidget {
  final int totalQuestions;
  final int correctAnswers;
  final List<int> allLessonIds;
  final int currentQuizId;
  final VoidCallback? onBackToLesson;

  const QuizResultPage({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
    this.allLessonIds = const [],
    this.currentQuizId = 0,
    this.onBackToLesson,
  });

  @override
  State<QuizResultPage> createState() => _QuizResultPageState();
}

class _QuizResultPageState extends State<QuizResultPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scoreAnim;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

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

  // ── Derive prev/next from allLessonIds ──────────────────────────────────
  int? get _previousId {
    if (widget.allLessonIds.isEmpty || widget.currentQuizId == 0) return null;
    final idx = widget.allLessonIds.indexOf(widget.currentQuizId);
    if (idx > 0) return widget.allLessonIds[idx - 1];
    return null;
  }

  int? get _nextId {
    if (widget.allLessonIds.isEmpty || widget.currentQuizId == 0) return null;
    final idx = widget.allLessonIds.indexOf(widget.currentQuizId);
    if (idx >= 0 && idx < widget.allLessonIds.length - 1) {
      return widget.allLessonIds[idx + 1];
    }
    return null;
  }

  Future<void> _navigateTo(int id) async {
    if (!mounted) return;
    final data = await apiService.getLessonDetails(id);
    if (!mounted || data == null) return;

    if (data['type'] == 'quiz') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => QuizIntroPage(
            quizId: data['id'],
            quizTitle: data['title'],
            allLessonIds: widget.allLessonIds,
          ),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => LessonPlayerPage(
            lessonId: data['id'],
            allLessonIds: widget.allLessonIds,
          ),
        ),
      );
    }
  }

  void _goToLessonPlayer() {
    if (widget.onBackToLesson != null) {
      widget.onBackToLesson!();
    } else {
      Navigator.pop(context);
    }
  }

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: true,
        title: const Text(
          "Results",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: isLandscape
            ? _buildLandscapeBody(percent, isPassed, percentInt)
            : _buildPortraitBody(percent, isPassed, percentInt),
      ),
    );
  }

  // ── Portrait ─────────────────────────────────────────────────────────────
  Widget _buildPortraitBody(double percent, bool isPassed, int percentInt) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        children: [
          const SizedBox(height: 16),
          _scoreRing(percent, isPassed, percentInt, size: 180),
          const SizedBox(height: 32),
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _statsRow(isPassed),
            ),
          ),
          const SizedBox(height: 40),
          FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: _buttons(isPassed),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Landscape: ring on left, stats + buttons on right ────────────────────
  Widget _buildLandscapeBody(double percent, bool isPassed, int percentInt) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Left: score ring — centred vertically
        Expanded(
          flex: 4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Center(
              child: _scoreRing(percent, isPassed, percentInt, size: 140),
            ),
          ),
        ),
        // Right: stats + buttons — independently scrollable
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
    return AnimatedBuilder(
      animation: _scoreAnim,
      builder: (context, _) {
        return SizedBox(
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
                    "${(_scoreAnim.value * percentInt).toInt()}%",
                    style: TextStyle(
                      fontSize: size * 0.22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    isPassed ? "Passed" : "Failed",
                    style: TextStyle(
                      fontSize: size * 0.08,
                      fontWeight: FontWeight.w600,
                      color: isPassed
                          ? const Color(0xFF2E7D32)
                          : const Color(0xFFC62828),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _statsRow(bool isPassed) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _StatCard(
            label: "Correct",
            value: "${widget.correctAnswers}",
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: "Wrong",
            value: "${widget.totalQuestions - widget.correctAnswers}",
            icon: Icons.cancel_outlined,
            color: const Color(0xFFC62828),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: "Total",
            value: "${widget.totalQuestions}",
            icon: Icons.list_alt_rounded,
            color: const Color(0xFF6D391E),
          ),
        ),
      ],
    );
  }

  Widget _buttons(bool isPassed, {double buttonHeight = 56}) {
    final hasPrev = _previousId != null;
    final hasNext = _nextId != null;
    final primaryBrown = const Color(0xFF6D391E);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Retry (only if failed) ──────────────────────────────────────
        if (!isPassed) ...[
          ElevatedButton.icon(
            icon: const Icon(
              Icons.replay_rounded,
              color: Colors.white,
              size: 20,
            ),
            label: Text(
              "Retry Quiz",
              style: TextStyle(
                color: Colors.white,
                fontSize: buttonHeight < 56 ? 14 : 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBrown,
              minimumSize: Size(double.infinity, buttonHeight),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(context, 'retake'),
          ),
          const SizedBox(height: 12),
        ],

        // ── Back to Lesson ───────────────────────────────────────────────
        OutlinedButton.icon(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF6D391E),
            size: 20,
          ),
          label: Text(
            "Back to Lesson",
            style: TextStyle(
              color: primaryBrown,
              fontSize: buttonHeight < 56 ? 14 : 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: Size(double.infinity, buttonHeight),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            side: BorderSide(color: primaryBrown, width: 1.5),
          ),
          onPressed: _goToLessonPlayer,
        ),

        const SizedBox(height: 12),

        // ── Prev / Next ──────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasPrev ? () => _navigateTo(_previousId!) : null,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
                label: Text(
                  'Previous',
                  style: TextStyle(fontSize: buttonHeight < 56 ? 13 : 15),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBrown,
                  disabledForegroundColor: Colors.grey.shade400,
                  side: BorderSide(
                    color: hasPrev ? primaryBrown : Colors.grey.shade300,
                  ),
                  minimumSize: Size(0, buttonHeight < 56 ? 42 : 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: hasNext ? () => _navigateTo(_nextId!) : null,
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                label: Text(
                  'Next',
                  style: TextStyle(fontSize: buttonHeight < 56 ? 13 : 15),
                ),
                iconAlignment: IconAlignment.end,
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryBrown,
                  disabledForegroundColor: Colors.grey.shade400,
                  side: BorderSide(
                    color: hasNext ? primaryBrown : Colors.grey.shade300,
                  ),
                  minimumSize: Size(0, buttonHeight < 56 ? 42 : 48),
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
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

    final bgPaint = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    final progressPaint = Paint()
      ..color = isPassed ? const Color(0xFF2E7D32) : const Color(0xFFC62828)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) => old.progress != progress;
}
