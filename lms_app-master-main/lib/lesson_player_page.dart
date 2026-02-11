import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_html/flutter_html.dart';
import 'services/api_service.dart';
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
  Timer? _handshakeTimer;
  InAppWebViewController? _webViewController;

  final Color primaryBrown = const Color(0xFF6D391E);

  @override
  void initState() {
    super.initState();
    _fetchStatusFromWebsite();
  }

  @override
  void dispose() {
    _cleanupResources();
    super.dispose();
  }

  void _cleanupResources() {
    _handshakeTimer?.cancel();
    _handshakeTimer = null;
    _webViewController?.removeJavaScriptHandler(handlerName: 'onProgress');
  }

  // Robust boolean conversion for API data
  bool _toBool(dynamic value) {
    return value == true ||
        value == "1" ||
        value == 1 ||
        value.toString().toLowerCase() == "true";
  }

  Future<void> _fetchStatusFromWebsite() async {
    final data = await apiService.getLessonDetails(widget.lessonId);
    if (data != null && mounted) {
      setState(() {
        _lessonData = data;
        // PERSISTENCE FIX: Ensure the lesson shows as completed if the website says so
        _isLessonCompleted = _toBool(data['is_completed']);
        _isLoading = false;
      });
    }
  }

  Future<void> _syncCompletionToWebsite() async {
    if (_isMarkingComplete || _isLessonCompleted) return;
    setState(() => _isMarkingComplete = true);

    final result = await apiService.syncLessonWithWebsite(widget.lessonId);

    if (result != null && result['success'] == true && mounted) {
      setState(() {
        _isLessonCompleted = true;
        _isMarkingComplete = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Progress synced with website!"),
          backgroundColor: Colors.green,
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (!mounted) return;
        _handleNavigation(result['next_lesson_id']);
      });
    } else {
      if (mounted) setState(() => _isMarkingComplete = false);
    }
  }

  void _handleNavigation(dynamic nextId) {
    _cleanupResources();

    if (nextId != null && nextId != 0 && nextId != "0") {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LessonPlayerPage(
            lessonId: int.parse(nextId.toString()),
            allLessonIds: widget.allLessonIds,
          ),
        ),
      );
    } else {
      Navigator.pop(context);
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
              child: Center(child: Icon(Icons.quiz, size: 50)),
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
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: InAppWebView(
        initialUrlRequest: URLRequest(
          url: WebUri("https://play.gumlet.io/embed/$videoId"),
          headers: {'Referer': 'https://lms.gdcollege.ca/'},
        ),
        onWebViewCreated: (controller) {
          _webViewController = controller;
          controller.addJavaScriptHandler(
            handlerName: 'onProgress',
            callback: (args) {
              double p = (args[0] as num).toDouble();
              setState(() => _videoProgress = p);
              if (p >= 0.9) _syncCompletionToWebsite();
            },
          );
        },
        onLoadStop: (controller, url) {
          _handshakeTimer?.cancel();
          _handshakeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
            if (_videoProgress > 0) t.cancel();
            controller.evaluateJavascript(
              source: """
              window.addEventListener('message', function(e) {
                try {
                  var d = JSON.parse(e.data);
                  if (d.event === 'timeupdate') {
                    window.flutter_inappwebview.callHandler('onProgress', d.value.seconds / d.value.duration);
                  }
                } catch(err) {}
              });
              var iframe = document.querySelector('iframe');
              if(iframe) {
                iframe.contentWindow.postMessage(JSON.stringify({"context":"player.js","method":"addEventListener","value":"timeupdate"}), '*');
              }
            """,
            );
          });
        },
      ),
    );
  }

  Widget _buildSyncButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: ElevatedButton(
        onPressed: (_isLessonCompleted || _isMarkingComplete)
            ? null
            : _syncCompletionToWebsite,
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBrown,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryBrown.withOpacity(0.5),
          minimumSize: const Size(double.infinity, 54),
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
            : Text(
                _isLessonCompleted ? " Completed" : "Mark as Complete",
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
