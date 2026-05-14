import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────────────────────
// ADMIN PANEL
// Only accessible to Jeetlooapp@gmail.com
// ─────────────────────────────────────────────────────────────

class AdminPanel extends StatefulWidget {
  @override
  _AdminPanelState createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel>
    with SingleTickerProviderStateMixin {
  static const String _adminEmail = 'Jeetlooapp@gmail.com';
  static const Color _green = Color(0xFF4CAF50);
  static const Color _bg = Color(0xFF1a1d29);
  static const Color _card = Color(0xFF252836);

  late TabController _tabController;
  bool _isAuthorized = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkAuth();
  }

  void _checkAuth() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _isAuthorized =
          user != null && user.email?.toLowerCase() == _adminEmail.toLowerCase();
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        backgroundColor: Color(0xFF1a1d29),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF4CAF50))),
      );
    }

    if (!_isAuthorized) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          backgroundColor: _bg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text('Admin Panel',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        body: const Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.lock, color: Colors.red, size: 64),
            SizedBox(height: 16),
            Text('Access Denied',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('You are not authorized to view this page.',
                style: TextStyle(color: Colors.grey, fontSize: 14)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Admin Panel',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _green,
          labelColor: _green,
          unselectedLabelColor: Colors.grey,
          tabs: const [
            Tab(text: 'Deposits'),
            Tab(text: 'Withdrawals'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DepositsTab(),
          _WithdrawalsTab(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// DEPOSITS TAB
// ─────────────────────────────────────────────────────────────

class _DepositsTab extends StatelessWidget {
  static const Color _green = Color(0xFF4CAF50);
  static const Color _bg = Color(0xFF1a1d29);
  static const Color _card = Color(0xFF252836);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Container(
          color: _bg,
          child: const TabBar(
            indicatorColor: _green,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Approved'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            _depositList(context, 'pending'),
            _depositList(context, 'approved'),
            _depositList(context, 'rejected'),
          ]),
        ),
      ]),
    );
  }

  Widget _depositList(BuildContext context, String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('manual_deposits')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No $status deposits',
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snapshot.data!.docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _DepositCard(
              docId: doc.id,
              data: data,
              status: status,
            );
          },
        );
      },
    );
  }
}

class _DepositCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String status;

  const _DepositCard({
    required this.docId,
    required this.data,
    required this.status,
  });

  @override
  _DepositCardState createState() => _DepositCardState();
}

class _DepositCardState extends State<_DepositCard> {
  static const Color _green = Color(0xFF4CAF50);
  static const Color _card = Color(0xFF252836);
  bool _processing = false;

  Future<void> _approve() async {
    setState(() => _processing = true);
    try {
      final userId = widget.data['userId'];
      final coins = widget.data['coins'] as int;

      // Credit coins to user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'points': FieldValue.increment(coins)});

      // Update deposit status
      await FirebaseFirestore.instance
          .collection('manual_deposits')
          .doc(widget.docId)
          .update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Approved! $coins J Coins credited to user.'),
          backgroundColor: _green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _processing = false);
  }

  Future<void> _reject() async {
    setState(() => _processing = true);
    try {
      await FirebaseFirestore.instance
          .collection('manual_deposits')
          .doc(widget.docId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Deposit rejected.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final coins = data['coins'] ?? 0;
    final amount = data['amountUsd'] ?? 0;
    final method = data['method'] ?? '';
    final txnId = data['transactionId'] ?? '';
    final senderMobile = data['senderMobile'] ?? '';
    final merchantNumber = data['merchantNumber'] ?? '';
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.status == 'pending'
              ? Colors.orange.withOpacity(0.5)
              : widget.status == 'approved'
                  ? _green.withOpacity(0.5)
                  : Colors.red.withOpacity(0.5),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: method == 'JazzCash'
                  ? const Color(0xFFFF6B35).withOpacity(0.2)
                  : _green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(method,
                style: TextStyle(
                    color: method == 'JazzCash'
                        ? const Color(0xFFFF6B35)
                        : _green,
                    fontWeight: FontWeight.bold,
                    fontSize: 13)),
          ),
          const Spacer(),
          Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const SizedBox(height: 12),

        // Coins & Amount
        Row(children: [
          _infoChip('$coins J Coins', Icons.monetization_on, _green),
          const SizedBox(width: 8),
          _infoChip('\$$amount USD', Icons.attach_money, Colors.blue),
        ]),
        const SizedBox(height: 12),

        // Details
        _row('Sender Mobile', senderMobile),
        _row('Transaction ID', txnId),
        _row('Sent To', merchantNumber),
        _row('User ID', data['userId'] ?? ''),

        // Approve / Reject buttons (only for pending)
        if (widget.status == 'pending') ...[
          const SizedBox(height: 16),
          _processing
              ? const Center(child: CircularProgressIndicator(color: _green))
              : Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _approve,
                      icon: const Icon(Icons.check, color: Colors.white, size: 18),
                      label: const Text('Approve',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      label: const Text('Reject',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
        ],

        if (widget.status == 'approved')
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.check_circle, color: _green, size: 16),
              SizedBox(width: 6),
              Text('Coins credited to user', style: TextStyle(color: _green, fontSize: 13)),
            ]),
          ),

        if (widget.status == 'rejected')
          Container(
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(children: [
              Icon(Icons.cancel, color: Colors.red, size: 16),
              SizedBox(width: 6),
              Text('Deposit rejected', style: TextStyle(color: Colors.red, fontSize: 13)),
            ]),
          ),
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _infoChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WITHDRAWALS TAB
// ─────────────────────────────────────────────────────────────

class _WithdrawalsTab extends StatelessWidget {
  static const Color _green = Color(0xFF4CAF50);
  static const Color _bg = Color(0xFF1a1d29);
  static const Color _card = Color(0xFF252836);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(children: [
        Container(
          color: _bg,
          child: const TabBar(
            indicatorColor: _green,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(text: 'Pending'),
              Tab(text: 'Processed'),
              Tab(text: 'Rejected'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(children: [
            _withdrawList(context, 'pending'),
            _withdrawList(context, 'processed'),
            _withdrawList(context, 'rejected'),
          ]),
        ),
      ]),
    );
  }

  Widget _withdrawList(BuildContext context, String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _green));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No $status withdrawals',
                style: const TextStyle(color: Colors.grey, fontSize: 16)),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, i) {
            final doc = snapshot.data!.docs[i];
            final data = doc.data() as Map<String, dynamic>;
            return _WithdrawalCard(docId: doc.id, data: data, status: status);
          },
        );
      },
    );
  }
}

class _WithdrawalCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final String status;

  const _WithdrawalCard({
    required this.docId,
    required this.data,
    required this.status,
  });

  @override
  _WithdrawalCardState createState() => _WithdrawalCardState();
}

class _WithdrawalCardState extends State<_WithdrawalCard> {
  static const Color _green = Color(0xFF4CAF50);
  static const Color _card = Color(0xFF252836);
  bool _processing = false;

  Future<void> _markProcessed() async {
    setState(() => _processing = true);
    try {
      await FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .doc(widget.docId)
          .update({
        'status': 'processed',
        'processedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Withdrawal marked as processed.'),
          backgroundColor: _green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _processing = false);
  }

  Future<void> _reject() async {
    setState(() => _processing = true);
    try {
      final userId = widget.data['userId'];
      final coinsAmount = widget.data['coinsAmount'] as int;

      // Refund coins to user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .update({'points': FieldValue.increment(coinsAmount)});

      await FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .doc(widget.docId)
          .update({
        'status': 'rejected',
        'rejectedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Rejected. $coinsAmount J Coins refunded to user.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
    setState(() => _processing = false);
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final coins = data['coinsAmount'] ?? 0;
    final pkr = data['pkrAmount'] ?? 0;
    final net = data['netAmount'] ?? 0;
    final fee = data['fee'] ?? 0;
    final method = data['method'] ?? '';
    final account = data['accountNumber'] ?? '';
    final title = data['accountTitle'] ?? '';
    final ts = data['createdAt'] as Timestamp?;
    final date = ts != null
        ? '${ts.toDate().day}/${ts.toDate().month}/${ts.toDate().year} ${ts.toDate().hour}:${ts.toDate().minute.toString().padLeft(2, '0')}'
        : 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.status == 'pending'
              ? Colors.orange.withOpacity(0.5)
              : widget.status == 'processed'
                  ? _green.withOpacity(0.5)
                  : Colors.red.withOpacity(0.5),
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(method,
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const Spacer(),
          Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
        const SizedBox(height: 12),

        Row(children: [
          _chip('$coins J Coins', _green),
          const SizedBox(width: 8),
          _chip('PKR $pkr', Colors.orange),
          const SizedBox(width: 8),
          _chip('Net: PKR $net', Colors.blue),
        ]),
        const SizedBox(height: 4),
        Text('Fee: PKR $fee', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 12),

        _row('Account Name', title),
        _row('Account Number', account),
        _row('Method', method),
        _row('User ID', data['userId'] ?? ''),

        if (widget.status == 'pending') ...[
          const SizedBox(height: 16),
          _processing
              ? const Center(child: CircularProgressIndicator(color: _green))
              : Row(children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _markProcessed,
                      icon: const Icon(Icons.send, color: Colors.white, size: 18),
                      label: const Text('Mark Sent',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _reject,
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      label: const Text('Reject',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ]),
        ],
      ]),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ]),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
