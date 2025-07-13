import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class RainfallWebView extends StatefulWidget {
  final String url;
  final String? stationId;
  const RainfallWebView({super.key, required this.url, this.stationId});

  @override
  State<RainfallWebView> createState() => _RainfallWebViewState();
}

class _RainfallWebViewState extends State<RainfallWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cumulato 30 g'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
