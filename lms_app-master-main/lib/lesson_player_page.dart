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
  final Color primaryBrown = const Color(0xFF6D391E);

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
    if (value is int && value > 1) return true;
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null && parsed > 1) return true;
    }
    return false;
  }

  bool _hasVideo() {
    final videoId = _lessonData?['video_id']?.toString() ?? '';
    return videoId.isNotEmpty;
  }

  // Helper to safely parse integers for quiz results
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  // Helper to check if quiz is completed and get result data
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

        // SEQUENTIAL LOGIC: If no video is present, enable button immediately
        if (hasNoVideo && !isCompleted) {
          _isButtonEnabled = true;
        }

        _isLoading = false;
      });
    }
  }

  Future<void> _syncCompletionToWebsite() async {
    if (_isMarkingComplete || _isLessonCompleted) return;
    setState(() => _isMarkingComplete = true);

    final result = await apiService.syncLessonWithWebsite(widget.lessonId);

    if (!mounted) return;

    if (result != null && result['success'] == true) {
      setState(() {
        _isLessonCompleted = true;
        _isMarkingComplete = false;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        _handleNavigation(result['next_lesson_id']);
      });
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
      final quizTitle = nextData['title'];

      // --- SMART ROUTING LOGIC ---
      bool alreadyDone = _toBool(nextData['is_completed']);

      if (alreadyDone) {
        debugPrint('✓ Quiz already done. Routing to Results Page.');
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

      // Default to Intro Page if not done or data fetch failed
      debugPrint('○ Routing to Quiz Intro.');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => QuizIntroPage(quizId: quizId, quizTitle: quizTitle),
        ),
      );
    } else {
      // Standard Lesson Navigation
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final videoId = _lessonData!['video_id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        title: Text(
          _lessonData!['title'] ?? "Lesson",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        children: [
          if (videoId.isNotEmpty)
            _buildPlayer(videoId)
          else
            const SizedBox(
              height: 200,
              child: Center(
                child: Icon(Icons.article, size: 50, color: Colors.grey),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Html(data: _lessonData!['content'] ?? ""),
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
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { background: #000; overflow: hidden; }
    #player-container { position: relative; width: 100%; height: 100vh; }
    iframe { position: absolute; top: 0; left: 0; width: 100%; height: 100%; border: none; }
  </style>
</head>
<body>
  <div id="player-container">
    <iframe id="gumlet-player" 
            src="https://play.gumlet.io/embed/$videoId" 
            allow="accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture" 
            allowfullscreen>
    </iframe>
  </div>
  <script src="https://cdn.jsdelivr.net/npm/@gumlet/player.js@latest/dist/player.min.js"></script>
  <script>
    let lastProgress = 0;
    function sendToApp(progress) {
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        window.flutter_inappwebview.callHandler('VideoProgress', { progress: progress });
      }
    }
    function initPlayer() {
      const iframe = document.getElementById('gumlet-player');
      if (!iframe || typeof playerjs === 'undefined') { setTimeout(initPlayer, 500); return; }
      try {
        const player = new playerjs.Player(iframe);
        player.on('ready', () => {
          player.on('timeupdate', (data) => {
            if (data && data.duration > 0) {
              const progress = data.seconds / data.duration;
              if (Math.abs(progress - lastProgress) >= 0.01) {
                lastProgress = progress;
                sendToApp(progress);
              }
            }
          });
        });
      } catch(e) {}
    }
    window.onload = initPlayer;
  </script>
</body>
</html>
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
          mediaPlaybackRequiresUserGesture: false,
          domStorageEnabled: true,
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
          controller.addJavaScriptHandler(
            handlerName: 'VideoProgress',
            callback: (args) {
              if (_isLessonCompleted) return;

              if (args.isNotEmpty && args[0] is Map) {
                final data = args[0] as Map;
                final progress = (data['progress'] as num?)?.toDouble() ?? 0.0;
                if (mounted) {
                  setState(() {
                    _videoProgress = progress;
                    // --- SEQUENTIAL LOGIC: Unlock at 90% ---
                    if (progress >= 0.90 && !_isButtonEnabled) {
                      _isButtonEnabled = true;
                    }
                  });
                }
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildSyncButton() {
    if (_isLessonCompleted) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color.fromARGB(
              255,
              148,
              148,
              148,
            ).withOpacity(0.7),
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.check_circle, size: 18),
              ),
              Text(
                "Completed",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    bool hasVideo = _hasVideo();
    bool isLocked = hasVideo && !_isButtonEnabled;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: ElevatedButton(
        onPressed: (isLocked || _isMarkingComplete)
            ? null
            : _syncCompletionToWebsite,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          disabledBackgroundColor: isLocked
              ? Colors.grey[400]
              : primaryBrown.withOpacity(0.7),
          minimumSize: const Size(double.infinity, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: isLocked ? 0 : 2,
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
                  if (isLocked)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Icon(Icons.lock, size: 18),
                    ),
                  Text(
                    isLocked ? "Watch Video to Unlock" : "Mark as Complete",
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
