import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────
// COMBINED PAYMENT SERVICE
// Paymentwall (cards) + JazzCash manual + Easypaisa manual
// ─────────────────────────────────────────────────────────────

class PaymentwallService {
  // ── Paymentwall ──
  static const String _projectKey = '647d99fde028925d3386ceaf9f530952';
  static const String _secretKey = '46a3aaf2c2657b3f1f456a4ed114dbec';
  static const String _widgetCode = 'p1_1';
  static const String _pwBaseUrl = 'https://api.paymentwall.com/api/widget';

  // ── Merchant numbers (manual flow) ──
  static const String jazzCashNumber = '03168727342';
  static const String easypaisaNumber = '03195668133';

  // ── J Coin packages (updated pricing: 100 J = $1.99) ──
  static const List<Map<String, dynamic>> coinPackages = [
    {'coins': 100, 'usd': 1.99, 'label': '100 J Coins'},
    {'coins': 500, 'usd': 8.99, 'label': '500 J Coins'},
    {'coins': 1000, 'usd': 15.99, 'label': '1000 J Coins'},
    {'coins': 5000, 'usd': 69.99, 'label': '5000 J Coins'},
  ];

  // ─────────────────────────────────────────────────────────────
  // PAYMENTWALL — Generate signed widget URL
  // ─────────────────────────────────────────────────────────────

  String generateWidgetUrl({
    required String userId,
    required String userEmail,
    required int coins,
    required double amountUsd,
  }) {
    final orderId = 'JL_${DateTime.now().millisecondsSinceEpoch}';
    final amount = amountUsd.toStringAsFixed(2);
    final productName = '$coins J Coins - JeetLoo';
    final email = userEmail.isEmpty ? '$userId@jeetloo.app' : userEmail;

    final params = <String, String>{
      'ag_external_id': orderId,
      'ag_name': productName,
      'ag_type': 'fixed',
      'amount': amount,
      'currencyCode': 'USD',
      'email': email,
      'failure_url': 'https://jeetlooapp.wixsite.com/jeetlo/payment-failure',
      'key': _projectKey,
      'success_url': 'https://jeetlooapp.wixsite.com/jeetlo/payment-success',
      'uid': userId,
      'widget': _widgetCode,
    };

    final sortedKeys = params.keys.toList()..sort();
    final sigString =
        sortedKeys.map((k) => '$k=${params[k]}').join('&') + _secretKey;
    final signature = md5.convert(utf8.encode(sigString)).toString();
    final query =
        sortedKeys.map((k) => '$k=${Uri.encodeComponent(params[k]!)}').join('&');
    return '$_pwBaseUrl?$query&sign=$signature&sign_version=2';
  }

  // ─────────────────────────────────────────────────────────────
  // JAZZCASH / EASYPAISA — Submit manual deposit request
  // User sends money to the merchant number, enters transaction ID
  // Admin verifies and credits coins manually
  // ─────────────────────────────────────────────────────────────

  Future<PaymentwallResult> submitManualDeposit({
    required String method, // 'JazzCash' or 'Easypaisa'
    required int coins,
    required double amountUsd,
    required String transactionId,
    required String senderMobile,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return PaymentwallResult.failure(message: 'You must be logged in.');

    if (transactionId.trim().isEmpty) {
      return PaymentwallResult.failure(message: 'Please enter your transaction ID.');
    }
    if (senderMobile.trim().length < 11) {
      return PaymentwallResult.failure(message: 'Please enter a valid mobile number.');
    }

    try {
      await FirebaseFirestore.instance.collection('manual_deposits').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'method': method,
        'coins': coins,
        'amountUsd': amountUsd,
        'transactionId': transactionId.trim(),
        'senderMobile': senderMobile.trim(),
        'merchantNumber': method == 'JazzCash' ? jazzCashNumber : easypaisaNumber,
        'status': 'pending', // admin changes to 'approved' or 'rejected'
        'createdAt': FieldValue.serverTimestamp(),
      });

      return PaymentwallResult.success(
        message: 'Request submitted! Your J Coins will be credited within 1 hour after verification.',
      );
    } catch (e) {
      return PaymentwallResult.failure(message: 'Failed to submit: ${e.toString()}');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // PAYMENTWALL — Save pending deposit
  // ─────────────────────────────────────────────────────────────

  Future<void> savePendingDeposit({
    required String userId,
    required int coins,
    required double amountUsd,
  }) async {
    await FirebaseFirestore.instance.collection('transactions').add({
      'userId': userId,
      'method': 'Paymentwall',
      'coins': coins,
      'amountUsd': amountUsd,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ─────────────────────────────────────────────────────────────
  // WITHDRAW — Submit request to Firestore
  // ─────────────────────────────────────────────────────────────

  Future<PaymentwallResult> submitWithdrawRequest({
    required int coinsAmount,
    required String method,
    required String accountNumber,
    required String accountTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return PaymentwallResult.failure(message: 'Not logged in.');

    final pkrAmount = coinsAmount * 5;
    final fee = (pkrAmount * 0.05).round();

    try {
      await FirebaseFirestore.instance.collection('withdrawal_requests').add({
        'userId': user.uid,
        'userEmail': user.email ?? '',
        'method': method,
        'coinsAmount': coinsAmount,
        'pkrAmount': pkrAmount,
        'fee': fee,
        'netAmount': pkrAmount - fee,
        'accountNumber': accountNumber,
        'accountTitle': accountTitle,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return PaymentwallResult.success(
          message: 'Withdrawal request submitted. Processing within 24 hours.');
    } catch (e) {
      return PaymentwallResult.failure(message: 'Error: ${e.toString()}');
    }
  }
}

class PaymentwallResult {
  final bool isSuccess;
  final String message;

  PaymentwallResult._({required this.isSuccess, required this.message});

  factory PaymentwallResult.success({required String message}) =>
      PaymentwallResult._(isSuccess: true, message: message);

  factory PaymentwallResult.failure({required String message}) =>
      PaymentwallResult._(isSuccess: false, message: message);
}
