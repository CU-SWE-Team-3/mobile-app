import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _siteKey = '6LeDUossAAAAAMWPIJONmtqHz_9DIWkponxfVIkJ';

const _recaptchaHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      background: #1a1a1a;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      font-family: -apple-system, sans-serif;
    }
    h3 {
      color: #ffffff;
      font-size: 16px;
      margin-bottom: 20px;
      font-weight: 500;
    }
  </style>
  <script src="https://www.google.com/recaptcha/api.js" async defer></script>
  <script>
    function onCaptchaSolved(token) {
      CaptchaChannel.postMessage(token);
    }
  </script>
</head>
<body>
  <h3>Verify you're not a robot</h3>
  <div
    class="g-recaptcha"
    data-sitekey="$_siteKey"
    data-callback="onCaptchaSolved"
    data-theme="dark">
  </div>
</body>
</html>
''';

/// Shows a bottom sheet with a real reCAPTCHA widget.
/// Returns the token string, or null if dismissed without solving.
Future<String?> showRecaptchaBottomSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1A1A1A),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => const _RecaptchaSheet(),
  );
}

class _RecaptchaSheet extends StatefulWidget {
  const _RecaptchaSheet();

  @override
  State<_RecaptchaSheet> createState() => _RecaptchaSheetState();
}

class _RecaptchaSheetState extends State<_RecaptchaSheet> {
  late final WebViewController _controller;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CaptchaChannel',
        onMessageReceived: (msg) {
          final token = msg.message;
          if (token.isNotEmpty && mounted) {
            Navigator.of(context).pop(token);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
      ))
      ..loadHtmlString(_recaptchaHtml, baseUrl: 'http://localhost');
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.55,
      child: Column(
        children: [
          // Drag handle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF555555),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_loading)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFFFF5500)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
