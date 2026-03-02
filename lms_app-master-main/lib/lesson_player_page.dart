import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_html/flutter_html.dart';
import 'services/api_service.dart';
import 'quiz_intro_page.dart';
import 'quiz_result_page.dart';
import 'course_details_page.dart'; // for courseRouteObserver
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

class _LessonPlayerPageState extends State<LessonPlayerPage> with RouteAware {
  Map<String, dynamic>? _lessonData;
  bool _isLoading = true;
  bool _isMarkingComplete = false;
  bool _isLessonCompleted = false;
  InAppWebViewController? _webViewController;
  bool _isButtonEnabled = false;

  // ── Cached player to survive orientation rebuilds ──
  final GlobalKey _webViewKey = GlobalKey();
  Widget? _cachedPlayer;

  // Theme Colors
  final Color primaryBrown = const Color(0xFF6D391E);
  final Color backgroundGrey = const Color(0xFFF7F7F7);

  @override
  void initState() {
    super.initState();
    _fetchStatusFromWebsite();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    courseRouteObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    courseRouteObserver.unsubscribe(this);
    _webViewController?.removeJavaScriptHandler(handlerName: 'VideoProgress');
    _cachedPlayer = null;
    super.dispose();
  }

  bool _toBool(dynamic value) {
    if (value == null || value == false || value == 0 || value == "0") {
      return false;
    }
    if (value == true ||
        value == "1" ||
        value == 1 ||
        value.toString().toLowerCase() == "true") {
      return true;
    }
    final parsed = int.tryParse(value.toString());
    if (parsed != null && parsed > 1) return true;
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

    if (!mounted) return;

    if (data != null) {
      final isCompleted = _toBool(data['is_completed']);
      final hasNoVideo = (data['video_id']?.toString() ?? '').isEmpty;
      setState(() {
        _lessonData = data;
        _isLessonCompleted = isCompleted;
        if (hasNoVideo && !isCompleted) _isButtonEnabled = true;
        if (isCompleted) _isButtonEnabled = true;
        _isLoading = false;
      });
    } else {
      // API returned null — still show the page with a minimal fallback
      setState(() {
        _lessonData = {
          'id': widget.lessonId,
          'title': 'Lesson',
          'content': '',
          'video_id': '',
          'is_completed': false,
          'next_lesson_id': null,
        };
        _isButtonEnabled = true;
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
    } else {
      setState(() => _isMarkingComplete = false);
    }
  }

  void _handleNavigation(dynamic nextId) async {
    if (!mounted) return;

    if (nextId == null || nextId == 0) {
      Navigator.pop(context);
      return;
    }

    final nextData = await apiService.getLessonDetails(
      int.parse(nextId.toString()),
    );

    if (!mounted || nextData == null) return;

    final nextType = nextData['type']?.toString() ?? '';
    if (nextType == 'quiz' || nextType == 'tutor_quiz') {
      final quizId = nextData['id'];
      if (_toBool(nextData['is_completed'])) {
        final attempt = await _checkQuizCompletion(quizId);
        if (!mounted) return;
        if (attempt != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (c) => QuizResultPage(
                totalQuestions: _parseInt(attempt['total_questions']),
                correctAnswers: _parseInt(attempt['total_correct']),
                allLessonIds: widget.allLessonIds,
                currentQuizId: quizId,
              ),
            ),
          );
          return;
        }
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (c) => QuizIntroPage(
            quizId: quizId,
            quizTitle: nextData['title'],
            allLessonIds: widget.allLessonIds,
          ),
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

  // ─────────────────────────────────────────────
  // Derives previous lesson ID from allLessonIds
  // ─────────────────────────────────────────────
  int? get _previousLessonId {
    final idx = widget.allLessonIds.indexOf(widget.lessonId);
    if (idx > 0) return widget.allLessonIds[idx - 1];
    return null;
  }

  int? get _nextLessonId {
    final idx = widget.allLessonIds.indexOf(widget.lessonId);
    if (idx >= 0 && idx < widget.allLessonIds.length - 1) {
      return widget.allLessonIds[idx + 1];
    }
    final parsedFromApi = _parseInt(_lessonData?['next_lesson_id']);
    return parsedFromApi > 0 ? parsedFromApi : null;
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
        centerTitle: true,
        title: Text(
          _lessonData!['title'] ?? "Lesson",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = constraints.maxWidth > constraints.maxHeight;
          if (isLandscape) {
            return _buildLandscapeLayout(videoId);
          }
          return _buildPortraitLayout(videoId);
        },
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PORTRAIT
  // ─────────────────────────────────────────────
  Widget _buildPortraitLayout(String videoId) {
    return Column(
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
        _buildPrevNextButtons(),
        _buildSyncButton(),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // LANDSCAPE
  // ─────────────────────────────────────────────
  Widget _buildLandscapeLayout(String videoId) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: Container(
            color: backgroundGrey,
            padding: const EdgeInsets.all(12),
            child: videoId.isNotEmpty
                ? Center(child: _buildPlayer(videoId))
                : const Center(
                    child: Icon(
                      Icons.article_outlined,
                      size: 60,
                      color: Colors.grey,
                    ),
                  ),
          ),
        ),
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Html(
                    data: _lessonData!['content'] ?? "",
                    style: {
                      "body": Style(
                        fontSize: FontSize(14.0),
                        lineHeight: LineHeight(1.5),
                        color: Colors.black87,
                      ),
                      "h2": Style(
                        fontWeight: FontWeight.bold,
                        margin: Margins.only(top: 8),
                      ),
                    },
                  ),
                ),
              ),
              _buildPrevNextButtons(compact: true),
              _buildSyncButton(compact: true),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // PREV / NEXT BUTTONS
  // ─────────────────────────────────────────────
  Widget _buildPrevNextButtons({bool compact = false}) {
    final hasPrev = _previousLessonId != null;
    final hasNext = _nextLessonId != null && _isButtonEnabled;

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 4, 12, 4)
          : const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          // ── Previous ──
          Expanded(
            child: OutlinedButton.icon(
              onPressed: hasPrev
                  ? () => _handleNavigation(_previousLessonId)
                  : null,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              label: Text(
                'Previous',
                style: TextStyle(fontSize: compact ? 13 : 15),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBrown,
                disabledForegroundColor: Colors.grey.shade400,
                side: BorderSide(
                  color: hasPrev ? primaryBrown : Colors.grey.shade300,
                ),
                minimumSize: Size(0, compact ? 42 : 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // ── Next ──
          Expanded(
            child: OutlinedButton.icon(
              onPressed: hasNext
                  ? () async {
                      if (!_isLessonCompleted) {
                        await _syncCompletionToWebsite();
                      }
                      if (mounted) _handleNavigation(_nextLessonId);
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
              label: Text(
                'Next',
                style: TextStyle(fontSize: compact ? 13 : 15),
              ),
              iconAlignment: IconAlignment.end,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryBrown,
                disabledForegroundColor: Colors.grey.shade400,
                side: BorderSide(
                  color: hasNext ? primaryBrown : Colors.grey.shade300,
                ),
                minimumSize: Size(0, compact ? 42 : 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // PLAYER — built once, cached to survive rebuilds
  // ─────────────────────────────────────────────
  Widget _buildPlayer(String videoId) {
    if (_cachedPlayer != null) return _cachedPlayer!;

    const String authorizedDomain = 'https://lms.gdcollege.ca/';
    final html =
        '''
      <!DOCTYPE html><html><head>
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <style>
        body { background: #F7F7F7; margin: 0; display: flex; justify-content: center; align-items: center; height: 100vh; }
        #player-container { width: 90%; aspect-ratio: 16/9; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 15px rgba(0,0,0,0.1); }
        iframe { width: 100%; height: 100%; border: none; }
      </style></head>
      <body>
        <div id="player-container">
          <iframe id="gumlet-player" src="https://play.gumlet.io/embed/$videoId" allowfullscreen></iframe>
        </div>
        <script src="https://cdn.jsdelivr.net/npm/@gumlet/player.js@latest/dist/player.min.js"></script>
        <script>
          function sendToApp(progress) {
            if (window.flutter_inappwebview) {
              window.flutter_inappwebview.callHandler('VideoProgress', { progress: progress });
            }
          }
          window.onload = function() {
            const player = new playerjs.Player(document.getElementById('gumlet-player'));
            player.on('ready', () => {
              player.on('timeupdate', (data) => {
                if (data.duration > 0) { sendToApp(data.seconds / data.duration); }
              });
            });
          }
        </script>
      </body></html>
    ''';

    _cachedPlayer = KeyedSubtree(
      key: _webViewKey,
      child: AspectRatio(
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
            supportZoom: false,
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
                    if (progress >= 0.00 && !_isButtonEnabled) {
                      _isButtonEnabled = true;
                      _syncCompletionToWebsite();
                    }
                  });
                }
              },
            );
          },
        ),
      ),
    );

    return _cachedPlayer!;
  }

  Widget _buildSyncButton({bool compact = false}) {
    bool isLocked = _hasVideo() && !_isButtonEnabled && !_isLessonCompleted;

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 4, 12, 12)
          : const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            if (!isLocked && !_isLessonCompleted)
              BoxShadow(
                color: primaryBrown.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: ElevatedButton(
          onPressed: (isLocked || _isMarkingComplete || _isLessonCompleted)
              ? null
              : () async {
                  await _syncCompletionToWebsite();
                  if (mounted && _isLessonCompleted) {
                    _handleNavigation(_lessonData?['next_lesson_id']);
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: _isLessonCompleted
                ? Colors.grey.shade400
                : primaryBrown,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _isLessonCompleted
                ? Colors.grey.shade200
                : Colors.grey.shade400,
            minimumSize: Size(double.infinity, compact ? 46 : 56),
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
                      style: TextStyle(
                        fontSize: compact ? 14 : 16,
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
