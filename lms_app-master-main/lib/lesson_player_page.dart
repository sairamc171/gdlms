import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_html/flutter_html.dart';
import 'app_theme.dart';
import 'services/api_service.dart';
import 'quiz_intro_page.dart';
import 'quiz_result_page.dart';
import 'course_details_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Simple in-memory lesson cache shared across all LessonPlayerPage instances.
// ─────────────────────────────────────────────────────────────────────────────
class _LessonCache {
  static final Map<int, Map<String, dynamic>> _cache = {};

  static Map<String, dynamic>? get(int id) => _cache[id];

  static void put(int id, Map<String, dynamic> data) => _cache[id] = data;

  static bool has(int id) => _cache.containsKey(id);
}

// ─────────────────────────────────────────────────────────────────────────────
// _PersistentWebView — stable GlobalKey keeps WKWebView alive across rebuilds.
// ─────────────────────────────────────────────────────────────────────────────
class _PersistentWebView extends StatefulWidget {
  final String videoId;
  final void Function(InAppWebViewController) onControllerCreated;
  final void Function(double progress) onProgress;

  const _PersistentWebView({
    required Key key,
    required this.videoId,
    required this.onControllerCreated,
    required this.onProgress,
  }) : super(key: key);

  @override
  State<_PersistentWebView> createState() => _PersistentWebViewState();
}

class _PersistentWebViewState extends State<_PersistentWebView> {
  @override
  Widget build(BuildContext context) {
    const String authorizedDomain = 'https://lms.gdcollege.ca/';

    final html =
        '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta name="viewport"
              content="width=device-width, initial-scale=1.0, viewport-fit=cover">
        <style>
          * { box-sizing: border-box; margin: 0; padding: 0; }
          html, body {
            width: 100vw; height: 100vh;
            overflow: hidden; background: #000;
            padding: 0 !important;
          }
          #gumlet-player {
            position: fixed;
            top: 0; left: 0; right: 0; bottom: 0;
            width: 100%; height: 100%;
            border: none; background: #000;
          }
        </style>
      </head>
      <body>
        <iframe
          id="gumlet-player"
          src="https://play.gumlet.io/embed/${widget.videoId}?preload=false&autoplay=false&loop=false&background=false"
          allow="accelerometer; gyroscope; autoplay; encrypted-media; fullscreen; picture-in-picture"
          allowfullscreen playsinline webkit-playsinline>
        </iframe>
        <script src="https://cdn.jsdelivr.net/npm/@gumlet/player.js@latest/dist/player.min.js"></script>
        <script>
          function sendToApp(p) {
            if (window.flutter_inappwebview)
              window.flutter_inappwebview.callHandler('VideoProgress', { progress: p });
          }
          window.onload = function () {
            var iframe = document.getElementById('gumlet-player');
            var player = new playerjs.Player(iframe);
            player.on('ready', function () {
              player.on('timeupdate', function (d) {
                if (d.duration > 0) sendToApp(d.seconds / d.duration);
              });
            });
            function forceFullSize() {
              iframe.style.cssText =
                'position:fixed;top:0;left:0;right:0;bottom:0;' +
                'width:100%;height:100%;border:none;background:#000;';
            }
            ['fullscreenchange','webkitfullscreenchange'].forEach(function(e) {
              document.addEventListener(e, forceFullSize);
              iframe.addEventListener(e, forceFullSize);
            });
            window.addEventListener('resize',            forceFullSize);
            window.addEventListener('orientationchange', forceFullSize);
          };
        </script>
      </body>
      </html>
    ''';

    return InAppWebView(
      initialData: InAppWebViewInitialData(
        data: html,
        baseUrl: WebUri(authorizedDomain),
      ),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        allowsInlineMediaPlayback: true,
        mediaPlaybackRequiresUserGesture: false,
        supportZoom: false,
        allowsAirPlayForMediaPlayback: true,
        allowsPictureInPictureMediaPlayback: true,
      ),
      onWebViewCreated: (controller) {
        controller.addJavaScriptHandler(
          handlerName: 'VideoProgress',
          callback: (args) {
            if (args.isEmpty) return;
            widget.onProgress((args[0]['progress'] as num).toDouble());
          },
        );
        widget.onControllerCreated(controller);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LessonPlayerPage
// ─────────────────────────────────────────────────────────────────────────────
class LessonPlayerPage extends StatefulWidget {
  final int lessonId;
  final List<int> allLessonIds;
  final Map<String, dynamic>? initialData;

  const LessonPlayerPage({
    super.key,
    required this.lessonId,
    required this.allLessonIds,
    this.initialData,
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

  final GlobalKey _webViewKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final cached = widget.initialData ?? _LessonCache.get(widget.lessonId);
    if (cached != null) {
      _applyLessonData(cached);
      _refreshInBackground();
    } else {
      _fetchAndShow();
    }
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
    super.dispose();
  }

  // ── data helpers ───────────────────────────────────────────────────────────

  void _applyLessonData(Map<String, dynamic> data) {
    final isCompleted = _toBool(data['is_completed']);
    final hasNoVideo = (data['video_id']?.toString() ?? '').isEmpty;
    _lessonData = data;
    _isLessonCompleted = isCompleted;
    // FIX: curly_braces_in_flow_control_structures — wrapped single-line ifs
    if (hasNoVideo && !isCompleted) {
      _isButtonEnabled = true;
    }
    if (isCompleted) {
      _isButtonEnabled = true;
    }
    _isLoading = false;
  }

  Future<void> _fetchAndShow() async {
    final data = await apiService.getLessonDetails(widget.lessonId);
    if (!mounted) return;

    if (data != null) {
      _LessonCache.put(widget.lessonId, data);
      setState(() => _applyLessonData(data));
    } else {
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
    _prefetchAdjacentLessons();
  }

  Future<void> _refreshInBackground() async {
    final data = await apiService.getLessonDetails(widget.lessonId);
    if (!mounted || data == null) return;
    _LessonCache.put(widget.lessonId, data);
    final isCompleted = _toBool(data['is_completed']);
    if (isCompleted != _isLessonCompleted) {
      setState(() {
        _isLessonCompleted = isCompleted;
        if (isCompleted) {
          _isButtonEnabled = true;
        }
      });
    }
    _prefetchAdjacentLessons();
  }

  Future<void> _prefetchAdjacentLessons() async {
    final nextId = _nextLessonId;
    final prevId = _previousLessonId;
    if (nextId != null && !_LessonCache.has(nextId)) {
      apiService.getLessonDetails(nextId).then((d) {
        if (d != null) _LessonCache.put(nextId, d);
      });
    }
    if (prevId != null && !_LessonCache.has(prevId)) {
      apiService.getLessonDetails(prevId).then((d) {
        if (d != null) _LessonCache.put(prevId, d);
      });
    }
  }

  // FIX: curly_braces_in_flow_control_structures — all branches now use braces
  bool _toBool(dynamic value) {
    if (value == null || value == false || value == 0 || value == '0') {
      return false;
    }
    if (value == true ||
        value == '1' ||
        value == 1 ||
        value.toString().toLowerCase() == 'true') {
      return true;
    }
    final parsed = int.tryParse(value.toString());
    if (parsed != null && parsed > 1) {
      return true;
    }
    return false;
  }

  bool _hasVideo() => (_lessonData?['video_id']?.toString() ?? '').isNotEmpty;

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

  Future<void> _syncCompletionToWebsite() async {
    if (_isMarkingComplete || _isLessonCompleted) return;
    setState(() => _isMarkingComplete = true);
    final result = await apiService.syncLessonWithWebsite(widget.lessonId);
    if (!mounted) return;
    if (result != null && result['success'] == true) {
      _LessonCache.put(widget.lessonId, {
        ...?_lessonData,
        'is_completed': true,
      });
      setState(() {
        _isLessonCompleted = true;
        _isMarkingComplete = false;
      });
    } else {
      setState(() => _isMarkingComplete = false);
    }
  }

  // FIX: changed void to Future<void> so await callers don't get a warning
  Future<void> _handleNavigation(dynamic nextId) async {
    if (!mounted) return;
    if (nextId == null || nextId == 0) {
      Navigator.pop(context);
      return;
    }

    final id = int.parse(nextId.toString());
    final cached = _LessonCache.get(id);
    final nextData = cached ?? await apiService.getLessonDetails(id);

    // FIX: unnecessary_null_comparison — removed the redundant `if (nextData != null)`
    // that followed immediately after a null-guard return. Now only one null check exists.
    if (!mounted || nextData == null) return;
    _LessonCache.put(id, nextData);

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
            initialData: nextData,
          ),
        ),
      );
    }
  }

  int? get _previousLessonId {
    final idx = widget.allLessonIds.indexOf(widget.lessonId);
    return idx > 0 ? widget.allLessonIds[idx - 1] : null;
  }

  int? get _nextLessonId {
    final idx = widget.allLessonIds.indexOf(widget.lessonId);
    if (idx >= 0 && idx < widget.allLessonIds.length - 1) {
      return widget.allLessonIds[idx + 1];
    }
    final parsedFromApi = _parseInt(_lessonData?['next_lesson_id']);
    return parsedFromApi > 0 ? parsedFromApi : null;
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // FIX: prefer_const_constructors — Scaffold and its subtree are now const
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final videoId = _lessonData!['video_id']?.toString() ?? '';
    final hasVideo = videoId.isNotEmpty;

    final persistentPlayer = hasVideo
        ? _PersistentWebView(
            key: _webViewKey,
            videoId: videoId,
            onControllerCreated: (ctrl) => _webViewController = ctrl,
            onProgress: (progress) {
              if (_isLessonCompleted || !mounted) return;
              if (progress >= 0.90 && !_isButtonEnabled) {
                setState(() => _isButtonEnabled = true);
                _syncCompletionToWebsite();
              }
            },
          )
        : null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppTheme.buildAppBar(
        title: _lessonData!['title']?.toString() ?? 'Lesson',
      ),
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.landscape
                ? _buildLandscapeLayout(persistentPlayer)
                : _buildPortraitLayout(persistentPlayer);
          },
        ),
      ),
    );
  }

  // ── portrait ───────────────────────────────────────────────────────────────

  Widget _buildPortraitLayout(Widget? player) {
    // 1. Fetch the image URL from your data
    final imageUrl = _lessonData?['featured_image']?.toString() ?? '';

    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppTheme.surface,
            border: Border(bottom: BorderSide(color: AppTheme.divider)),
          ),
          child: player != null
              ? AspectRatio(aspectRatio: 16 / 9, child: player)
              : SizedBox(
                  height: 200,
                  width: double.infinity,
                  // 2. Logic: If imageUrl exists, show Image.network, else show Icon
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          // Fallback icon if the image fails to load
                          errorBuilder: (context, error, stackTrace) =>
                              const Center(
                                child: Icon(
                                  Icons.article_outlined,
                                  size: 60,
                                  color: AppTheme.textHint,
                                ),
                              ),
                        )
                      : const Center(
                          child: Icon(
                            Icons.article_outlined,
                            size: 60,
                            color: AppTheme.textHint,
                          ),
                        ),
                ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Html(
              data: _lessonData!['content'] ?? '',
              style: {
                'body': Style(
                  fontSize: FontSize(16.0),
                  lineHeight: const LineHeight(1.5),
                  color: AppTheme.textPrimary,
                ),
                'h2': Style(
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

  // ── landscape ──────────────────────────────────────────────────────────────

  Widget _buildLandscapeLayout(Widget? player) {
    // 1. Fetch the image URL
    final imageUrl = _lessonData?['featured_image']?.toString() ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 5,
          child: ColoredBox(
            color: Colors.black,
            child: Align(
              child: player != null
                  ? LayoutBuilder(
                      builder: (ctx, constraints) {
                        double w = constraints.maxWidth;
                        double h = w * 9 / 16;
                        if (h > constraints.maxHeight) {
                          h = constraints.maxHeight;
                          w = h * 16 / 9;
                        }
                        return SizedBox(width: w, height: h, child: player);
                      },
                    )
                  // 2. Logic: If no player, check for imageUrl, else show Icon
                  : imageUrl.isNotEmpty
                  ? Image.network(
                      imageUrl,
                      fit: BoxFit
                          .contain, // Contain ensures the whole image fits the left side
                      errorBuilder: (c, e, s) => const Icon(
                        Icons.article_outlined,
                        size: 60,
                        color: AppTheme.textHint,
                      ),
                    )
                  : const Icon(
                      Icons.article_outlined,
                      size: 60,
                      color: AppTheme.textHint,
                    ),
            ),
          ),
        ),
        Expanded(
          flex: 5,
          child: ColoredBox(
            color: AppTheme.background,
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Html(
                      data: _lessonData!['content'] ?? '',
                      style: {
                        'body': Style(
                          fontSize: FontSize(14.0),
                          lineHeight: const LineHeight(1.5),
                          color: AppTheme.textPrimary,
                        ),
                        'h2': Style(
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
        ),
      ],
    );
  }
  // ── buttons ────────────────────────────────────────────────────────────────

  Widget _buildPrevNextButtons({bool compact = false}) {
    final hasPrev = _previousLessonId != null;
    final hasNext = _nextLessonId != null && _isButtonEnabled;

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 4, 12, 4)
          : const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: hasPrev
                  ? () => _handleNavigation(_previousLessonId)
                  : null,
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              label: Text(
                'Previous',
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: compact ? 13 : 14,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                disabledForegroundColor: AppTheme.textHint,
                side: BorderSide(
                  color: hasPrev ? AppTheme.primary : AppTheme.placeholder,
                ),
                minimumSize: Size(0, compact ? 42 : 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                style: AppTheme.bodyMedium.copyWith(
                  fontSize: compact ? 13 : 14,
                ),
              ),
              iconAlignment: IconAlignment.end,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                disabledForegroundColor: AppTheme.textHint,
                side: BorderSide(
                  color: hasNext ? AppTheme.primary : AppTheme.placeholder,
                ),
                minimumSize: Size(0, compact ? 42 : 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyncButton({bool compact = false}) {
    final isLocked = _hasVideo() && !_isButtonEnabled && !_isLessonCompleted;

    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(12, 4, 12, 12)
          : const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            if (!isLocked && !_isLessonCompleted)
              // FIX: prefer_const_constructors — BoxShadow and Offset are now const
              const BoxShadow(
                color: Color(0x404B2313), // AppTheme.primary ~25% opacity
                blurRadius: 10,
                offset: Offset(0, 4),
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
                ? AppTheme.completed
                : AppTheme.primary,
            foregroundColor: AppTheme.surface,
            disabledBackgroundColor: _isLessonCompleted
                ? AppTheme.completed.withValues(alpha: 0.5)
                : AppTheme.placeholder,
            minimumSize: Size(double.infinity, compact ? 46 : 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 0,
          ),
          // FIX: prefer_const_constructors — SizedBox + CircularProgressIndicator now const
          child: _isMarkingComplete
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: AppTheme.surface,
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
                      color: AppTheme.surface.withValues(alpha: 0.85),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _isLessonCompleted ? 'Completed' : 'Mark as Completed',
                      style: AppTheme.bodyMedium.copyWith(
                        fontSize: compact ? 14 : 16,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.surface,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
