import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// A small browser inside the app (no need to leave Kainuwa Studio). Back goes to the page before,
/// and when there is none it closes the browser.
class WebPageScreen extends StatefulWidget {
  const WebPageScreen({super.key, required this.url, this.title = 'Browser'});

  final String url;
  final String title;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  String _title = '';
  bool _canGoBack = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onPageFinished: (_) async {
            final title = await _controller.getTitle();
            final back = await _controller.canGoBack();
            if (mounted) {
              setState(() {
                _title = title ?? '';
                _canGoBack = back;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_canGoBack,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _controller.goBack();
        final back = await _controller.canGoBack();
        if (mounted) setState(() => _canGoBack = back);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_title.isEmpty ? widget.title : _title, maxLines: 1, overflow: TextOverflow.ellipsis),
          actions: [
            IconButton(
              tooltip: 'Reload',
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
            ),
          ],
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100, minHeight: 3),
                )
              : null,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
