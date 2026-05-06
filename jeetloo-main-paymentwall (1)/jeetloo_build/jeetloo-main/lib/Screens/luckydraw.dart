import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class LuckyDrawSystem extends StatefulWidget {
  @override
  _LuckyDrawSystemState createState() => _LuckyDrawSystemState();
}

class _LuckyDrawSystemState extends State<LuckyDrawSystem>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _wheelController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _wheelAnimation;
  late Animation<double> _pulseAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? userId;
  int userTokens = 0;
  int todaySpins = 0;
  bool isSpinning = false;
  String? winningPrize;
  bool showResult = false;
  bool isWeekend = false;

  // Prize wheel segments with their probabilities
  final List<Map<String, dynamic>> prizeSegments = [
    {
      'title': '250 J Jackpot',
      'subtitle': 'Jackpot Prize',
      'color': Color(0xFFFFD700), // Gold
      'probability': 1,
      'icon': Icons.emoji_events,
    },
    {
      'title': '100 J Big Win',
      'subtitle': 'Big Prize',
      'color': Color(0xFFC0C0C0), // Silver
      'probability': 3,
      'icon': Icons.star,
    },
    {
      'title': '75 J Medium Win',
      'subtitle': 'Medium Prize',
      'color': Color(0xFFCD7F32), // Bronze
      'probability': 6,
      'icon': Icons.workspace_premium,
    },
    {
      'title': '30 J Small Win',
      'subtitle': 'Small Prize',
      'color': Color(0xFF4CAF50), // Green
      'probability': 10,
      'icon': Icons.card_giftcard,
    },
    {
      'title': '12 J Frequent Win',
      'subtitle': 'Frequent Prize',
      'color': Color(0xFF2196F3), // Blue
      'probability': 20,
      'icon': Icons.redeem,
    },
    {
      'title': '5 J Mini Win',
      'subtitle': 'Mini Prize',
      'color': Color(0xFF9C27B0), // Purple
      'probability': 25,
      'icon': Icons.star_half,
    },
    {
      'title': 'Better Luck',
      'subtitle': 'Next Time',
      'color': Color(0xFF607D8B), // Blue Grey
      'probability': 25,
      'icon': Icons.sentiment_dissatisfied,
    },
    {
      'title': '50 Bonus Points',
      'subtitle': 'Non-withdrawable',
      'color': Color(0xFFFF5722), // Deep Orange
      'probability': 10,
      'icon': Icons.star_border,
    },
  ];

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkWeekendAndFetchData();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _wheelController = AnimationController(
      duration: Duration(milliseconds: 4000),
      vsync: this,
    );

    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _wheelAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _wheelController, curve: Curves.easeOut));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  Future<void> _checkWeekendAndFetchData() async {
    // Check if today is weekend (Saturday = 6, Sunday = 7)
    final now = DateTime.now();
    isWeekend = now.weekday == DateTime.sunday;

    await _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        userTokens = data['tokens'] ?? 0;
      });
    }
  }

  Map<String, dynamic> _selectWinningPrize() {
    final random = math.Random();
    final randomValue = random.nextInt(100) + 1; // 1-100

    int cumulativeProbability = 0;
    for (var segment in prizeSegments) {
      cumulativeProbability += segment['probability'] as int;
      if (randomValue <= cumulativeProbability) {
        return segment;
      }
    }

    // Fallback (should not reach here)
    return prizeSegments.last;
  }

  double getResponsiveSize(BuildContext context, double baseSize) {
    double screenWidth = MediaQuery.of(context).size.width;
    // 375 = base width (like iPhone X)
    return baseSize * (screenWidth / 375);
  }

  Future<void> _spinWheel() async {
    if (isSpinning || userId == null) return;

    // Check if it's weekend
    if (!isWeekend) {
      Get.snackbar(
        'Not Available',
        'Lucky Draw is only available on weekends ( Sunday).',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
        duration: Duration(seconds: 3),
      );
      return;
    }

    // Check daily spin limit

    if (userTokens < 30) {
      Get.snackbar(
        'Insufficient Tokens',
        'You need 30 J coins to play Lucky Draw.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    setState(() {
      isSpinning = true;
      showResult = false;
    });

    try {
      // Deduct tokens from Firebase first
      await _firestore.collection('users').doc(userId).update({
        'tokens': FieldValue.increment(-30),
      });

      // Update local state
      setState(() {
        userTokens -= 30;
      });

      // Select winning prize
      final selectedPrize = _selectWinningPrize();
      final segmentIndex = prizeSegments.indexOf(selectedPrize);
      final segmentAngle = (2 * math.pi) / prizeSegments.length;
      final targetAngle = (segmentIndex * segmentAngle) + (segmentAngle / 2);

      // Add multiple full rotations plus target angle
      final fullRotations = 5 + math.Random().nextDouble() * 3; // 5-8 rotations
      final finalAngle = (fullRotations * 2 * math.pi) + targetAngle;

      // Start wheel animation
      _wheelController.reset();
      final normalizedAngle = (finalAngle % (2 * math.pi)) / (2 * math.pi);
      await _wheelController.animateTo(
        normalizedAngle,
        curve: Curves.easeOut,
        duration: Duration(seconds: 4),
      );

      // Show result after a small delay
      await Future.delayed(Duration(milliseconds: 500));

      setState(() {
        winningPrize = selectedPrize['title'];
        showResult = true;
        isSpinning = false;
      });

      // Save result to Firebase
      await _saveDrawResult(selectedPrize);

      // Show result dialog
      _showResultDialog(selectedPrize);
    } catch (e) {
      setState(() {
        isSpinning = false;
        // Refund tokens if there was an error
        userTokens += 30;
      });

      Get.snackbar(
        'Error',
        'Something went wrong. Your J Coins have been refunded.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Future<void> _saveDrawResult(Map<String, dynamic> prize) async {
    if (userId == null) return;

    // Always save the draw result first
    DocumentReference drawResultRef = await _firestore
        .collection('luckyDrawResults')
        .add({
          'userId': userId,
          'prize': prize['title'],
          'subtitle': prize['subtitle'],
          'timestamp': FieldValue.serverTimestamp(),
          'tokensUsed': 10,
          'status': 'pending', // All prizes start as pending
          'adminReviewed': false,
          'needsApproval': true, // All prizes need approval now
          'prizeType': prize['title'] == 'Better Luck'
              ? 'consolation'
              : prize['title'] == '50 Points'
              ? 'points'
              : 'cash',
        });

    // No rewards are automatically added to user account
    // All rewards (including points) need admin approval first

    // Create a notification for admin for all prizes except "Better Luck"
    if (prize['title'] != 'Better Luck') {
      await _firestore.collection('adminNotifications').add({
        'type': 'lucky_draw_prize',
        'userId': userId,
        'drawResultId': drawResultRef.id,
        'prize': prize['title'],
        'subtitle': prize['subtitle'],
        'prizeType': prize['title'] == '50 Points' ? 'points' : 'cash',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending_review',
      });
    }
  }

  void _showResultDialog(Map<String, dynamic> prize) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
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
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: prize['color'].withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(prize['icon'], size: 40, color: Colors.white),
                ),
                SizedBox(height: 20),
                Text(
                  prize['title'] == 'Better Luck'
                      ? 'Better Luck Next Time!'
                      : 'Congratulations!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  prize['title'] == 'Better Luck'
                      ? 'Don\'t give up! Try again.'
                      : prize['title'] == '50 Points'
                      ? 'You earned 50 Points!'
                      : 'You won ${prize['title']}!',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10),
                Text(
                  prize['subtitle'],
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                if (prize['title'] != 'Better Luck')
                  Column(
                    children: [
                      SizedBox(height: 15),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.schedule,
                              color: Colors.orange,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Your prize is pending admin approval. Check My Rewards for status!',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        Get.back(); // Go back to home
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    if (prize['title'] != 'Better Luck')
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          // Navigate to My Rewards page
                          Get.toNamed('/myRewards');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                        child: Text(
                          'My Rewards',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _wheelController.dispose();
    _pulseController.dispose();
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
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildHeader(),
                        SizedBox(height: 30),
                        _buildUserTokensCard(),
                        SizedBox(height: 20),
                        _buildAvailabilityCard(),
                        SizedBox(height: 30),
                        _buildLuckyWheel(),
                        SizedBox(height: 30),
                        _buildSpinButton(),
                        SizedBox(height: 20),
                        _buildPrizeList(),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => Get.back(),
              icon: Icon(Icons.arrow_back, color: Colors.white, size: 24),
            ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
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
                    child: Icon(Icons.casino, size: 40, color: Colors.white),
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Lucky Draw',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Spin the Wheel & Win Big!',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 48),
          ],
        ),
      ],
    );
  }

  Widget _buildUserTokensCard() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.toll, color: Colors.green, size: 24),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your JCoins',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$userTokens Tokens Available',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$userTokens',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityCard() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isWeekend
            ? Colors.green.withOpacity(0.2)
            : Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isWeekend
              ? Colors.green.withOpacity(0.5)
              : Colors.red.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isWeekend
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isWeekend ? Icons.check_circle : Icons.schedule,
              color: isWeekend ? Colors.green : Colors.red,
              size: 24,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWeekend ? 'Available Now!' : 'Sunday Only',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  isWeekend ? '' : 'Come back on Sunday',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLuckyWheel() {
    return Container(
      width: 300,
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spinning Wheel
          AnimatedBuilder(
            animation: _wheelController,
            builder: (context, child) {
              return Transform.rotate(
                angle: _wheelAnimation.value * 8 * math.pi,
                child: Container(
                  width: 280,
                  height: 280,
                  child: CustomPaint(
                    painter: WheelPainter(prizeSegments),
                    size: Size(280, 280),
                  ),
                ),
              );
            },
          ),
          // Center Button
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
            ),
            child: Icon(Icons.play_arrow, size: 30, color: Color(0xFF667eea)),
          ),
          // Pointer
          Positioned(
            top: 10,
            child: Container(
              width: 0,
              height: 0,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(width: 15, color: Colors.transparent),
                  right: BorderSide(width: 15, color: Colors.transparent),
                  bottom: BorderSide(width: 25, color: Colors.red),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpinButton() {
    bool canSpin = isWeekend && userTokens >= 30 && !isSpinning;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Transform.scale(
          scale: canSpin ? _pulseAnimation.value : 1.0,
          child: InkWell(
            onTap: canSpin ? _spinWheel : null,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: double.infinity,
              height: 55,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: canSpin
                      ? [Color(0xFF667eea), Color(0xFF764ba2)]
                      : [Colors.grey, Colors.grey.shade600],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                isSpinning
                    ? 'Spinning...'
                    : !isWeekend
                    ? 'Sunday Only'
                    : userTokens < 30
                    ? 'Need 30 J Coins'
                    : 'Spin (30 J Coins)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPrizeList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prizes & Odds',
          style: TextStyle(
            color: Colors.white,
            fontSize: getResponsiveSize(context, 20), // ✅ responsive
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 15),
        ...prizeSegments.map((segment) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 5),
            padding: EdgeInsets.symmetric(
              horizontal: getResponsiveSize(context, 15), // ✅ responsive
              vertical: getResponsiveSize(context, 10),
            ),
            decoration: BoxDecoration(
              color: segment['color'].withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  segment['icon'],
                  color: Colors.white,
                  size: getResponsiveSize(context, 28),
                ), // ✅
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment['title'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: getResponsiveSize(context, 16), // ✅
                        ),
                      ),
                      Text(
                        segment['subtitle'],
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: getResponsiveSize(context, 12), // ✅
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${segment['probability']}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: getResponsiveSize(context, 14), // ✅
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildPrizeListe() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prizes & Odds',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 15),
        ...prizeSegments.map((segment) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 5),
            padding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: segment['color'].withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(segment['icon'], color: Colors.white, size: 28),
                SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        segment['title'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        segment['subtitle'],
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${segment['probability']}%',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
}

class WheelPainter extends CustomPainter {
  final List<Map<String, dynamic>> segments;
  WheelPainter(this.segments);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    final sweepAngle = 2 * math.pi / segments.length;
    double startAngle = -math.pi / 2;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    for (var segment in segments) {
      paint.color = segment['color'];
      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);

      final textSpan = TextSpan(
        text: segment['title'],
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.03, // ✅ responsive: 5% of wheel width
          fontWeight: FontWeight.bold,
        ),
      );

      textPainter.text = textSpan;
      textPainter.layout();

      final angle = startAngle + sweepAngle / 2;
      final textRadius = radius * 0.7;
      final offset = Offset(
        center.dx + textRadius * math.cos(angle) - textPainter.width / 2,
        center.dy + textRadius * math.sin(angle) - textPainter.height / 2,
      );

      textPainter.paint(canvas, offset);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
