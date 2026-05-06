import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

class GuaranteedGiftsScreen extends StatefulWidget {
  @override
  _GuaranteedGiftsScreenState createState() => _GuaranteedGiftsScreenState();
}

class _GuaranteedGiftsScreenState extends State<GuaranteedGiftsScreen>
    with TickerProviderStateMixin {
  late AnimationController _sparkleController;
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _sparkleAnimation;
  late Animation<double> _rotationAnimation;
  late Animation<double> _pulseAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? userId;
  int userTokens = 0;
  bool isLoading = true;
  bool isPurchasing = false;

  // Guaranteed gifts data
  final List<GuaranteedGift> guaranteedGifts = [
    GuaranteedGift(
      id: 'gift_1',
      title: 'Premium Account',
      subtitle: 'Ad-free experience',
      value: 'J coin 500',
      icon: Icons.workspace_premium,
      color: Colors.purple,
      gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
      description: 'Enjoy JeetLoo without any advertisements for 30 days',
    ),
    GuaranteedGift(
      id: 'gift_2',
      title: 'Mobile Recharge',
      subtitle: 'Top-up your phone',
      value: 'J coin 100',
      icon: Icons.phone_android,
      color: Colors.green,
      gradient: [Color(0xFF11998e), Color(0xFF38ef7d)],
      description: 'Instant mobile recharge for any network in Pakistan',
    ),
    GuaranteedGift(
      id: 'gift_3',
      title: 'Gift Voucher',
      subtitle: 'Shopping voucher',
      value: 'J coin 250',
      icon: Icons.card_giftcard,
      color: Colors.orange,
      gradient: [Color(0xFFf093fb), Color(0xFFf5576c)],
      description: 'Universal shopping voucher for online stores',
    ),
    GuaranteedGift(
      id: 'gift_4',
      title: 'Bonus Points',
      subtitle: 'Extra game points',
      value: '1000 PTS',
      icon: Icons.stars,
      color: Colors.amber,
      gradient: [Color(0xFFffecd2), Color(0xFFfcb69f)],
      description: 'Get 1000 bonus points added to your account',
    ),
    GuaranteedGift(
      id: 'gift_5',
      title: 'Data Package',
      subtitle: 'Internet data',
      value: '1GB',
      icon: Icons.wifi,
      color: Colors.blue,
      gradient: [Color(0xFF667eea), Color(0xFF764ba2)],
      description: '1GB high-speed internet data for your mobile',
    ),
    GuaranteedGift(
      id: 'gift_6',
      title: 'Cash Reward',
      subtitle: 'Direct cash',
      value: 'J coin 150',
      icon: Icons.account_balance_wallet,
      color: Colors.teal,
      gradient: [Color(0xFF11998e), Color(0xFF38ef7d)],
      description: 'Direct cash transfer to your account',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchUserData();
  }

  void _initAnimations() {
    _sparkleController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _rotationController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _sparkleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _sparkleController, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 2 * pi).animate(
      CurvedAnimation(parent: _rotationController, curve: Curves.linear),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _sparkleController.repeat(reverse: true);
    _rotationController.repeat();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _fetchUserData() async {
    try {
      userId = _auth.currentUser?.uid;
      if (userId == null) return;

      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          userTokens = data['tokens'] ?? 0;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      Get.snackbar('Error', 'Failed to load user data');
    }
  }

  Future<void> _purchaseGuaranteedGift(GuaranteedGift gift) async {
    if (isPurchasing) return;
    if (userId == null) return;
    if (userTokens < 20) {
      Get.snackbar(
        'Insufficient Tokens',
        'You need 20 tokens to get a guaranteed gift.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      isPurchasing = true;
    });

    try {
      // Deduct tokens
      await _firestore.collection('users').doc(userId).update({
        'tokens': FieldValue.increment(-20),
      });

      // Add to user's rewards
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('guaranteed_gifts')
          .add({
            'giftId': gift.id,
            'title': gift.title,
            'value': gift.value,
            'description': gift.description,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'claimed',
          });

      setState(() {
        userTokens -= 20;
        isPurchasing = false;
      });

      // Show success dialog
      _showSuccessDialog(gift);
    } catch (e) {
      setState(() {
        isPurchasing = false;
      });
      Get.snackbar(
        'Error',
        'Failed to process your request. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _showSuccessDialog(GuaranteedGift gift) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.9,
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            padding: EdgeInsets.all(Get.width * 0.05),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gift.gradient,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: Get.width * 0.2,
                  height: Get.width * 0.2,
                  constraints: BoxConstraints(
                    minWidth: 60,
                    minHeight: 60,
                    maxWidth: 100,
                    maxHeight: 100,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    gift.icon,
                    size: Get.width * 0.08,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: Get.height * 0.025),
                Text(
                  'Congratulations!',
                  style: TextStyle(
                    fontSize: Get.width * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: Get.height * 0.015),
                Text(
                  'You have received:',
                  style: TextStyle(
                    fontSize: Get.width * 0.04,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                SizedBox(height: Get.height * 0.008),
                Text(
                  '${gift.title} - ${gift.value}',
                  style: TextStyle(
                    fontSize: Get.width * 0.045,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: Get.height * 0.015),
                Flexible(
                  child: Text(
                    gift.description,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ),
                SizedBox(height: Get.height * 0.025),
                SizedBox(
                  width: double.infinity,
                  height: Get.height * 0.06,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Get.back();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: gift.color,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: Get.width * 0.08,
                        vertical: Get.height * 0.015,
                      ),
                    ),
                    child: Text(
                      'Awesome!',
                      style: TextStyle(
                        fontSize: Get.width * 0.04,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to get responsive grid count
  int _getGridCrossAxisCount() {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) return 4; // Large tablets/desktops
    if (screenWidth > 800) return 3; // Medium tablets
    if (screenWidth > 600) return 3; // Small tablets
    return 2; // Mobile phones
  }

  // Helper method to get responsive aspect ratio
  double _getGridAspectRatio() {
    double screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 800) return 0.9; // Tablets
    return 0.85; // Mobile
  }

  @override
  void dispose() {
    _sparkleController.dispose();
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            ),
          ),
          child: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
        ),
      );
    }

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
          child: Column(
            children: [
              // Header
              _buildHeader(),
              // Token display
              _buildTokenDisplay(),
              // Gifts grid
              Expanded(child: _buildGiftsGrid()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Get.width * 0.05,
        vertical: Get.height * 0.02,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: EdgeInsets.all(Get.width * 0.02),
              constraints: BoxConstraints(minWidth: 40, minHeight: 40),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: Get.width * 0.06,
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                children: [
                  AnimatedBuilder(
                    animation: _sparkleAnimation,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _sparkleAnimation.value * 2 * pi,
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.amber.withOpacity(
                            0.7 + 0.3 * _sparkleAnimation.value,
                          ),
                          size: Get.width * 0.07,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: Get.height * 0.01),
                  Text(
                    'Guaranteed Gifts',
                    style: TextStyle(
                      fontSize: Get.width * 0.06,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  Text(
                    '100% Win Chance',
                    style: TextStyle(
                      fontSize: Get.width * 0.035,
                      color: Colors.white.withOpacity(0.8),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: Get.width * 0.12), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildTokenDisplay() {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: Get.width * 0.05,
        vertical: Get.height * 0.015,
      ),
      padding: EdgeInsets.all(Get.width * 0.05),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: EdgeInsets.all(Get.width * 0.03),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.toll,
                    color: Colors.green,
                    size: Get.width * 0.06,
                  ),
                ),
              );
            },
          ),
          SizedBox(width: Get.width * 0.04),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Tokens',
                  style: TextStyle(
                    fontSize: Get.width * 0.035,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                Text(
                  '$userTokens',
                  style: TextStyle(
                    fontSize: Get.width * 0.06,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Get.width * 0.03,
              vertical: Get.height * 0.008,
            ),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.local_offer,
                  color: Colors.orange,
                  size: Get.width * 0.04,
                ),
                SizedBox(width: Get.width * 0.01),
                Text(
                  '20 Tokens',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: Get.width * 0.03,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGiftsGrid() {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: Get.width * 0.05,
        vertical: Get.height * 0.01,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _getGridCrossAxisCount(),
              crossAxisSpacing: Get.width * 0.04,
              mainAxisSpacing: Get.height * 0.02,
              childAspectRatio: _getGridAspectRatio(),
            ),
            itemCount: guaranteedGifts.length,
            itemBuilder: (context, index) {
              return _buildGiftCard(guaranteedGifts[index]);
            },
          );
        },
      ),
    );
  }

  Widget _buildGiftCard(GuaranteedGift gift) {
    return GestureDetector(
      onTap: () => _showGiftDetails(gift),
      child: AnimatedBuilder(
        animation: _sparkleAnimation,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gift.gradient,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: gift.color.withOpacity(0.3),
                  blurRadius: 15,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Sparkle effect
                Positioned(
                  top: Get.height * 0.015,
                  right: Get.width * 0.025,
                  child: Transform.rotate(
                    angle: _rotationAnimation.value,
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white.withOpacity(
                        0.5 + 0.5 * _sparkleAnimation.value,
                      ),
                      size: Get.width * 0.05,
                    ),
                  ),
                ),
                // Main content
                Padding(
                  padding: EdgeInsets.all(Get.width * 0.04),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: Get.width * 0.15,
                        height: Get.width * 0.15,
                        constraints: BoxConstraints(
                          minWidth: 50,
                          minHeight: 50,
                          maxWidth: 80,
                          maxHeight: 80,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          gift.icon,
                          color: Colors.white,
                          size: Get.width * 0.08,
                        ),
                      ),
                      SizedBox(height: Get.height * 0.015),
                      Text(
                        gift.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Get.width * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: Get.height * 0.005),
                      Text(
                        gift.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: Get.width * 0.03,
                          color: Colors.white.withOpacity(0.8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: Get.height * 0.01),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: Get.width * 0.03,
                          vertical: Get.height * 0.005,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          gift.value,
                          style: TextStyle(
                            fontSize: Get.width * 0.035,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showGiftDetails(GuaranteedGift gift) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gift.gradient,
            ),
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: Get.width * 0.08,
            vertical: Get.height * 0.04,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: Get.width * 0.1,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: Get.height * 0.025),

              // Gift icon
              Container(
                width: Get.width * 0.25,
                height: Get.width * 0.25,
                constraints: BoxConstraints(
                  minWidth: 80,
                  minHeight: 80,
                  maxWidth: 120,
                  maxHeight: 120,
                ),
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
                  gift.icon,
                  size: Get.width * 0.12,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: Get.height * 0.025),

              // Gift details
              Text(
                gift.title,
                style: TextStyle(
                  fontSize: Get.width * 0.07,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: Get.height * 0.01),
              Text(
                gift.value,
                style: TextStyle(
                  fontSize: Get.width * 0.05,
                  fontWeight: FontWeight.bold,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
              SizedBox(height: Get.height * 0.02),
              Flexible(
                child: Text(
                  gift.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Get.width * 0.04,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.4,
                  ),
                ),
              ),
              SizedBox(height: Get.height * 0.04),

              // Purchase button
              SizedBox(
                width: double.infinity,
                height: Get.height * 0.07,
                child: ElevatedButton(
                  onPressed: isPurchasing
                      ? null
                      : () {
                          Navigator.pop(context);
                          _purchaseGuaranteedGift(gift);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: gift.color,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 5,
                  ),
                  child: isPurchasing
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              gift.color,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.toll, size: Get.width * 0.05),
                            SizedBox(width: Get.width * 0.02),
                            Flexible(
                              child: Text(
                                'Get for 20 Tokens',
                                style: TextStyle(
                                  fontSize: Get.width * 0.045,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              SizedBox(height: Get.height * 0.02),
            ],
          ),
        );
      },
    );
  }
}

// Data model for guaranteed gifts
class GuaranteedGift {
  final String id;
  final String title;
  final String subtitle;
  final String value;
  final IconData icon;
  final Color color;
  final List<Color> gradient;
  final String description;

  GuaranteedGift({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.icon,
    required this.color,
    required this.gradient,
    required this.description,
  });
}
