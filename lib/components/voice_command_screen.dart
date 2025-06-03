import 'package:flutter/material.dart';

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({Key? key}) : super(key: key);
  @override
  _VoiceCommandScreenState createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen> {
  final TextEditingController _controller = TextEditingController();
  String _commandResult = "";
  void _simulateVoiceCommand() {
    setState(() {
      _commandResult = "Executing command: ${_controller.text}";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Voice Command Integration")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Simulated voice command (type command below):"),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: "Enter command"),
            ),
            ElevatedButton(
              onPressed: _simulateVoiceCommand,
              child: const Text("Execute"),
            ),
            const SizedBox(height: 20),
            Text(_commandResult),
          ],
        ),
      ),
    );
  }
}
