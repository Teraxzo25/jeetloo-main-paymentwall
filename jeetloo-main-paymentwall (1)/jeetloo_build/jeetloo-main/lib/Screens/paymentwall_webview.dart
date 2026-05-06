import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:jeetloo/Screens/paymentwall_service.dart';

// ─────────────────────────────────────────────────────────────
// PAYMENTWALL WEBVIEW SCREEN
// Opens the Paymentwall payment page inside the app
// Place in: lib/Screens/paymentwall_webview.dart
// ─────────────────────────────────────────────────────────────

class PaymentwallWebView extends StatefulWidget {
  final String paymentUrl;
  final int coins;
  final double amountUsd;

  const PaymentwallWebView({
    Key? key,
    required this.paymentUrl,
    required this.coins,
    required this.amountUsd,
  }) : super(key: key);

  @override
  State<PaymentwallWebView> createState() => _PaymentwallWebViewState();
}

class _PaymentwallWebViewState extends State<PaymentwallWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() => _isLoading = true),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            // Detect success or failure redirect
            if (request.url.contains('payment-success')) {
              Navigator.pop(context, 'success');
              return NavigationDecision.prevent;
            }
            if (request.url.contains('payment-failure')) {
              Navigator.pop(context, 'failure');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1d29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1d29),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context, 'cancelled'),
        ),
        title: Text(
          'Buy ${widget.coins} J Coins — \$${widget.amountUsd.toStringAsFixed(2)}',
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
            ),
        ],
      ),
    );
  }
}
