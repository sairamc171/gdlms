import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'quiz_taking_page.dart';
import 'quiz_result_page.dart' as results;

class QuizIntroPage extends StatefulWidget {
  final int quizId;
  final String quizTitle;
  const QuizIntroPage({
    super.key,
    required this.quizId,
    required this.quizTitle,
  });

  @override
  State<QuizIntroPage> createState() => _QuizIntroPageState();
}

class _QuizIntroPageState extends State<QuizIntroPage>
    with SingleTickerProviderStateMixin {
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
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAttempts() async {
    setState(() => _isLoading = true);
    try {
      final attempts = await apiService.getQuizAttempts(widget.quizId);
      final completed = attempts.where((a) {
        final status = a['attempt_status']?.toString().toLowerCase() ?? '';
        return ['finished', 'passed', 'failed'].contains(status) &&
            _parseDouble(a['total_marks']) > 0;
      }).toList();

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
      setState(() => _isLoading = false);
    }
    _animController.forward(from: 0);
  }

  void _showResults() {
    final route = MaterialPageRoute(
      builder: (c) => results.QuizResultPage(
        totalQuestions: _parseInt(_latestAttempt!['total_questions']),
        correctAnswers: _parseInt(_latestAttempt!['total_correct']),
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
    final dynamic result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (c) => QuizTakingPage(quizId: widget.quizId)),
    );
    if (mounted) _checkAttempts();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F3E7),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6D391E),
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    final double? scorePercent = _hasPreviousAttempt && _latestAttempt != null
        ? (_parseDouble(_latestAttempt!['earned_marks']) /
                  _parseDouble(_latestAttempt!['total_marks'])) *
              100
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF9F3E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F3E7),
        elevation: 0,
        foregroundColor: const Color(0xFF2C1A0E),
        title: Text(
          widget.quizTitle,
          style: const TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C1A0E),
          ),
        ),
        centerTitle: true,
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Hero icon area
                  Container(
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
                  ),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    widget.quizTitle,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2C1A0E),
                      height: 1.3,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Previous score chip (only if attempted)
                  if (_hasPreviousAttempt && scorePercent != null) ...[
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                              _isPassed
                                  ? Icons.check_circle_outline
                                  : Icons.cancel_outlined,
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
                    ),
                    const SizedBox(height: 8),
                  ],

                  const Spacer(),

                  // CTA Buttons
                  if (_isPassed) ...[
                    _OutlineButton(
                      label: "View Results",
                      icon: Icons.bar_chart_rounded,
                      onPressed: _showResults,
                    ),
                    const SizedBox(height: 12),
                    _PrimaryButton(
                      label: "Retake Quiz",
                      icon: Icons.replay_rounded,
                      onPressed: _startQuiz,
                    ),
                  ] else ...[
                    _PrimaryButton(
                      label: _hasPreviousAttempt ? "Try Again" : "Start Quiz",
                      icon: _hasPreviousAttempt
                          ? Icons.replay_rounded
                          : Icons.play_arrow_rounded,
                      onPressed: _startQuiz,
                    ),
                  ],

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _parseDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
  int _parseInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
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
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF6D391E),
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onPressed,
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
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: Color(0xFF6D391E), width: 1.5),
      ),
      onPressed: onPressed,
    );
  }
}
