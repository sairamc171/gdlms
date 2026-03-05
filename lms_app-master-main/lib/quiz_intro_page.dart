import 'package:flutter/material.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'quiz_taking_page.dart';
import 'quiz_result_page.dart';
import 'course_details_page.dart';

class QuizIntroPage extends StatefulWidget {
  final int quizId;
  final String quizTitle;
  final List<int> allLessonIds;

  const QuizIntroPage({
    super.key,
    required this.quizId,
    required this.quizTitle,
    this.allLessonIds = const [],
  });

  @override
  State<QuizIntroPage> createState() => _QuizIntroPageState();
}

class _QuizIntroPageState extends State<QuizIntroPage>
    with SingleTickerProviderStateMixin, RouteAware {
  bool _isLoading = true;
  bool _hasPreviousAttempt = false;
  bool _isPassed = false;
  Map<String, dynamic>? _latestAttempt;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _checkAttempts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    courseRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    courseRouteObserver.unsubscribe(this);
    _animController.dispose();
    super.dispose();
  }

  // When returning from QuizTakingPage via back button, refresh attempt state
  @override
  void didPopNext() => _checkAttempts();

  Future<void> _checkAttempts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final attempts = await apiService.getQuizAttempts(widget.quizId);
      final completed = attempts.where((a) {
        final status = a['attempt_status']?.toString().toLowerCase() ?? '';
        return ['finished', 'passed', 'failed'].contains(status) &&
            _parseDouble(a['total_marks']) > 0;
      }).toList();

      if (!mounted) return;
      if (completed.isNotEmpty) {
        final latest = completed.first;
        _latestAttempt = latest;
        final pct =
            (_parseDouble(latest['earned_marks']) /
                _parseDouble(latest['total_marks'])) *
            100;
        setState(() {
          _hasPreviousAttempt = true;
          _isPassed = pct >= 70 || latest['attempt_status'] == 'passed';
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasPreviousAttempt = false;
          _isPassed = false;
          _latestAttempt = null;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
    if (mounted) _animController.forward(from: 0);
  }

  // Navigate to result page for the latest attempt
  void _showResults() {
    if (_latestAttempt == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => QuizResultPage(
          totalQuestions: _parseInt(_latestAttempt!['total_questions']),
          correctAnswers: _parseInt(_latestAttempt!['total_correct']),
          allLessonIds: widget.allLessonIds,
          currentQuizId: widget.quizId,
        ),
      ),
    );
  }

  // Start / retake quiz — push QuizTakingPage, refresh on return
  Future<void> _startQuiz() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (c) => QuizTakingPage(
          quizId: widget.quizId,
          allLessonIds: widget.allLessonIds,
        ),
      ),
    );
    // Refresh after returning (back button or quiz completion → back)
    if (mounted) _checkAttempts();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final double? scorePercent = _hasPreviousAttempt && _latestAttempt != null
        ? (_parseDouble(_latestAttempt!['earned_marks']) /
                  _parseDouble(_latestAttempt!['total_marks'])) *
              100
        : null;
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(title: widget.quizTitle),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: isLandscape
                ? _buildLandscapeBody(scorePercent)
                : _buildPortraitBody(scorePercent),
          ),
        ),
      ),
    );
  }

  Widget _buildPortraitBody(double? scorePercent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _heroIcon(),
          const SizedBox(height: 28),
          _titleText(),
          const SizedBox(height: 12),
          if (_hasPreviousAttempt && scorePercent != null) ...[
            _scoreChip(scorePercent),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 36),
          _buttons(),
        ],
      ),
    );
  }

  Widget _buildLandscapeBody(double? scorePercent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 4,
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(child: _heroIconWidget(size: 64)),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _titleText(fontSize: 20),
                const SizedBox(height: 10),
                if (_hasPreviousAttempt && scorePercent != null) ...[
                  _scoreChip(scorePercent),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 16),
                _buttons(buttonHeight: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroIconWidget({double size = 64}) {
    return Icon(
      _isPassed
          ? Icons.workspace_premium_rounded
          : (_hasPreviousAttempt ? Icons.refresh_rounded : Icons.quiz_rounded),
      size: size,
      color: AppTheme.primary,
    );
  }

  Widget _heroIcon() {
    return Container(
      height: 130,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(child: _heroIconWidget()),
    );
  }

  Widget _titleText({double fontSize = 22}) {
    return Text(
      widget.quizTitle,
      style: AppTheme.headingMedium.copyWith(fontSize: fontSize),
      textAlign: TextAlign.center,
    );
  }

  Widget _scoreChip(double scorePercent) {
    final color = _isPassed ? AppTheme.completed : Colors.red[700]!;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPassed ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 15,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              'Last score: ${scorePercent.toInt()}%',
              style: AppTheme.labelMedium.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttons({double buttonHeight = 52}) {
    if (_isPassed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OutlineBtn(
            label: 'View Results',
            icon: Icons.bar_chart_rounded,
            height: buttonHeight,
            onPressed: _showResults,
          ),
          const SizedBox(height: 12),
          _PrimaryBtn(
            label: 'Retake Quiz',
            icon: Icons.replay_rounded,
            height: buttonHeight,
            onPressed: _startQuiz,
          ),
        ],
      );
    }
    return _PrimaryBtn(
      label: _hasPreviousAttempt ? 'Try Again' : 'Start Quiz',
      icon: _hasPreviousAttempt
          ? Icons.replay_rounded
          : Icons.play_arrow_rounded,
      height: buttonHeight,
      onPressed: _startQuiz,
    );
  }

  double _parseDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
  int _parseInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
}

// ── Reusable button widgets ────────────────────────────────────────────────

class _PrimaryBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;

  const _PrimaryBtn({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    icon: Icon(icon, color: AppTheme.surface, size: 20),
    label: Text(
      label,
      style: AppTheme.bodyMedium.copyWith(
        color: AppTheme.surface,
        fontWeight: FontWeight.w600,
      ),
    ),
    style: ElevatedButton.styleFrom(
      backgroundColor: AppTheme.primary,
      minimumSize: Size(double.infinity, height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
    ),
    onPressed: onPressed,
  );
}

class _OutlineBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;

  const _OutlineBtn({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: Icon(icon, color: AppTheme.primary, size: 20),
    label: Text(
      label,
      style: AppTheme.bodyMedium.copyWith(
        color: AppTheme.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
    style: OutlinedButton.styleFrom(
      minimumSize: Size(double.infinity, height),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      side: const BorderSide(color: AppTheme.primary, width: 1.5),
    ),
    onPressed: onPressed,
  );
}
