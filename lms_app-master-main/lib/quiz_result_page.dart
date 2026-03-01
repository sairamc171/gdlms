import 'package:flutter/material.dart';
import 'dart:math' as math;

class QuizResultPage extends StatefulWidget {
  final int totalQuestions;
  final int correctAnswers;

  const QuizResultPage({
    super.key,
    required this.totalQuestions,
    required this.correctAnswers,
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

  @override
  Widget build(BuildContext context) {
    final double percent = widget.totalQuestions > 0
        ? widget.correctAnswers / widget.totalQuestions
        : 0;
    final bool isPassed = percent >= 0.7;
    final int percentInt = (percent * 100).toInt();

    return Scaffold(
      backgroundColor: const Color(0xFFF9F3E7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F3E7),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          "Results",
          style: TextStyle(
            fontFamily: 'Georgia',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C1A0E),
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 16),

              // Score ring
              AnimatedBuilder(
                animation: _scoreAnim,
                builder: (context, _) {
                  return SizedBox(
                    width: 180,
                    height: 180,
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
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C1A0E),
                              ),
                            ),
                            Text(
                              isPassed ? "Passed" : "Failed",
                              style: TextStyle(
                                fontSize: 14,
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
              ),

              const SizedBox(height: 32),

              // Stats row
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Row(
                    children: [
                      _StatCard(
                        label: "Correct",
                        value: "${widget.correctAnswers}",
                        icon: Icons.check_circle_outline_rounded,
                        color: const Color(0xFF2E7D32),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: "Wrong",
                        value:
                            "${widget.totalQuestions - widget.correctAnswers}",
                        icon: Icons.cancel_outlined,
                        color: const Color(0xFFC62828),
                      ),
                      const SizedBox(width: 12),
                      _StatCard(
                        label: "Total",
                        value: "${widget.totalQuestions}",
                        icon: Icons.list_alt_rounded,
                        color: const Color(0xFF6D391E),
                      ),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Buttons
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isPassed) ...[
                        ElevatedButton.icon(
                          icon: const Icon(
                            Icons.replay_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          label: const Text(
                            "Retry Quiz",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6D391E),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () => Navigator.pop(context, 'retake'),
                        ),
                        const SizedBox(height: 12),
                      ],
                      OutlinedButton.icon(
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: Color(0xFF6D391E),
                          size: 20,
                        ),
                        label: const Text(
                          "Back",
                          style: TextStyle(
                            color: Color(0xFF6D391E),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(
                            color: Color(0xFF6D391E),
                            width: 1.5,
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontFamily: 'Georgia',
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
                color: Color(0xFF9E7B5A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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

    // Background ring
    final bgPaint = Paint()
      ..color = const Color(0xFFE8D8C4)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
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
