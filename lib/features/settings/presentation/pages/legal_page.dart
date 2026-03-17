import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LegalPage extends ConsumerWidget {
  const LegalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Legal',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Icon(Icons.cast, color: Colors.white),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 8),

          // ✅ Copyright Information FIRST — no WebView, just local page
          _LegalItem(
            title: 'Copyright Information',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _LicensesPage(),
              ),
            ),
          ),

          _LegalItem(
            title: 'Terms of Use',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _WebViewPage(
                  title: 'Terms of Use',
                  url: 'https://pages.soundcloud.com/geo/uk_us_ie/legal/terms-of-use.android.html?format=android',
                ),
              ),
            ),
          ),

          _LegalItem(
            title: 'Privacy Policy',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _WebViewPage(
                  title: 'Privacy Policy',
                  url: 'https://pages.soundcloud.com/geo/uk_us_ie/legal/privacy-policy.android.html?format=android',
                ),
              ),
            ),
          ),

          _LegalItem(
            title: 'Imprint',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const _WebViewPage(
                  title: 'Imprint',
                  url: 'https://pages.soundcloud.com/geo/uk_us_ie/legal/imprint.android.html?format=android',
                ),
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Legal item ────────────────────────────────────────────────────────────────

class _LegalItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _LegalItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontSize: 17),
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white54,
                  size: 15,
                ),
              ],
            ),
          ),
        ),
        const Divider(color: Color(0xFF1F1F1F), height: 1, thickness: 1),
      ],
    );
  }
}

// ── WebView Page — injects dark CSS + blocks external navigation ──────────────

class _WebViewPage extends StatefulWidget {
  final String title;
  final String url;

  const _WebViewPage({required this.title, required this.url});

  @override
  State<_WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<_WebViewPage> {
  late final WebViewController _controller;
  bool _isLoading = true;

  // ── Inject dark mode CSS after page loads ─────────────────────────────────
  static const String _darkModeJS = '''
    document.body.style.backgroundColor = '#111111';
    document.body.style.color = '#CCCCCC';
    document.body.style.fontFamily = 'Arial, sans-serif';
    document.body.style.padding = '16px';

    // Make all text light
    var elements = document.querySelectorAll('*');
    for (var el of elements) {
      el.style.color = '#CCCCCC';
      el.style.backgroundColor = 'transparent';
    }

    // Keep links orange
    var links = document.querySelectorAll('a');
    for (var link of links) {
      link.style.color = '#FF5500';
    }

    // Fix headings
    var headings = document.querySelectorAll('h1, h2, h3, h4, h5, h6');
    for (var h of headings) {
      h.style.color = '#FFFFFF';
    }
  ''';

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF111111))
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            // Inject dark CSS after page loads
            _controller.runJavaScript(_darkModeJS);
            setState(() => _isLoading = false);
          },
          // ✅ Block external links like GitHub
          onNavigationRequest: (NavigationRequest request) {
            // Only allow the original SoundCloud domain
            if (request.url.contains('pages.soundcloud.com')) {
              return NavigationDecision.navigate;
            }
            // Block everything else (GitHub, etc.)
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Icon(Icons.cast, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xFFFF5500),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Copyright Information Page ────────────────────────────────────────────────

class _LicensesPage extends StatelessWidget {
  const _LicensesPage();

  @override
  Widget build(BuildContext context) {
    final licenses = [
      {'name': 'RxJava', 'copyright': '© Netflix Inc. — Apache License 2.0'},
      {'name': 'RxAndroid', 'copyright': '© Netflix Inc. — Apache License 2.0'},
      {'name': 'Universal Image Loader', 'copyright': '© Sergey Tarasevich — Apache License 2.0'},
      {'name': 'Jackson JSON', 'copyright': '© FasterXML LLC — Apache License 2.0'},
      {'name': 'Dagger', 'copyright': '© Square Inc. — Apache License 2.0'},
      {'name': 'OkHttp', 'copyright': '© Square Inc. — Apache License 2.0'},
      {'name': 'ViewPagerIndicator', 'copyright': '© Jake Wharton — Apache License 2.0'},
      {'name': 'libvorbis, libogg', 'copyright': '© Xiph Foundation'},
      {'name': 'liboggz', 'copyright': '© CSIRO Australia'},
      {'name': 'Guava', 'copyright': '© Google Inc. — Apache License 2.0'},
      {'name': 'SlidingUpPanelView', 'copyright': '© Umano — Apache License 2.0'},
      {'name': 'UndoBar', 'copyright': '© Liao Kai — Apache License 2.0'},
      {'name': 'uCrop', 'copyright': 'Yalantis - Apache License 2.0'},
      {'name': 'Facebook Android SDK', 'copyright': '© Facebook Inc. — Apache License 2.0'},
      {'name': 'Rebound', 'copyright': '© Facebook Inc. — BSD License'},
      {'name': 'AOSP', 'copyright': 'This software contains code derived from code developed by The Android Open Source Project'},
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        title: const Text(
          'Copyright Information',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 15),
            child: Icon(Icons.cast, color: Colors.white),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: licenses.length,
        itemBuilder: (context, index) {
          final license = licenses[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  license['name']!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  license['copyright']!,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}