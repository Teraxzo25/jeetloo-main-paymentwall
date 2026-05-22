import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unity_ads_plugin/unity_ads_plugin.dart';
import 'package:jeetloo/Candle_System/candle_predciation.dart';
import 'package:jeetloo/Screens/payment.dart';
import 'package:jeetloo/Screens/admin_panel.dart';
import 'package:jeetloo/authentication/login.dart';
import 'package:jeetloo/Screens/gurrantedgift.dart';
import 'package:jeetloo/Screens/luckydraw.dart';
import 'package:jeetloo/Screens/myreward.dart';
import 'package:jeetloo/quizsetup/screens/quiz_controller.dart';
import 'package:jeetloo/quizsetup/screens/quiz_screen.dart';
import 'package:jeetloo/reward_ads/bannerads.dart';
import 'package:jeetloo/reward_ads/flutter_rewarded_ads_getx.dart';
import 'package:shared_preferences/shared_preferences.dart';

class JeetLooHomeScreen extends StatefulWidget {
  @override
  _JeetLooHomeScreenState createState() => _JeetLooHomeScreenState();
}

class _JeetLooHomeScreenState extends State<JeetLooHomeScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _pulseAnimation;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? userId;
  final RewardedAdsController controller = Get.put(RewardedAdsController());
  final QuizController quizController = Get.put(QuizController());

  int userPoints = 0;
  int userTokens = 0;
  int dailyLoginStreak = 1;
  bool hasClaimedDailyBonus = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _fetchUserData();

    // Set callback when rewarded ad completes
    controller.setOnRewardEarnedCallback(_onRewardEarned);
  }

  // Function to fetch latest balance from Firestore
  Future<void> _refreshBalance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          setState(() {
            userPoints = doc['points'] ?? 0;
            userTokens = doc['tokens'] ?? 0;
          });
        }
      } catch (e) {
        print('Error refreshing balance: $e');
      }
    }
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _slideAnimation = Tween<double>(begin: 50.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _animationController.forward();
    _pulseController.repeat(reverse: true);
  }

  // Future<void> _fetchUserData() async {
  //   userId = _auth.currentUser?.uid;
  //   if (userId == null) return;

  //   final doc = await _firestore.collection('users').doc(userId).get();
  //   if (doc.exists) {
  //     final data = doc.data()!;
  //     setState(() {
  //       userPoints = data['points'] ?? 0;
  //       userTokens = data['tokens'] ?? 0;
  //       dailyLoginStreak = data['dailyLoginStreak'] ?? 1;
  //       hasClaimedDailyBonus = data['hasClaimedDailyBonus'] ?? false;
  //     });
  //   } else {
  //     await _firestore.collection('users').doc(userId).set({
  //       'points': userPoints,
  //       'tokens': userTokens,
  //       'dailyLoginStreak': dailyLoginStreak,
  //       'hasClaimedDailyBonus': hasClaimedDailyBonus,
  //     });
  //   }
  // }
  Future<void> _fetchUserData() async {
    userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data()!;

      DateTime? lastClaimDate;
      if (data['lastClaimDate'] != null) {
        lastClaimDate = (data['lastClaimDate'] as Timestamp).toDate();
      }

      DateTime today = DateTime.now();

      // check if last claim was today
      bool claimedToday =
          lastClaimDate != null &&
          lastClaimDate.year == today.year &&
          lastClaimDate.month == today.month &&
          lastClaimDate.day == today.day;

      setState(() {
        userPoints = (data['points'] ?? 0).clamp(0, double.infinity).toInt();
        userTokens = (data['tokens'] ?? 0).clamp(0, double.infinity).toInt();
        dailyLoginStreak = data['dailyLoginStreak'] ?? 1;
        hasClaimedDailyBonus = claimedToday;
      });
    } else {
      await _firestore.collection('users').doc(userId).set({
        'points': userPoints,
        'tokens': userTokens,
        'dailyLoginStreak': dailyLoginStreak,
        'hasClaimedDailyBonus': false,
        'lastClaimDate': null,
      });
    }
  }

  Future<void> _claimDailyBonus() async {
    if (hasClaimedDailyBonus || userId == null) return;

    int bonus = _getDailyBonusPoints();
    DateTime today = DateTime.now();

    setState(() {
      hasClaimedDailyBonus = true;
      userPoints += bonus;
      dailyLoginStreak += 1;
    });

    await _firestore.collection('users').doc(userId).update({
      'points': userPoints,
      'dailyLoginStreak': dailyLoginStreak,
      'hasClaimedDailyBonus': true,
      'lastClaimDate': today,
    });
  }

  /// New callback: When user earns reward from ad
  Future<void> _onRewardEarned(int rewardAmount) async {
    if (userId == null) return;

    // Update points in Firestore atomically
    await _firestore.collection('users').doc(userId).update({
      'points': FieldValue.increment(rewardAmount),
    });

    // Update local UI state to reflect new points
    setState(() {
      userPoints += rewardAmount;
    });
    Get.closeAllSnackbars(); // 👈 closes any old snackbars

    Get.snackbar(
      'Reward Earned!',
      'You earned $rewardAmount points!',
      backgroundColor: Colors.green,
      colorText: Colors.white,
      snackPosition: SnackPosition.BOTTOM,
      duration: Duration(seconds: 3),
    );
  }

  bool _isConverting = false; // add this at the top of your State class

  /// Convert points to tokens: 100 points = 1 token
  Future<void> _convertPointsToTokens() async {
    if (_isConverting) return; // prevent double-tap spam
    _isConverting = true; // lock

    if (userId == null) {
      _isConverting = false;
      return;
    }

    if (userPoints < 100) {
      Get.closeAllSnackbars(); // 👈 closes any old snackbars

      Get.snackbar(
        'Not Enough Points',
        'You need at least 100 points to convert.',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
      _isConverting = false;
      return;
    }

    int tokensToAdd = userPoints ~/ 100;
    int pointsLeft = userPoints % 100;

    try {
      await _firestore.collection('users').doc(userId).update({
        'points': pointsLeft,
        'tokens': FieldValue.increment(tokensToAdd),
      });

      setState(() {
        userPoints = pointsLeft;
        userTokens += tokensToAdd;
      });
      Get.closeAllSnackbars(); // 👈 closes any old snackbars

      Get.snackbar(
        'Conversion Successful',
        'Converted ${tokensToAdd * 100} points into $tokensToAdd tokens!',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      Get.closeAllSnackbars(); // 👈 closes any old snackbars

      Get.snackbar(
        'Error',
        'Something went wrong. Please try again.',
        backgroundColor: Colors.red,
        colorText: Colors.white,
        snackPosition: SnackPosition.BOTTOM,
      );
    }

    _isConverting = false; // unlock
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // All UI code remains unchanged except we add onTap to _buildConvertColumn

  Widget _buildConvertColumn() {
    return Expanded(
      child: GestureDetector(
        onTap: () => _convertPointsToTokens(), // <-- Updated here
        child: Column(
          children: [
            Icon(Icons.swap_horiz, color: Colors.orange, size: 32),
            SizedBox(height: 8),
            Text(
              'Convert',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              '100 pts = 1 Jeet',
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // All other UI widgets unchanged...

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshBalance,
        child: Container(
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
                          Container(
                            height: 100,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                              ),
                            ),
                            child: SafeArea(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 15,
                                ),
                                child: Row(
                                  children: [
                                    // Left Side - Welcome with animated icon
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.2,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.waving_hand,
                                              color: Colors.amber,
                                              size: 24,
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                "Welcome to",
                                                style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.8),
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w300,
                                                ),
                                              ),
                                              Text(
                                                "JeetLOo",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Right Side - Notification & Profile Menu
                                    Row(
                                      children: [
                                        // Notification Bell
                                        Container(
                                          margin: EdgeInsets.only(right: 12),
                                          padding: EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.15,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Stack(
                                            children: [
                                              Icon(
                                                Icons.notifications_outlined,
                                                color: Colors.white,
                                                size: 22,
                                              ),
                                              Positioned(
                                                right: 0,
                                                top: 0,
                                                child: Container(
                                                  width: 8,
                                                  height: 8,
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    shape: BoxShape.circle,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Profile Menu
                                        PopupMenuButton<String>(
                                          onSelected: (String value) {
                                            switch (value) {
                                              case 'profile':
                                                Get.closeAllSnackbars(); // 👈 closes any old snackbars

                                                Get.snackbar(
                                                  'Profile',
                                                  'Profile clicked',
                                                );
                                                break;
                                              case 'settings':
                                                Get.closeAllSnackbars(); // 👈 closes any old snackbars

                                                Get.snackbar(
                                                  'Settings',
                                                  'Settings clicked',
                                                );
                                                break;
                                              case 'help':
                                                Get.closeAllSnackbars(); // 👈 closes any old snackbars

                                                Get.snackbar(
                                                  'Help',
                                                  'Help clicked',
                                                );
                                                break;
                                              case 'logout':
                                                FirebaseAuth.instance.signOut();
                                                Get.offAllNamed('/login');
                                                break;
                                            }
                                          },
                                          itemBuilder: (BuildContext context) => [
                                            // PopupMenuItem<String>(
                                            //   value: 'profile',
                                            //   child: Row(
                                            //     children: [
                                            //       Icon(
                                            //         Icons.person,
                                            //         color: Color(0xFF667eea),
                                            //       ),
                                            //       SizedBox(width: 10),
                                            //       Text('Profile'),
                                            //     ],
                                            //   ),
                                            // ),
                                            // PopupMenuItem<String>(
                                            //   value: 'settings',
                                            //   child: Row(
                                            //     children: [
                                            //       Icon(
                                            //         Icons.settings,
                                            //         color: Color(0xFF667eea),
                                            //       ),
                                            //       SizedBox(width: 10),
                                            //       Text('Settings'),
                                            //     ],
                                            //   ),
                                            // ),
                                            // PopupMenuItem<String>(
                                            //   value: 'help',
                                            //   child: Row(
                                            //     children: [
                                            //       Icon(
                                            //         Icons.help,
                                            //         color: Color(0xFF667eea),
                                            //       ),
                                            //       SizedBox(width: 10),
                                            //       Text('Help & Support'),
                                            //     ],
                                            //   ),
                                            // ),
                                            // PopupMenuDivider(),
                                            PopupMenuItem<String>(
                                              value: 'logout',
                                              child: Row(
                                                children: [
                                                  GestureDetector(
                                                    onTap: () async {
                                                      // On logout clear SharedPreferences and Firebase auth
                                                      await FirebaseAuth
                                                          .instance
                                                          .signOut();
                                                      final prefs =
                                                          await SharedPreferences.getInstance();
                                                      await prefs.clear();
                                                      Get.offAll(
                                                        () => LoginScreen(),
                                                      );
                                                    },
                                                    child: Icon(
                                                      Icons.logout,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Logout',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                          child: Container(
                                            padding: EdgeInsets.all(4),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withOpacity(
                                                0.15,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: Colors.white.withOpacity(
                                                  0.3,
                                                ),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                CircleAvatar(
                                                  radius: 16,
                                                  backgroundColor: Colors.white,
                                                  child: Icon(
                                                    Icons.person,
                                                    color: Color(0xFF667eea),
                                                    size: 18,
                                                  ),
                                                ),
                                                SizedBox(width: 6),
                                                Icon(
                                                  Icons.keyboard_arrow_down,
                                                  color: Colors.white,
                                                  size: 18,
                                                ),
                                                SizedBox(width: 4),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 10),

                          _buildHeader(),
                          SizedBox(height: 10),
                          _buildPointsTokensCard(),
                          SizedBox(height: 20),
                          _buildDailyLoginCard(),
                          SizedBox(height: 30),
                          _buildMainActionButtons(),
                          SizedBox(height: 30),
                          _buildQuickActionsRow(),
                          SizedBox(height: 30),
                          _buildRecentWinnersSection(),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: Visibility(
        visible: true, // Set to false to hide ads
        child: UnityBannerAd(
          placementId: AdmobHelper.bannerPlacementId,
          onLoad: (placementId) => print('Banner loaded: $placementId'),
          onClick: (placementId) => print('Banner clicked: $placementId'),
          onFailed: (placementId, error, message) =>
              print('Banner failed: $message'),
        ),
      ),
      // sizedBox(height: 50),
    );
  }

  // The rest of UI code remains unchanged as you provided
  Widget _buildHeader() {
    return Column(
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
          child: Icon(Icons.emoji_events, size: 40, color: Colors.white),
        ),
        SizedBox(height: 10),
        Text(
          'JeetLOo',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 5),
        Text(
          'Earn Smart. Earn Fast.',
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w300,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildPointsTokensCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          _buildInfoColumn(Icons.stars, 'Points', userPoints, Colors.amber),
          _divider(),
          _buildInfoColumn(Icons.toll, 'Jeet', userTokens, Colors.green),
          _divider(),
          _buildConvertColumn(),
        ],
      ),
    );
  }

  Widget _buildInfoColumn(IconData icon, String label, int value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          SizedBox(height: 8),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 50,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildDailyLoginCard() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.card_giftcard, color: Colors.orange, size: 24),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Login Bonus',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Day $dailyLoginStreak - Get ${_getDailyBonusPoints()} points',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: hasClaimedDailyBonus ? null : _claimDailyBonus,
            style: ElevatedButton.styleFrom(
              backgroundColor: hasClaimedDailyBonus
                  ? Colors.grey
                  : Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              hasClaimedDailyBonus ? 'Claimed' : 'Claim',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainActionButtons() {
    return Column(
      children: [
        Obx(() {
          final isReady = controller.isAdReady.value;
          final isLoading = controller.isAdLoading.value;

          return Column(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: InkWell(
                      onTap: isReady ? controller.showAd : null,
                      borderRadius: BorderRadius.circular(30),
                      child: Container(
                        width: double.infinity,
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: isReady
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF11998e),
                                    Color(0xFF38ef7d),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [Colors.grey, Colors.grey],
                                ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: isLoading
                              ? const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      'Loading...',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    Icon(
                                      Icons.play_circle_filled,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Watch Ads & Earn Points',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 20),

              // Ad Status Text
              Text(
                isLoading
                    ? 'Loading advertisement...'
                    : isReady
                    ? 'Advertisement ready!'
                    : 'Advertisement not available',
                style: TextStyle(
                  fontSize: 14,
                  color: isReady ? Colors.green : Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 15),
            ],
          );
        }),

        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CandlePredictionScreen()),
            );
          },
          borderRadius: BorderRadius.circular(30),
          child: Container(
            width: double.infinity,
            height: 45,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  Color.fromARGB(255, 241, 6, 42),
                  Color.fromARGB(255, 185, 206, 193),
                ],
              ),
              borderRadius: BorderRadius.circular(30),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.play_circle_fill, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text(
                    'Candle Prediction Game',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: 20),

        Obx(() {
          final isAvailable = quizController.canPlayQuiz.value;

          return InkWell(
            onTap: isAvailable
                ? () async {
                    await quizController
                        .markQuizPlayed(); // 🔹 Lock immediately
                    Get.to(QuizScreen())?.then((_) {
                      // Optional: check again when returning
                      quizController.checkQuizAvailability();
                    });
                  }
                : null,
            borderRadius: BorderRadius.circular(25),
            child: Container(
              width: double.infinity,
              height: 50,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isAvailable
                      ? [Color(0xFF667eea), Color(0xFF764ba2)]
                      : [Colors.grey.shade500, Colors.grey.shade700],
                ),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isAvailable ? Icons.quiz : Icons.lock,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      isAvailable
                          ? 'Play Quiz & Earn Points'
                          : 'Unlock after 24 hours',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildQuickActionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildQuickActionButton(
          Icons.casino,
          'Lucky Draw',
          '10 Jeets',
          Colors.purple,
          LuckyDrawSystem(),
        ),
        _buildQuickActionButton(
          Icons.payment, // New payment icon
          'Payment', // New payment label
          'Deposit/Withdraw', // New subtitle
          Colors.blue, // Color for payment
          PaymentScreen(), // Navigate to PaymentScreen
        ),
        // Admin panel — only visible to admin
        if (FirebaseAuth.instance.currentUser?.email?.toLowerCase() ==
            'jeetlooapp@gmail.com')
          _buildQuickActionButton(
            Icons.admin_panel_settings,
            'Admin',
            'Manage',
            Colors.red,
            AdminPanel(),
          ),
        // _buildQuickActionButton(
        //   Icons.card_giftcard,
        //   'Guaranteed',
        //   '20 Jeets',
        //   Colors.pink,
        //   GuaranteedGiftsScreen(),
        // ),
        _buildQuickActionButton(
          Icons.emoji_events,
          'My Rewards',
          'Withdraw',
          Colors.orange,
          MyRewardsPage(),
        ),
      ],
    );
  }

  //
  Widget _buildQuickActionButton(
    IconData icon,
    String label,
    String subtitle,
    Color color,
    Widget route,
  ) {
    return GestureDetector(
      // onTap: () => Get.to(LuckyDrawSystem()),
      onTap: () => Get.to(route),

      // () => print('$label tapped'), // Placeholder for actual navigation
      // ),
      // () => print('$label tapped'),
      child: Container(
        width: 100,
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentWinnersSection() {
    return Container(
      padding: EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Winners',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                'View All',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.8),
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          _buildWinnerItem('Ahmad123', 'J coin 5,000', '2 days ago'),
          _buildWinnerItem('Fatima456', 'J coin 2,500', '4 days ago'),
          _buildWinnerItem('Hassan789', 'J coin 1,000', '6 days ago'),
        ],
      ),
    );
  }

  Widget _buildWinnerItem(String name, String prize, String time) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.emoji_events, color: Colors.amber, size: 16),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            prize,
            style: TextStyle(
              color: Colors.green,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 8),
          Text(
            time,
            style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  int _getDailyBonusPoints() {
    switch (dailyLoginStreak) {
      case 1:
        return 10;
      case 2:
        return 15;
      case 3:
        return 20;
      case 4:
        return 25;
      case 5:
        return 30;
      case 6:
        return 35;
      case 7:
        return 50;
      default:
        return 10;
    }
  }
}
