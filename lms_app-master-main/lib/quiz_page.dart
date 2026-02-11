import 'package:flutter/material.dart';
import 'services/api_service.dart';

class QuizPage extends StatefulWidget {
  final int quizId;
  final String title;

  const QuizPage({super.key, required this.quizId, required this.title});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  List<dynamic> _questions = [];
  bool _isLoading = true;
  int _currentQuestionIndex = 0;
  Map<int, int> _userAnswers = {}; // question_id -> answer_id

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  Future<void> _loadQuestions() async {
    final data = await apiService.getQuizQuestions(
      widget.quizId,
    ); // Uses your api_service
    setState(() {
      _questions = data;
      _isLoading = false;
    });
  }

  Future<void> _submitQuiz() async {
    setState(() => _isLoading = true);
    // Syncs with the website using your unified sync handler
    final result = await apiService.syncLessonWithWebsite(
      widget.quizId,
      itemType: 'quiz',
    );

    if (result != null && result['success'] == true) {
      Navigator.pop(
        context,
        true,
      ); // Return true to trigger refresh in curriculum
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_questions.isEmpty)
      return const Scaffold(body: Center(child: Text("No questions found.")));

    final currentQuestion = _questions[_currentQuestionIndex];

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              "Question ${_currentQuestionIndex + 1} of ${_questions.length}",
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            Text(
              currentQuestion['title'],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ...(currentQuestion['options'] as List).map((opt) {
              return RadioListTile<int>(
                title: Text(opt['answer_text']),
                value: int.parse(opt['answer_id'].toString()),
                groupValue: _userAnswers[currentQuestion['id']],
                onChanged: (val) =>
                    setState(() => _userAnswers[currentQuestion['id']] = val!),
              );
            }).toList(),
            const Spacer(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: () {
                if (_currentQuestionIndex < _questions.length - 1) {
                  setState(() => _currentQuestionIndex++);
                } else {
                  _submitQuiz();
                }
              },
              child: Text(
                _currentQuestionIndex < _questions.length - 1
                    ? "Next"
                    : "Submit Quiz",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
