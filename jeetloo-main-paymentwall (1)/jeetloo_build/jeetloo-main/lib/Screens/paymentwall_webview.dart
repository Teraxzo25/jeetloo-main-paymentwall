import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:jeetloo/Screens/paymentwall_service.dart';

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
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) => setState(() {
            _isLoading = true;
            _hasError = false;
          }),
          onPageFinished: (_) => setState(() => _isLoading = false),
          onWebResourceError: (error) {
            // Ignore sub-resource errors, only catch main frame errors
            if (error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onHttpError: (error) {
            if (error.response?.statusCode != null &&
                error.response!.statusCode! >= 400) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
          onNavigationRequest: (request) {
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
      body: Stack(children: [
        if (!_hasError) WebViewWidget(controller: _controller),
        if (_isLoading && !_hasError)
          const Center(
            child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
          ),
        if (_hasError)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.payment, color: Colors.orange, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Payment Unavailable',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  'Card payments are currently under review and will be available soon.\n\nPlease use JazzCash or Easypaisa to deposit for now.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'cancelled'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Go Back',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
          ),
      ]),
    );
  }
}
