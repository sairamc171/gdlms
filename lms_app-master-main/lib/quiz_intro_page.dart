import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'quiz_taking_page.dart';
import 'quiz_result_page.dart' as results;
import 'course_details_page.dart'; // for courseRouteObserver

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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
    if (!mounted) return;
    _animController.forward(from: 0);
  }

  void _showResults() {
    final route = MaterialPageRoute(
      builder: (c) => results.QuizResultPage(
        totalQuestions: _parseInt(_latestAttempt!['total_questions']),
        correctAnswers: _parseInt(_latestAttempt!['total_correct']),
        allLessonIds: widget.allLessonIds,
        currentQuizId: widget.quizId,
        onBackToLesson: () {
          // Pop result page + intro page → lands on lesson player
          int count = 0;
          Navigator.of(context).popUntil((_) => count++ >= 2);
        },
      ),
    );
    Navigator.push(context, route).then((res) {
      if (res == 'retake') {
        _startQuiz();
      } else {
        _checkAttempts();
      }
    });
  }

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
    if (mounted) _checkAttempts();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator()),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          widget.quizTitle,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          _heroIcon(),
          const SizedBox(height: 32),
          _titleText(),
          const SizedBox(height: 12),
          if (_hasPreviousAttempt && scorePercent != null) ...[
            _scoreChip(scorePercent),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 40),
          _buttons(),
          const SizedBox(height: 16),
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
                  color: const Color(0xFF6D391E).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Center(
                  child: Icon(
                    _isPassed
                        ? Icons.workspace_premium_rounded
                        : (_hasPreviousAttempt
                              ? Icons.refresh_rounded
                              : Icons.quiz_rounded),
                    size: 64,
                    color: const Color(0xFF6D391E),
                  ),
                ),
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
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroIcon() {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: const Color(0xFF6D391E).withOpacity(0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Center(
        child: Icon(
          _isPassed
              ? Icons.workspace_premium_rounded
              : (_hasPreviousAttempt
                    ? Icons.refresh_rounded
                    : Icons.quiz_rounded),
          size: 64,
          color: const Color(0xFF6D391E),
        ),
      ),
    );
  }

  Widget _titleText({double fontSize = 24}) {
    return Text(
      widget.quizTitle,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
        height: 1.3,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _scoreChip(double scorePercent) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _isPassed
              ? const Color(0xFF2E7D32).withOpacity(0.1)
              : const Color(0xFFC62828).withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: _isPassed
                ? const Color(0xFF2E7D32).withOpacity(0.4)
                : const Color(0xFFC62828).withOpacity(0.4),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isPassed ? Icons.check_circle_outline : Icons.cancel_outlined,
              size: 16,
              color: _isPassed
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
            ),
            const SizedBox(width: 6),
            Text(
              "Last score: ${scorePercent.toInt()}%",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _isPassed
                    ? const Color(0xFF2E7D32)
                    : const Color(0xFFC62828),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buttons({double buttonHeight = 56}) {
    if (_isPassed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OutlineButton(
            label: "View Results",
            icon: Icons.bar_chart_rounded,
            height: buttonHeight,
            onPressed: _showResults,
          ),
          const SizedBox(height: 12),
          _PrimaryButton(
            label: "Retake Quiz",
            icon: Icons.replay_rounded,
            height: buttonHeight,
            onPressed: _startQuiz,
          ),
        ],
      );
    }
    return _PrimaryButton(
      label: _hasPreviousAttempt ? "Try Again" : "Start Quiz",
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

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: Icon(icon, color: Colors.white, size: 20),
      label: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6D391E),
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      onPressed: onPressed,
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final double height;
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, color: const Color(0xFF6D391E), size: 20),
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF6D391E),
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: Size(double.infinity, height),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: Color(0xFF6D391E), width: 1.5),
      ),
      onPressed: onPressed,
    );
  }
}
