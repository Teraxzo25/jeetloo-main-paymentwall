import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class MyRewardsPage extends StatefulWidget {
  @override
  _MyRewardsPageState createState() => _MyRewardsPageState();
}

class _MyRewardsPageState extends State<MyRewardsPage>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? userId;
  List<Map<String, dynamic>> rewards = [];
  bool isLoading = true;
  int totalPendingValue = 0;
  int totalReceivedValue = 0;
  int totalRewards = 0;
  String errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchRewards();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();
  }

  Future<void> _fetchRewards() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = '';
      });

      print('Starting _fetchRewards...');

      // Check if user is authenticated
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        print('Error: User not authenticated');
        setState(() {
          isLoading = false;
          errorMessage = 'User not authenticated. Please login again.';
        });
        Get.snackbar(
          'Authentication Error',
          'Please login again to view your rewards.',
          backgroundColor: Colors.red,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
        return;
      }

      userId = currentUser.uid;
      print('Fetching rewards for user: $userId');

      // First, let's check if the collection exists and has any documents
      final collectionRef = _firestore.collection('luckyDrawResults');
      print('Collection reference created: ${collectionRef.path}');

      // Try to get all documents for this user (without orderBy first)
      final simpleQuery = await collectionRef
          .where('userId', isEqualTo: userId)
          .get();

      print(
        'Simple query completed. Found ${simpleQuery.docs.length} documents',
      );

      if (simpleQuery.docs.isEmpty) {
        print('No documents found for this user');
        setState(() {
          rewards = [];
          totalPendingValue = 0;
          totalReceivedValue = 0;
          totalRewards = 0;
          isLoading = false;
        });
        return;
      }

      // If we have documents, try the ordered query
      QuerySnapshot query;
      try {
        query = await collectionRef
            .where('userId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .get();
        print('Ordered query completed successfully');
      } catch (orderError) {
        print('Ordered query failed: $orderError');
        // Fall back to simple query without ordering
        query = simpleQuery;
        print('Using simple query results instead');
      }

      List<Map<String, dynamic>> fetchedRewards = [];
      int pendingValue = 0;
      int receivedValue = 0;
      int totalCount = 0;

      for (var doc in query.docs) {
        try {
          final data = doc.data() as Map<String, dynamic>?;

          if (data == null) {
            print('Document ${doc.id} has null data');
            continue;
          }

          print('Processing document: ${doc.id}');
          print('Document data: $data');

          final reward = {
            'id': doc.id,
            'prize': data['prize'] ?? 'Unknown Prize',
            'subtitle': data['subtitle'] ?? 'No subtitle',
            'status': data['status'] ?? 'pending',
            'timestamp': data['timestamp'],
            'prizeType': data['prizeType'] ?? 'unknown',
            'adminReviewed': data['adminReviewed'] ?? false,
            'tokensUsed': data['tokensUsed'] ?? 0,
            'needsApproval': data['needsApproval'] ?? false,
          };

          fetchedRewards.add(reward);

          // Calculate statistics - only count non "Better Luck" prizes
          if (reward['prize'] != 'Better Luck') {
            totalCount++;

            // Extract value from prize string
            int prizeValue = _extractPrizeValue(reward['prize'] as String);

            // Add to appropriate category based on status
            if (reward['status'] == 'approved') {
              receivedValue += prizeValue;
            } else if (reward['status'] == 'pending') {
              pendingValue += prizeValue;
            }
            // Note: rejected prizes are counted in totalCount but not in value calculations
          }
        } catch (docError) {
          print('Error processing document ${doc.id}: $docError');
          // Continue processing other documents
        }
      }

      // Sort rewards by timestamp if we couldn't order in query
      fetchedRewards.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;

        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;

        return bTime.compareTo(aTime); // Descending order
      });

      print('Statistics calculated:');
      print('Total Count: $totalCount');
      print('Pending Value: $pendingValue');
      print('Received Value: $receivedValue');
      print('Total Rewards: ${fetchedRewards.length}');

      setState(() {
        rewards = fetchedRewards;
        totalPendingValue = pendingValue;
        totalReceivedValue = receivedValue;
        totalRewards = totalCount;
        isLoading = false;
      });

      print('State updated successfully');
    } catch (e) {
      print('Error in _fetchRewards: $e');
      print('Error type: ${e.runtimeType}');
      print('Error stack trace: ${StackTrace.current}');

      String newErrorMessage = 'Failed to load rewards. Please try again.';

      // Provide more specific error messages
      if (e.toString().contains('permission-denied')) {
        newErrorMessage = 'Permission denied. Please check your access rights.';
      } else if (e.toString().contains('unavailable')) {
        newErrorMessage =
            'Service temporarily unavailable. Please try again later.';
      } else if (e.toString().contains('not-found')) {
        newErrorMessage = 'Rewards data not found.';
      } else if (e.toString().contains('failed-precondition')) {
        newErrorMessage = 'Database index required. Please contact support.';
      }

      setState(() {
        isLoading = false;
        errorMessage = newErrorMessage;
      });

      Get.snackbar(
        'Error',
        newErrorMessage,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 5),
      );
    }
  }

  int _extractPrizeValue(String prize) {
    if (prize == '50 Points') {
      return 50;
    } else if (prize.contains('J coin')) {
      // Extract J coin value
      final prizeText = prize;
      final PkrValue = prizeText
          .replaceAll('J coin', '')
          .replaceAll(',', '')
          .trim();
      return int.tryParse(PkrValue) ?? 0;
    }
    return 0;
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Icons.check_circle;
      case 'pending':
        return Icons.schedule;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return 'Received';
      case 'pending':
        return 'Pending';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Unknown';
    }
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown Date';
    try {
      final date = timestamp.toDate();
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      print('Error formatting date: $e');
      return 'Invalid Date';
    }
  }

  Widget _buildStatsCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Text(
            'Rewards Summary',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatItem(
                  'Total Rewards',
                  '$totalRewards',
                  Icons.emoji_events,
                  Colors.blue,
                ),
              ),
              SizedBox(width: 15),
              Expanded(
                child: _buildStatItem(
                  'Pending Value',
                  totalPendingValue > 0 ? 'J coin $totalPendingValue' : '0',
                  Icons.schedule,
                  Colors.orange,
                ),
              ),
            ],
          ),
          SizedBox(height: 15),
          _buildStatItem(
            'Received Value',
            totalReceivedValue > 0 ? 'J coin $totalReceivedValue' : '0',
            Icons.check_circle,
            Colors.green,
            isFullWidth: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: isFullWidth
          ? Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 5),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
    );
  }

  Widget _buildRewardCard(Map<String, dynamic> reward) {
    final statusColor = _getStatusColor(reward['status']);
    final statusIcon = _getStatusIcon(reward['status']);
    final statusText = _getStatusText(reward['status']);

    return Container(
      margin: EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(statusIcon, color: statusColor, size: 20),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        reward['prize'],
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        reward['subtitle'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
                SizedBox(width: 5),
                Text(
                  _formatDate(reward['timestamp']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.6),
                  ),
                ),
                Spacer(),
                if (reward['tokensUsed'] != null && reward['tokensUsed'] > 0)
                  Row(
                    children: [
                      Icon(
                        Icons.toll,
                        size: 14,
                        color: Colors.white.withOpacity(0.6),
                      ),
                      SizedBox(width: 3),
                      Text(
                        '${reward['tokensUsed']} tokens',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            if (reward['status'] == 'pending' &&
                reward['prize'] != 'Better Luck')
              Container(
                margin: EdgeInsets.only(top: 12),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.blue.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your reward is pending admin approval. You\'ll be notified once processed!',
                        style: TextStyle(fontSize: 11, color: Colors.blue),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: 60,
            color: Colors.red.withOpacity(0.7),
          ),
          SizedBox(height: 15),
          Text(
            'Error Loading Rewards',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 8),
          Text(
            errorMessage.isNotEmpty ? errorMessage : 'Unknown error occurred',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _fetchRewards,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return FadeTransition(
                opacity: _fadeAnimation,
                child: Transform.translate(
                  offset: Offset(0, _slideAnimation.value),
                  child: Column(
                    children: [
                      // Header
                      Padding(
                        padding: EdgeInsets.all(20),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () => Get.back(),
                              icon: Icon(
                                Icons.arrow_back,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.2),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 20,
                                          offset: Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Icons.card_giftcard,
                                      size: 30,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  Text(
                                    'My Rewards',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'Track your lucky draw prizes',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withOpacity(0.8),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 48),
                          ],
                        ),
                      ),
                      // Content
                      Expanded(
                        child: isLoading
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    Text(
                                      'Loading your rewards...',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _fetchRewards,
                                child: SingleChildScrollView(
                                  physics: AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (errorMessage.isNotEmpty)
                                        _buildErrorCard()
                                      else ...[
                                        _buildStatsCard(),
                                        SizedBox(height: 30),
                                        Text(
                                          'Recent Rewards',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(height: 15),
                                        if (rewards.isEmpty)
                                          Container(
                                            padding: EdgeInsets.all(40),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.2,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Icon(
                                                  Icons.card_giftcard_outlined,
                                                  size: 60,
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                ),
                                                SizedBox(height: 15),
                                                Text(
                                                  'No Rewards Yet',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Play Lucky Draw on weekends to win amazing prizes!',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Colors.white
                                                        .withOpacity(0.7),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                SizedBox(height: 20),
                                                ElevatedButton(
                                                  onPressed: () => Get.back(),
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: Colors
                                                        .white
                                                        .withOpacity(0.2),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            25,
                                                          ),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    'Play Lucky Draw',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        else
                                          ...rewards
                                              .map(
                                                (reward) =>
                                                    _buildRewardCard(reward),
                                              )
                                              .toList(),
                                      ],
                                      SizedBox(height: 20),
                                    ],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
