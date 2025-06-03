import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TrailerPlayerScreen extends StatefulWidget {
  final String trailerKey;
  const TrailerPlayerScreen({Key? key, required this.trailerKey})
      : super(key: key);

  @override
  _TrailerPlayerScreenState createState() => _TrailerPlayerScreenState();
}

class _TrailerPlayerScreenState extends State<TrailerPlayerScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    // Force landscape orientation.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Instantiate and configure the WebViewController.
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(
          'https://www.youtube.com/embed/${widget.trailerKey}?autoplay=1'));
  }

  @override
  void dispose() {
    // Restore portrait orientation when leaving the screen.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Trailer'),
        backgroundColor: Colors.transparent,
      ),
      // Use WebViewWidget with the configured controller.
      body: WebViewWidget(controller: _controller),
    );
  }
}
