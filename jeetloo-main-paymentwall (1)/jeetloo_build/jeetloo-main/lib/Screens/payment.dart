import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jeetloo/Screens/paymentwall_service.dart';
import 'package:jeetloo/Screens/paymentwall_webview.dart';

// ─────────────────────────────────────────────────────────────
// PAYMENT SCREEN — Paymentwall Integration
// Place in: lib/Screens/payment.dart
// ─────────────────────────────────────────────────────────────

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentwallService _service = PaymentwallService();

  int _selectedTab = 0; // 0 = Deposit, 1 = Withdraw
  int _selectedPackageIndex = 0;
  String _selectedWithdrawMethod = 'JazzCash';
  bool _isLoading = false;

  final TextEditingController _withdrawAmountController =
      TextEditingController(text: '100');
  final TextEditingController _withdrawAccountController =
      TextEditingController();
  final TextEditingController _withdrawTitleController =
      TextEditingController();

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1a1d29),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1a1d29),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment',
          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildTabSelector(),
                Expanded(
                  child: _selectedTab == 0 ? _buildDepositTab() : _buildWithdrawTab(),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
              ),
            ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB SELECTOR
  // ─────────────────────────────────────────────────────────────

  Widget _buildTabSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF252836),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tabButton('Deposit', 0),
          _tabButton('Withdraw', 1),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF4CAF50) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DEPOSIT TAB
  // ─────────────────────────────────────────────────────────────

  Widget _buildDepositTab() {
    final packages = PaymentwallService.coinPackages;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF252836),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Deposit J Coins',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Secure payment via Paymentwall',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 24),

            const Text(
              'Select Package',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // Coin packages
            ...packages.asMap().entries.map((entry) {
              final i = entry.key;
              final pkg = entry.value;
              final isSelected = _selectedPackageIndex == i;

              return GestureDetector(
                onTap: () => setState(() => _selectedPackageIndex = i),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFF4CAF50).withOpacity(0.1)
                        : const Color(0xFF1a1d29),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[700]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              pkg['label'] as String,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              '\$${(pkg['usd'] as double).toStringAsFixed(2)} USD',
                              style: TextStyle(color: Colors.grey[400], fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50)),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 8),
            Text(
              '🔒 Payments secured by Paymentwall. Supports cards, wallets & local methods.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleDeposit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Proceed to Payment',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Coins credited within 5 minutes after confirmation',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // WITHDRAW TAB
  // ─────────────────────────────────────────────────────────────

  Widget _buildWithdrawTab() {
    final methods = ['JazzCash', 'Easypaisa', 'Bank Transfer'];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF252836),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Withdraw Earnings',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            _buildInput(
              controller: _withdrawAmountController,
              label: 'Amount (J Coins)',
              hint: 'Min. 100',
              type: TextInputType.number,
              suffix: 'J',
            ),
            const SizedBox(height: 8),
            Text('100 J = 500 PKR  •  5% fee applies',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
            const SizedBox(height: 20),

            const Text('Select Method',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),

            ...methods.map((m) {
              final isSelected = _selectedWithdrawMethod == m;
              return GestureDetector(
                onTap: () => setState(() => _selectedWithdrawMethod = m),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : const Color(0xFF1a1d29),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[700]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(m, style: const TextStyle(color: Colors.white, fontSize: 15)),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                    ],
                  ),
                ),
              );
            }).toList(),

            const SizedBox(height: 16),

            _buildInput(
              controller: _withdrawAccountController,
              label: _selectedWithdrawMethod == 'Bank Transfer'
                  ? 'Bank Account Number'
                  : 'Mobile Number',
              hint: _selectedWithdrawMethod == 'Bank Transfer'
                  ? 'PK00XXXX...'
                  : '03001234567',
              type: TextInputType.text,
            ),
            const SizedBox(height: 16),

            _buildInput(
              controller: _withdrawTitleController,
              label: 'Account Name',
              hint: 'Your full name',
              type: TextInputType.name,
            ),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleWithdraw,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Withdraw Now',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Processed manually within 24 hours',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SHARED WIDGETS
  // ─────────────────────────────────────────────────────────────

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required TextInputType type,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1a1d29),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[700]!),
          ),
          child: TextField(
            controller: controller,
            keyboardType: type,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: hint,
              hintStyle: TextStyle(color: Colors.grey[600]),
              suffixText: suffix,
              suffixStyle: TextStyle(color: Colors.grey[400]),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HANDLERS
  // ─────────────────────────────────────────────────────────────

  Future<void> _handleDeposit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _snack('You must be logged in.', error: true);
      return;
    }

    final pkg = PaymentwallService.coinPackages[_selectedPackageIndex];
    final coins = pkg['coins'] as int;
    final usd = pkg['usd'] as double;

    setState(() => _isLoading = true);

    final url = _service.generateWidgetUrl(
      userId: user.uid,
      userEmail: user.email ?? '',
      coins: coins,
      amountUsd: usd,
    );

    await _service.savePendingDeposit(
      userId: user.uid,
      coins: coins,
      amountUsd: usd,
    );

    setState(() => _isLoading = false);

    // Open WebView
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentwallWebView(
          paymentUrl: url,
          coins: coins,
          amountUsd: usd,
        ),
      ),
    );

    if (result == 'success') {
      _showResultDialog(
        success: true,
        message: 'Payment successful! Your $coins J Coins will be credited within 5 minutes.',
      );
    } else if (result == 'failure') {
      _showResultDialog(success: false, message: 'Payment failed. Please try again.');
    }
  }

  Future<void> _handleWithdraw() async {
    final amount = int.tryParse(_withdrawAmountController.text.trim());
    if (amount == null || amount < 100) {
      _snack('Minimum withdrawal is 100 J', error: true);
      return;
    }
    if (_withdrawAccountController.text.trim().isEmpty) {
      _snack('Enter your account/mobile number', error: true);
      return;
    }
    if (_withdrawTitleController.text.trim().isEmpty) {
      _snack('Enter your account name', error: true);
      return;
    }

    setState(() => _isLoading = true);

    final result = await _service.submitWithdrawRequest(
      coinsAmount: amount,
      method: _selectedWithdrawMethod,
      accountNumber: _withdrawAccountController.text.trim(),
      accountTitle: _withdrawTitleController.text.trim(),
    );

    setState(() => _isLoading = false);
    _showResultDialog(success: result.isSuccess, message: result.message);
  }

  void _showResultDialog({required bool success, required String message}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF252836),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? const Color(0xFF4CAF50) : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(success ? 'Success' : 'Failed',
                style: const TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(message, style: TextStyle(color: Colors.grey[300])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: Color(0xFF4CAF50))),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : const Color(0xFF4CAF50),
      ),
    );
  }
}
