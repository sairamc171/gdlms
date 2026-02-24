import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_html/flutter_html.dart';
import 'services/api_service.dart';
import 'quiz_intro_page.dart';
import 'quiz_result_page.dart';
import 'dart:async';

class LessonPlayerPage extends StatefulWidget {
  final int lessonId;
  final List<int> allLessonIds;

  const LessonPlayerPage({
    super.key,
    required this.lessonId,
    required this.allLessonIds,
  });

  @override
  State<LessonPlayerPage> createState() => _LessonPlayerPageState();
}

class _LessonPlayerPageState extends State<LessonPlayerPage> {
  Map<String, dynamic>? _lessonData;
  bool _isLoading = true;
  bool _isMarkingComplete = false;
  bool _isLessonCompleted = false;
  double _videoProgress = 0.0;
  InAppWebViewController? _webViewController;
  bool _isButtonEnabled = false;

  // Theme Colors
  final Color primaryBrown = const Color(0xFF6D391E);
  final Color backgroundGrey = const Color(0xFFF7F7F7);

  @override
  void initState() {
    super.initState();
    _fetchStatusFromWebsite();
  }

  @override
  void dispose() {
    _webViewController?.removeJavaScriptHandler(handlerName: 'VideoProgress');
    super.dispose();
  }

  bool _toBool(dynamic value) {
    if (value == null || value == false || value == 0 || value == "0")
      return false;
    if (value == true ||
        value == "1" ||
        value == 1 ||
        value.toString().toLowerCase() == "true")
      return true;
    return false;
  }

  bool _hasVideo() {
    final videoId = _lessonData?['video_id']?.toString() ?? '';
    return videoId.isNotEmpty;
  }

  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    return int.tryParse(value.toString()) ?? 0;
  }

  Future<Map<String, dynamic>?> _checkQuizCompletion(int quizId) async {
    try {
      final attempts = await apiService.getQuizAttempts(quizId);
      if (attempts.isNotEmpty) return attempts.first;
    } catch (e) {
      debugPrint('Error checking quiz completion: $e');
    }
    return null;
  }

  Future<void> _fetchStatusFromWebsite() async {
    final data = await apiService.getLessonDetails(widget.lessonId);
    if (data != null && mounted) {
      final isCompleted = _toBool(data['is_completed']);
      final hasNoVideo = (data['video_id']?.toString() ?? '').isEmpty;

      setState(() {
        _lessonData = data;
        _isLessonCompleted = isCompleted;
        if (hasNoVideo && !isCompleted) _isButtonEnabled = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _syncCompletionToWebsite() async {
    // Safety check: Don't run if already processing or already finished
    if (_isMarkingComplete || _isLessonCompleted) return;

    setState(() => _isMarkingComplete = true);
    final result = await apiService.syncLessonWithWebsite(widget.lessonId);

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      setState(() {
        _isLessonCompleted = true;
        _isMarkingComplete = false;
      });
      Future.delayed(
        const Duration(seconds: 1),
        () => _handleNavigation(result['next_lesson_id']),
      );
    } else {
      setState(() => _isMarkingComplete = false);
    }
  }

  void _handleNavigation(dynamic nextId) async {
    if (nextId == null || nextId == 0) {
      Navigator.pop(context, true);
      return;
    }
    final nextData = await apiService.getLessonDetails(
      int.parse(nextId.toString()),
    );
    if (!mounted || nextData == null) return;

    if (nextData['type'] == 'quiz') {
      final quizId = nextData['id'];
      if (_toBool(nextData['is_completed'])) {
        final attempt = await _checkQuizCompletion(quizId);
        if (attempt != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (c) => QuizResultPage(
                totalQuestions: _parseInt(attempt['total_questions']),
                correctAnswers: _parseInt(attempt['total_correct']),
              ),
            ),
          );
          return;
        }
      }
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) =>
              QuizIntroPage(quizId: quizId, quizTitle: nextData['title']),
        ),
      );
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => LessonPlayerPage(
            lessonId: nextData['id'],
            allLessonIds: widget.allLessonIds,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final videoId = _lessonData!['video_id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _lessonData!['title'] ?? "Lesson",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: backgroundGrey,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: videoId.isNotEmpty
                ? _buildPlayer(videoId)
                : const SizedBox(
                    height: 200,
                    child: Center(
                      child: Icon(
                        Icons.article_outlined,
                        size: 60,
                        color: Colors.grey,
                      ),
                    ),
                  ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Html(
                data: _lessonData!['content'] ?? "",
                style: {
                  "body": Style(
                    fontSize: FontSize(16.0),
                    lineHeight: LineHeight(1.5),
                    color: Colors.black87,
                  ),
                  "h2": Style(
                    fontWeight: FontWeight.bold,
                    margin: Margins.only(top: 10),
                  ),
                },
              ),
            ),
          ),

          _buildSyncButton(),
        ],
      ),
    );
  }

  Widget _buildPlayer(String videoId) {
    const String authorizedDomain = 'https://lms.gdcollege.ca/';
    final html =
        '''
      <!DOCTYPE html><html><head><meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style> body { background: #F7F7F7; margin: 0; display: flex; justify-content: center; align-items: center; height: 100vh; }
      #player-container { width: 90%; aspect-ratio: 16/9; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
      iframe { width: 100%; height: 100%; border: none; }</style></head>
      <body><div id="player-container"><iframe id="gumlet-player" src="https://play.gumlet.io/embed/$videoId" allowfullscreen></iframe></div>
      <script src="https://cdn.jsdelivr.net/npm/@gumlet/player.js@latest/dist/player.min.js"></script>
      <script>
        function sendToApp(progress) {
          if (window.flutter_inappwebview) { window.flutter_inappwebview.callHandler('VideoProgress', { progress: progress }); }
        }
        window.onload = function() {
          const player = new playerjs.Player(document.getElementById('gumlet-player'));
          player.on('ready', () => {
            player.on('timeupdate', (data) => {
              if (data.duration > 0) { sendToApp(data.seconds / data.duration); }
            });
          });
        }
      </script></body></html>
    ''';

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: InAppWebView(
        initialData: InAppWebViewInitialData(
          data: html,
          baseUrl: WebUri(authorizedDomain),
        ),
        initialSettings: InAppWebViewSettings(
          javaScriptEnabled: true,
          allowsInlineMediaPlayback: true,
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
          controller.addJavaScriptHandler(
            handlerName: 'VideoProgress',
            callback: (args) {
              if (_isLessonCompleted || args.isEmpty) return;

              final progress = (args[0]['progress'] as num).toDouble();

              if (mounted) {
                setState(() {
                  _videoProgress = progress;

                  // LOGIC CHANGE: AUTO-CLICK / AUTO-SYNC
                  if (progress >= 0.90 && !_isButtonEnabled) {
                    _isButtonEnabled = true;
                    // Automatically trigger the completion sync
                    _syncCompletionToWebsite();
                  }
                });
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildSyncButton() {
    bool isLocked = _hasVideo() && !_isButtonEnabled && !_isLessonCompleted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isLocked && !_isLessonCompleted)
              BoxShadow(
                color: primaryBrown.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: (isLocked || _isMarkingComplete || _isLessonCompleted)
              ? null
              : _syncCompletionToWebsite,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isLessonCompleted
                ? Colors.grey.shade400
                : primaryBrown,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _isLessonCompleted
                ? Colors.grey.shade200
                : Colors.grey.shade400,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isMarkingComplete
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isLessonCompleted
                          ? Icons.check_circle
                          : (isLocked
                                ? Icons.lock
                                : Icons.check_circle_outline),
                      size: 20,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isLessonCompleted ? "Completed" : "Mark as Completed",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
