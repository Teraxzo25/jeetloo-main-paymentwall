import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:jeetloo/Screens/paymentwall_service.dart';

// ─────────────────────────────────────────────────────────────
// PAYMENT SCREEN
// JazzCash (manual) + Easypaisa (manual) — Active
// Paymentwall (cards) — Hidden until account is approved
// ─────────────────────────────────────────────────────────────

class PaymentScreen extends StatefulWidget {
  @override
  _PaymentScreenState createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final PaymentwallService _service = PaymentwallService();

  int _tab = 0;
  String _depositMethod = 'JazzCash';
  String _withdrawMethod = 'JazzCash';
  int _manualPackageIndex = 0;
  bool _isLoading = false;

  final _txnIdCtrl = TextEditingController();
  final _senderMobileCtrl = TextEditingController();
  final _withdrawAmountCtrl = TextEditingController(text: '100');
  final _withdrawAccountCtrl = TextEditingController();
  final _withdrawTitleCtrl = TextEditingController();

  static const Color _green = Color(0xFF4CAF50);
  static const Color _bg = Color(0xFF1a1d29);
  static const Color _card = Color(0xFF252836);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Payment',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
      ),
      body: Stack(children: [
        SafeArea(
          child: Column(children: [
            _tabs(),
            Expanded(child: _tab == 0 ? _depositTab() : _withdrawTab()),
          ]),
        ),
        if (_isLoading)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: _green)),
          ),
      ]),
    );
  }

  // ── TABS ──

  Widget _tabs() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [_tabBtn('Deposit', 0), _tabBtn('Withdraw', 1)]),
    );
  }

  Widget _tabBtn(String label, int index) {
    final active = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  // ── DEPOSIT TAB ──

  Widget _depositTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Deposit J Coins',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          // ── "Coming Soon" notice for card payments ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.amber.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.amber, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Card payments coming soon. Please use JazzCash or Easypaisa.',
                  style: TextStyle(color: Colors.amber[200], fontSize: 12),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          const Text('Select Method',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Only show JazzCash and Easypaisa — Paymentwall hidden
          _methodTile('JazzCash', Icons.phone_android, const Color(0xFFFF6B35), true),
          _methodTile('Easypaisa', Icons.account_balance_wallet, _green, true),

          const SizedBox(height: 20),

          const Text('Select Package',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          ...PaymentwallService.coinPackages.asMap().entries.map((e) {
            final i = e.key;
            final pkg = e.value;
            final selected = _manualPackageIndex == i;
            return GestureDetector(
              onTap: () => setState(() => _manualPackageIndex = i),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected ? _green.withOpacity(0.1) : _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? _green : Colors.grey[700]!, width: selected ? 2 : 1),
                ),
                child: Row(children: [
                  Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
                    child: const Center(child: Text('J', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(pkg['label'] as String,
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('\$${(pkg['usd'] as double).toStringAsFixed(2)} USD',
                        style: TextStyle(color: Colors.grey[400], fontSize: 13)),
                  ])),
                  if (selected) const Icon(Icons.check_circle, color: _green),
                ]),
              ),
            );
          }).toList(),

          const SizedBox(height: 20),

          _instructionBox(),
          const SizedBox(height: 20),

          _input(_senderMobileCtrl, 'Your Mobile Number', '03001234567', TextInputType.phone),
          const SizedBox(height: 16),
          _input(_txnIdCtrl, 'Transaction ID', 'Enter ID from your payment receipt', TextInputType.text),
          const SizedBox(height: 20),

          _actionBtn('Submit Deposit Request', _handleManualDeposit),
          const SizedBox(height: 12),
          Center(
            child: Text(
              'Coins credited within 1 hour after verification',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        ]),
      ),
    );
  }

  // ── INSTRUCTION BOX ──

  Widget _instructionBox() {
    final isJazz = _depositMethod == 'JazzCash';
    final number = isJazz ? PaymentwallService.jazzCashNumber : PaymentwallService.easypaisaNumber;
    final pkg = PaymentwallService.coinPackages[_manualPackageIndex];
    final amount = '\$${(pkg['usd'] as double).toStringAsFixed(2)}';
    final coins = pkg['coins'];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isJazz
            ? const Color(0xFFFF6B35).withOpacity(0.1)
            : _green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isJazz ? const Color(0xFFFF6B35).withOpacity(0.5) : _green.withOpacity(0.5),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          '${isJazz ? "JazzCash" : "Easypaisa"} Payment Instructions',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        _step('1', 'Open your ${isJazz ? "JazzCash" : "Easypaisa"} app'),
        _step('2', 'Send $amount to:'),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: number));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Number copied!'), backgroundColor: _green),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[600]!),
            ),
            child: Row(children: [
              Text(number,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
                      letterSpacing: 1.5)),
              const Spacer(),
              const Icon(Icons.copy, color: _green, size: 18),
              const SizedBox(width: 4),
              const Text('Copy', style: TextStyle(color: _green, fontSize: 12)),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        _step('3', 'Enter your transaction ID below'),
        _step('4', 'Submit — your $coins J Coins will be credited within 1 hour'),
      ]),
    );
  }

  Widget _step(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20,
          decoration: const BoxDecoration(color: _green, shape: BoxShape.circle),
          child: Center(
            child: Text(number, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: TextStyle(color: Colors.grey[300], fontSize: 13))),
      ]),
    );
  }

  // ── WITHDRAW TAB ──

  Widget _withdrawTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Withdraw Earnings',
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          _input(_withdrawAmountCtrl, 'Amount (J Coins)', 'Min. 100', TextInputType.number, suffix: 'J'),
          const SizedBox(height: 8),
          Text('100 J = 500 PKR  •  5% fee applies',
              style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          const SizedBox(height: 20),

          const Text('Select Method',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          _methodTile('JazzCash', Icons.phone_android, const Color(0xFFFF6B35), false),
          _methodTile('Easypaisa', Icons.account_balance_wallet, _green, false),
          _methodTile('Bank Transfer', Icons.account_balance, const Color(0xFF2196F3), false),

          const SizedBox(height: 20),

          _input(
            _withdrawAccountCtrl,
            _withdrawMethod == 'Bank Transfer' ? 'Bank Account Number' : 'Mobile Number',
            _withdrawMethod == 'Bank Transfer' ? 'PK00XXXX...' : '03001234567',
            TextInputType.text,
          ),
          const SizedBox(height: 16),
          _input(_withdrawTitleCtrl, 'Account Name', 'Your full name', TextInputType.name),
          const SizedBox(height: 20),

          _actionBtn('Withdraw Now', _handleWithdraw),
          const SizedBox(height: 12),
          Center(
            child: Text('Processed manually within 24 hours',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ),
        ]),
      ),
    );
  }

  // ── SHARED WIDGETS ──

  Widget _methodTile(String name, IconData icon, Color color, bool isDeposit) {
    final selected = isDeposit ? _depositMethod == name : _withdrawMethod == name;
    return GestureDetector(
      onTap: () => setState(() => isDeposit ? _depositMethod = name : _withdrawMethod = name),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _green.withOpacity(0.1) : _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? _green : Colors.grey[700]!, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(name,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500))),
          if (selected) const Icon(Icons.check_circle, color: _green, size: 20),
        ]),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, String hint, TextInputType type,
      {String? suffix}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[700]!),
        ),
        child: TextField(
          controller: ctrl,
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
    ]);
  }

  Widget _actionBtn(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          disabledBackgroundColor: Colors.grey[700],
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // ── HANDLERS ──

  Future<void> _handleManualDeposit() async {
    final pkg = PaymentwallService.coinPackages[_manualPackageIndex];
    final coins = pkg['coins'] as int;
    final usd = pkg['usd'] as double;

    setState(() => _isLoading = true);

    final result = await _service.submitManualDeposit(
      method: _depositMethod,
      coins: coins,
      amountUsd: usd,
      transactionId: _txnIdCtrl.text,
      senderMobile: _senderMobileCtrl.text,
    );

    setState(() => _isLoading = false);

    if (result.isSuccess) {
      _txnIdCtrl.clear();
      _senderMobileCtrl.clear();
    }

    _dialog(result.isSuccess, result.message);
  }

  Future<void> _handleWithdraw() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { _snack('You must be logged in.', error: true); return; }

    final amount = int.tryParse(_withdrawAmountCtrl.text.trim());
    if (amount == null || amount < 100) { _snack('Minimum withdrawal is 100 J', error: true); return; }
    if (_withdrawAccountCtrl.text.trim().isEmpty) { _snack('Enter your account/mobile number', error: true); return; }
    if (_withdrawTitleCtrl.text.trim().isEmpty) { _snack('Enter your account name', error: true); return; }

    setState(() => _isLoading = true);

    final requiredPoints = amount * 100;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final rawPoints = userDoc.data()?['points'];
    final currentPoints = rawPoints is int ? rawPoints : (rawPoints as num?)?.toInt() ?? 0;

    if (currentPoints < requiredPoints) {
      final availableCoins = (currentPoints / 100).floor();
      setState(() => _isLoading = false);
      _snack('Insufficient balance. You have $availableCoins J Coins available.', error: true);
      return;
    }

    final result = await _service.submitWithdrawRequest(
      coinsAmount: amount,
      method: _withdrawMethod,
      accountNumber: _withdrawAccountCtrl.text.trim(),
      accountTitle: _withdrawTitleCtrl.text.trim(),
    );

    setState(() => _isLoading = false);
    _dialog(result.isSuccess, result.message);
  }

  void _dialog(bool success, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(success ? Icons.check_circle : Icons.error,
              color: success ? _green : Colors.red),
          const SizedBox(width: 8),
          Text(success ? 'Success' : 'Failed',
              style: const TextStyle(color: Colors.white)),
        ]),
        content: Text(message, style: TextStyle(color: Colors.grey[300])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: _green)),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {required bool error}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : _green),
    );
  }
}
