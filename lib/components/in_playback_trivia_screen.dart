import 'dart:async';
import 'package:flutter/material.dart';

class InPlaybackTriviaScreen extends StatefulWidget {
  const InPlaybackTriviaScreen({Key? key}) : super(key: key);

  @override
  _InPlaybackTriviaScreenState createState() => _InPlaybackTriviaScreenState();
}

class _InPlaybackTriviaScreenState extends State<InPlaybackTriviaScreen> {
  bool _questionShown = false;
  String _feedback = '';
  String _question = '';
  List<String> _options = [];
  String _correctAnswer = '';
  int _timeLeft = 10;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _fetchTriviaQuestion();
  }

  /// Simulates fetching a trivia question from a backend or TMDB.
  Future<void> _fetchTriviaQuestion() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    // Dummy data – in a real app, replace this with an actual API call.
    setState(() {
      _question = "Which actor starred in the lead role of this blockbuster?";
      _options = ["Actor A", "Actor B", "Actor C", "Actor D"];
      _correctAnswer = "Actor A";
      _questionShown = true;
      _feedback = '';
    });
    _startCountdown();
  }

  /// Starts a countdown timer (10 seconds) for answering the question.
  void _startCountdown() {
    setState(() {
      _timeLeft = 10;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft > 0) {
        setState(() {
          _timeLeft--;
        });
      } else {
        timer.cancel();
        setState(() {
          _feedback = "Time's up! The correct answer is $_correctAnswer.";
          _questionShown = false;
        });
        // Fetch the next question after a short delay.
        Future.delayed(const Duration(seconds: 3), () {
          _fetchTriviaQuestion();
        });
      }
    });
  }

  /// Handles answer submission.
  void _submitAnswer(String answer) {
    _countdownTimer?.cancel();
    setState(() {
      if (answer == _correctAnswer) {
        _feedback = "Correct!";
      } else {
        _feedback = "Incorrect. The correct answer is $_correctAnswer.";
      }
      _questionShown = false;
    });
    // Fetch the next question after a short delay.
    Future.delayed(const Duration(seconds: 3), () {
      _fetchTriviaQuestion();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("In-Playback Trivia")),
      body: Column(
        children: [
          // Simulated movie playback area.
          Container(
            height: 200,
            color: Colors.black87,
            child: const Center(
              child: Text("Movie Playback Simulation",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ),
          const SizedBox(height: 20),
          // Show a loading indicator if the question hasn't been fetched yet.
          if (!_questionShown && _feedback.isEmpty)
            const CircularProgressIndicator()
          else if (_questionShown)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _question,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Time left: $_timeLeft seconds",
                      style: const TextStyle(fontSize: 16, color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    Expanded(
                      child: ListView(
                        children: _options.map((option) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 4.0),
                            child: ListTile(
                              title: Text(option),
                              onTap: () => _submitAnswer(option),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_feedback.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(_feedback, style: const TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }
}
