import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────
// PAYMENTWALL SERVICE
// ─────────────────────────────────────────────────────────────

class PaymentwallService {
  static const String _projectKey = '647d99fde028925d3386ceaf9f530952';
  static const String _secretKey = '46a3aaf2c2657b3f1f456a4ed114dbec';
  static const String _widgetCode = 'p1_1';
  static const String _baseUrl = 'https://api.paymentwall.com/api/widget';

  // J Coin packages
  static const List<Map<String, dynamic>> coinPackages = [
    {'coins': 100, 'usd': 1.00, 'label': '100 J Coins'},
    {'coins': 500, 'usd': 4.50, 'label': '500 J Coins'},
    {'coins': 1000, 'usd': 8.00, 'label': '1000 J Coins'},
    {'coins': 5000, 'usd': 35.00, 'label': '5000 J Coins'},
  ];

  /// Generates a signed Paymentwall widget URL
  String generateWidgetUrl({
    required String userId,
    required String userEmail,
    required int coins,
    required double amountUsd,
  }) {
    final orderId = 'JL_${DateTime.now().millisecondsSinceEpoch}';
    final amount = amountUsd.toStringAsFixed(2);
    final productName = '$coins J Coins - JeetLoo';

    final params = <String, String>{
      'ag_external_id': orderId,
      'ag_name': productName,
      'ag_type': 'fixed',
      'amount': amount,
      'currencyCode': 'USD',
      'email': userEmail,
      'failure_url': 'https://jeetlooapp.wixsite.com/jeetlo/payment-failure',
      'key': _projectKey,
      'success_url': 'https://jeetlooapp.wixsite.com/jeetlo/payment-success',
      'uid': userId,
      'widget': _widgetCode,
    };

    // Keys must be sorted alphabetically for correct HMAC
    final sortedKeys = params.keys.toList()..sort();
    final sigString =
        sortedKeys.map((k) => '$k=${params[k]}').join('&') + _secretKey;
    final signature = md5.convert(utf8.encode(sigString)).toString();

    final query =
        sortedKeys.map((k) => '$k=${Uri.encodeComponent(params[k]!)}').join('&');
    return '$_baseUrl?$query&sign=$signature&sign_version=2';
  }

  /// Save pending deposit to Firestore
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

  /// Submit withdrawal request
  Future<PaymentwallResult> submitWithdrawRequest({
    required int coinsAmount,
    required String method,
    required String accountNumber,
    required String accountTitle,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return PaymentwallResult.failure(message: 'Not logged in.');

    final pkrAmount = coinsAmount * 5; // 100 J = 500 PKR
    final fee = (pkrAmount * 0.05).round();

    try {
      await FirebaseFirestore.instance.collection('withdrawal_requests').add({
        'userId': user.uid,
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
        message: 'Withdrawal request submitted. Processing within 24 hours.',
      );
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
