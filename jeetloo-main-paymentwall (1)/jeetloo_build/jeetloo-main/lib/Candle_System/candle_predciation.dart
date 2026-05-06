import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:math' as math;

class GameController extends GetxController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? userId;

  // User balances - synced with Firebase
  var quizAdPoints = 0.obs;
  var purchasedTokens = 0.obs;
  var withdrawablePoints = 0.obs;
  var jCoins = 0.obs; // single balance

  // Game state
  var currentPrediction = 1.065.obs;
  var isGameActive = false.obs;
  var countdown = 30.obs;
  var selectedOption = ''.obs; // 'red' or 'green'
  var predictionAmount = 100.obs;

  // Chart data for candlestick visualization
  var chartData = <CandleData>[].obs;
  var currentPrice = 1.065.obs;

  // Timer
  Timer? gameTimer;
  Timer? countdownTimer;

  // Lucky Draw
  var luckyDrawEntries = 0.obs;
  var isDrawing = false.obs;

  @override
  void onInit() {
    super.onInit();

    _initializeUser();
    _generateInitialChartData();
    startNewRound();
  }

  @override
  void onClose() {
    gameTimer?.cancel();
    countdownTimer?.cancel();
    Get.closeAllSnackbars();
    super.onClose();
  }

  void restartTimers() {
    // Cancel any existing timers
    gameTimer?.cancel();
    countdownTimer?.cancel();

    // Start a fresh round
    startNewRound();
  }

  Future<void> _initializeUser() async {
    userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final doc = await _firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data()!;
      quizAdPoints.value = data['points'] ?? 0;
      purchasedTokens.value = data['tokens'] ?? 0;
      withdrawablePoints.value = data['withdrawablePoints'] ?? 0;
      luckyDrawEntries.value = data['luckyDrawEntries'] ?? 0;
    } else {
      await _firestore.collection('users').doc(userId).set({
        'points': 0,
        'tokens': 0,
        'withdrawablePoints': 0,
        'luckyDrawEntries': 0,
      });
    }
  }

  void _generateInitialChartData() {
    Random random = Random();
    double basePrice = 1.065;

    for (int i = 0; i < 10; i++) {
      double high = basePrice + (random.nextDouble() * 0.01);
      double low = basePrice - (random.nextDouble() * 0.01);
      bool isGreen = random.nextBool();

      chartData.add(
        CandleData(
          open: basePrice,
          close: isGreen ? high - 0.002 : low + 0.002,
          high: high,
          low: low,
          isGreen: isGreen,
        ),
      );

      basePrice = chartData.last.close;
    }
    currentPrice.value = basePrice;
  }

  void startNewRound() {
    isGameActive.value = true;
    countdown.value = 15;
    selectedOption.value = '';

    countdownTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (countdown.value > 0) {
        countdown.value--;

        // Update chart in real-time
        if (countdown.value % 3 == 0) {
          _updateChart();
        }
      } else {
        timer.cancel();
        processRound();
      }
    });
  }

  void _updateChart() {
    Random random = Random();
    double lastPrice = currentPrice.value;
    double volatility = 0.005;

    double change = (random.nextDouble() - 0.5) * volatility;
    double newPrice = (lastPrice + change).clamp(1.040, 1.090);

    double high = max(lastPrice, newPrice) + (random.nextDouble() * 0.003);
    double low = min(lastPrice, newPrice) - (random.nextDouble() * 0.003);

    chartData.add(
      CandleData(
        open: lastPrice,
        close: newPrice,
        high: high,
        low: low,
        isGreen: newPrice > lastPrice,
      ),
    );

    // Keep only last 15 candles
    if (chartData.length > 15) {
      chartData.removeAt(0);
    }

    currentPrice.value = newPrice;
    currentPrediction.value = newPrice;
  }

  Future<void> processRound() async {
    if (selectedOption.value.isEmpty) {
      isGameActive.value = false;
      Get.closeAllSnackbars();
      Get.snackbar(
        'No Prediction',
        'You didn\'t make a prediction this round!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      Future.delayed(const Duration(seconds: 2), () => startNewRound());
      return;
    }

    // Generate final candle
    Random random = Random();
    double finalChange = (random.nextDouble() - 0.5) * 0.01;
    double finalPrice = (currentPrice.value + finalChange).clamp(1.040, 1.090);

    bool isGreen = finalPrice > currentPrice.value;
    String result = isGreen ? 'green' : 'red';

    chartData.add(
      CandleData(
        open: currentPrice.value,
        close: finalPrice,
        high: max(currentPrice.value, finalPrice) + 0.002,
        low: min(currentPrice.value, finalPrice) - 0.002,
        isGreen: isGreen,
      ),
    );

    currentPrice.value = finalPrice;
    currentPrediction.value = finalPrice;

    // Settlement logic
    final bool userWon = selectedOption.value == result;
    final int bet = predictionAmount.value;
    final int profit = (bet * 9) ~/ 10; // 90% profit

    if (userId == null) {
      Get.closeAllSnackbars();
      Get.snackbar(
        'Error',
        'User not logged in',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      isGameActive.value = false;
      Future.delayed(const Duration(seconds: 2), () => startNewRound());
      return;
    }

    final DocumentReference userRef = _firestore
        .collection('users')
        .doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) throw Exception('User document missing');

        final data = snapshot.data() as Map<String, dynamic>;
        final int currentTokens = ((data['tokens'] ?? 0) as num).toInt();

        // Check if user has sufficient balance
        if (currentTokens < bet) {
          throw Exception('Insufficient balance');
        }

        if (userWon) {
          // Winner: Remove bet amount, add back bet + profit
          // Net effect: user gains profit amount
          final int newBalance = currentTokens - bet + bet + profit;
          transaction.update(userRef, {'tokens': newBalance});
        } else {
          // Loser: Just deduct the bet
          transaction.update(userRef, {'tokens': currentTokens - bet});
        }
      });

      // Sync local state
      final fresh = await userRef.get();
      final freshData = fresh.data() as Map<String, dynamic>;
      purchasedTokens.value = ((freshData['tokens'] ?? 0) as num).toInt();

      Get.closeAllSnackbars();
      if (userWon) {
        Get.snackbar(
          '🎉 Prediction Correct!',
          'You won ${bet + profit} tokens! (${bet} returned + ${profit} profit)',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          '❌ Prediction Incorrect',
          'You lost $bet tokens. Better luck next time!',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.closeAllSnackbars();
      Get.snackbar(
        'Error',
        'Failed to settle round: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }

    isGameActive.value = false;
    Future.delayed(const Duration(seconds: 3), () => startNewRound());
  }

  Future<void> er() async {
    if (selectedOption.value.isEmpty) {
      isGameActive.value = false;
      Get.closeAllSnackbars();
      Get.snackbar(
        'No Prediction',
        'You didn\'t make a prediction this round!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      Future.delayed(const Duration(seconds: 2), () => startNewRound());
      return;
    }

    // --- generate final candle (same logic) ---
    Random random = Random();
    double finalChange = (random.nextDouble() - 0.5) * 0.01;
    double finalPrice = (currentPrice.value + finalChange).clamp(1.040, 1.090);

    bool isGreen = finalPrice > currentPrice.value;
    String result = isGreen ? 'green' : 'red';

    chartData.add(
      CandleData(
        open: currentPrice.value,
        close: finalPrice,
        high: max(currentPrice.value, finalPrice) + 0.002,
        low: min(currentPrice.value, finalPrice) - 0.002,
        isGreen: isGreen,
      ),
    );

    currentPrice.value = finalPrice;
    currentPrediction.value = finalPrice;

    // --- settlement logic ---
    final bool userWon = selectedOption.value == result;
    final int bet = predictionAmount.value;
    final int profit = (bet * 9) ~/ 10; // 90% profit
    final int reward = bet + profit; // stake + profit

    if (userId == null) {
      Get.closeAllSnackbars();
      Get.snackbar(
        'Error',
        'User not logged in',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      isGameActive.value = false;
      Future.delayed(const Duration(seconds: 2), () => startNewRound());
      return;
    }

    final DocumentReference userRef = _firestore
        .collection('users')
        .doc(userId);

    try {
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) throw Exception('User document missing');

        final data = snapshot.data() as Map<String, dynamic>;
        final int currentTokens = ((data['tokens'] ?? 0) as num).toInt();

        if (currentTokens < bet) {
          Get.snackbar("Insufficient Balance", "Not enough tokens to play.");
          return;
        }

        // 🔹 Step 1: Deduct bet
        transaction.update(userRef, {'tokens': currentTokens - bet});

        // 🔹 Step 2: If win → add reward (stake + profit)
        if (userWon) {
          transaction.update(userRef, {'tokens': FieldValue.increment(reward)});
        }
      });

      // 🔹 Sync local state
      final fresh = await userRef.get();
      final freshData = fresh.data() as Map<String, dynamic>;
      purchasedTokens.value = ((freshData['tokens'] ?? 0) as num).toInt();

      Get.closeAllSnackbars();
      if (userWon) {
        Get.snackbar(
          '🎉 Prediction Correct!',
          'You won $reward tokens!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          '❌ Prediction Incorrect',
          'Better luck next time!',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.closeAllSnackbars();
      Get.snackbar(
        'Error',
        'Failed to settle round: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }

    isGameActive.value = false;
    Future.delayed(const Duration(seconds: 3), () => startNewRound());
  }

  Future<void> processdRound() async {
    if (selectedOption.value.isEmpty) {
      isGameActive.value = false;
      Get.closeAllSnackbars();
      Get.snackbar(
        'No Prediction',
        'You didn\'t make a prediction this round!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      Future.delayed(Duration(seconds: 2), () => startNewRound());
      return;
    }

    // --- generate final candle (keeps your existing logic) ---
    Random random = Random();
    double finalChange = (random.nextDouble() - 0.5) * 0.01;
    double finalPrice = (currentPrice.value + finalChange).clamp(1.040, 1.090);

    bool isGreen = finalPrice > currentPrice.value;
    String result = isGreen ? 'green' : 'red';

    // add final candle
    chartData.add(
      CandleData(
        open: currentPrice.value,
        close: finalPrice,
        high: max(currentPrice.value, finalPrice) + 0.002,
        low: min(currentPrice.value, finalPrice) - 0.002,
        isGreen: isGreen,
      ),
    );

    currentPrice.value = finalPrice;
    currentPrediction.value = finalPrice;

    // --- settlement logic ---
    final bool userWon = selectedOption.value == result;
    final int bet = predictionAmount.value;
    final int profit = (bet * 9) ~/ 10; // 90% profit
    final int reward = bet + profit; // stake + profit

    if (userId == null) {
      Get.closeAllSnackbars();
      Get.snackbar(
        'Error',
        'User not logged in',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      isGameActive.value = false;
      Future.delayed(Duration(seconds: 2), () => startNewRound());
      return;
    }

    final DocumentReference userRef = _firestore
        .collection('users')
        .doc(userId);

    try {
      // Atomic transaction: deduct tokens (if still present) and credit withdrawablePoints
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(userRef);
        if (!snapshot.exists) {
          throw Exception('User document missing');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final int currentTokens = ((data['tokens'] ?? 0) as num).toInt();

        if (userWon) {
          // If tokens still exist, deduct them and credit reward.
          // If tokens were already deducted on tap, avoid double-deduct and only credit reward.
          if (currentTokens >= bet) {
            transaction.update(userRef, {
              'tokens': FieldValue.increment(-bet),
              'withdrawablePoints': FieldValue.increment(reward),
            });
          } else {
            transaction.update(userRef, {
              'withdrawablePoints': FieldValue.increment(reward),
            });
          }
        } else {
          // Losing: deduct tokens if still present (if already deducted on tap, nothing to do)
          if (currentTokens >= bet) {
            transaction.update(userRef, {'tokens': FieldValue.increment(-bet)});
          }
        }
      });

      // Re-sync local observables from Firestore for consistency
      final fresh = await userRef.get();
      final freshData = fresh.data() as Map<String, dynamic>;
      purchasedTokens.value = ((freshData['tokens'] ?? 0) as num).toInt();
      withdrawablePoints.value = ((freshData['withdrawablePoints'] ?? 0) as num)
          .toInt();

      Get.closeAllSnackbars();
      if (userWon) {
        Get.snackbar(
          '🎉 Prediction Correct!',
          'You won $reward withdrawable points!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          '❌ Prediction Incorrect',
          'Better luck next time!',
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.closeAllSnackbars();
      Get.snackbar(
        'Error',
        'Failed to settle round: ${e.toString()}',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }

    isGameActive.value = false;
    Future.delayed(Duration(seconds: 3), () => startNewRound());
  }

  void selectOption(String option) {
    if (!isGameActive.value || countdown.value <= 0) return;

    if (purchasedTokens.value < 50) {
      // minimum 50 J Coins
      Get.closeAllSnackbars();
      Get.snackbar(
        'Insufficient Tokens',
        'You need at least 50 J Coins to participate!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (purchasedTokens.value < predictionAmount.value) {
      Get.closeAllSnackbars();
      Get.snackbar(
        'Insufficient Tokens',
        'You don\'t have enough J Coins for this prediction!',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    selectedOption.value = option;
  }

  // In GameController
  void updatePredictionAmount(int amount) {
    final int hardMax = 1000;
    final int maxSelectable = min(purchasedTokens.value, hardMax);
    final int minSelectable = 50;
    // If user has <50 tokens, they can't participate; keep value at 50 but validation will block later.
    predictionAmount.value = amount.clamp(minSelectable, maxSelectable);
  }

  // Convert quiz/ad points to lucky draw entries
  Future<void> convertPointsToEntries(int points) async {
    if (quizAdPoints.value >= points && userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(-points),
        'luckyDrawEntries': FieldValue.increment(points),
      });

      quizAdPoints.value -= points;
      luckyDrawEntries.value += points;
      Get.closeAllSnackbars(); // 👈 closes any old snackbars

      Get.snackbar(
        'Points Converted',
        '$points points converted to lucky draw entries!',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    }
  }

  // Lucky Draw
  Future<void> enterLuckyDraw() async {
    if (luckyDrawEntries.value <= 0) {
      Get.closeAllSnackbars(); // 👈 closes any old snackbars

      Get.snackbar(
        'No Entries',
        'Convert quiz/ad points to get lucky draw entries!',
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
      return;
    }

    isDrawing.value = true;

    Future.delayed(Duration(seconds: 2), () async {
      Random random = Random();
      bool won = random.nextDouble() < 0.3; // 30% chance to win

      if (won) {
        int winAmount = random.nextInt(500) + 100; // Win between 100-600 points

        await _firestore.collection('users').doc(userId).update({
          'withdrawablePoints': FieldValue.increment(winAmount),
          'luckyDrawEntries': FieldValue.increment(-1),
        });

        withdrawablePoints.value += winAmount;
        Get.closeAllSnackbars(); // 👈 closes any old snackbars

        Get.snackbar(
          '🎉 Lucky Draw Winner!',
          'You won $winAmount withdrawable points!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );
      } else {
        await _firestore.collection('users').doc(userId).update({
          'luckyDrawEntries': FieldValue.increment(-1),
        });
        Get.closeAllSnackbars(); // 👈 closes any old snackbars

        Get.snackbar(
          '🎲 Lucky Draw',
          'No luck this time, try again!',
          backgroundColor: Colors.orange,
          colorText: Colors.white,
        );
      }

      luckyDrawEntries.value--;
      isDrawing.value = false;
    });
  }

  // Simulate buying tokens with real money
  Future<void> buyTokens(int amount) async {
    if (userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'tokens': FieldValue.increment(amount),
      });

      purchasedTokens.value += amount;
      Get.closeAllSnackbars(); // 👈 closes any old snackbars

      Get.snackbar(
        'Tokens Purchased',
        '$amount tokens added to your account!',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    }
  }

  // Simulate earning points from quiz/ads
  Future<void> earnQuizAdPoints() async {
    int earned = Random().nextInt(50) + 20;

    if (userId != null) {
      await _firestore.collection('users').doc(userId).update({
        'points': FieldValue.increment(earned),
      });

      quizAdPoints.value += earned;
      Get.closeAllSnackbars(); // 👈 closes any old snackbars

      Get.snackbar(
        'Points Earned',
        'You earned $earned points from quiz/ad!',
        backgroundColor: Colors.blue,
        colorText: Colors.white,
      );
    }
  }
}

class CandleData {
  final double open;
  final double close;
  final double high;
  final double low;
  final bool isGreen;

  CandleData({
    required this.open,
    required this.close,
    required this.high,
    required this.low,
    required this.isGreen,
  });
}

class CandlePredictionScreen extends StatefulWidget {
  @override
  _CandlePredictionScreenState createState() => _CandlePredictionScreenState();
}

class _CandlePredictionScreenState extends State<CandlePredictionScreen>
    with TickerProviderStateMixin {
  final GameController controller = Get.put(GameController());

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);

    // Add this line:
    controller.restartTimers(); // ✅ restart timers on screen open
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // cancel timers + close snackbars
        controller.onClose();
        Get.back(closeOverlays: true);
        return false; // we already handled back
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildHeader(),
                  SizedBox(height: 20),
                  _buildBalanceSection(),
                  SizedBox(height: 20),
                  _buildGameInterface(),
                  SizedBox(height: 20),
                  // _buildActionButtons(),
                  SizedBox(height: 20),
                  // _buildLuckyDrawSection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.trending_up, color: Colors.white, size: 28),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crypto Prediction',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Predict market movements & earn rewards',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showInfoDialog(),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSection() {
    return Obx(
      () => Container(
        padding: EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            // Expanded(
            //   child: _buildBalanceCard(
            //     'Quiz/Ad Points',
            //     controller.quizAdPoints.value.toString(),
            //     Colors.blue,
            //     Icons.quiz,
            //   ),
            // ),
            // _divider(),
            Expanded(
              child: _buildBalanceCard(
                'J Coins',
                max(0, controller.purchasedTokens.value).toString(),
                Colors.orange,
                Icons.toll,
              ),
            ),
            // _divider(),
            // Expanded(
            //   child: _buildBalanceCard(
            //     'Withdrawable',
            //     controller.withdrawablePoints.value.toString(),
            //     Colors.green,
            //     Icons.account_balance_wallet,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          title,
          style: TextStyle(fontSize: 10, color: Colors.white.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 40,
      color: Colors.white.withOpacity(0.3),
    );
  }

  Widget _buildGameInterface() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color(0xFF1e1e2e),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Timer and Current Price
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PREDICT',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Obx(
                () => Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: controller.countdown.value <= 10
                        ? Colors.red
                        : Color(0xFF667eea),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Time : 00:${controller.countdown.value.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Current Price Display
          Obx(
            () => Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  Text(
                    'Current Price',
                    style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    controller.currentPrediction.value.toStringAsFixed(3),
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20),

          // Candlestick Chart
          _buildCandlestickChart(),
          SizedBox(height: 20),

          // Prediction Amount Selector
          // _buildPredictionAmountSelector(),
          _buildMeterSelector(),
          SizedBox(height: 20),

          // Prediction Buttons
          _buildPredictionButtons(),
          SizedBox(height: 15),

          // Expected Reward
          Obx(
            () => Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Expected Reward:',
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    '${controller.predictionAmount.value + (controller.predictionAmount.value * 0.9).round()} Points',

                    // '${(controller.predictionAmount.value * 0.9).round()} Points',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandlestickChart() {
    return Container(
      height: 200,
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Obx(() {
        if (controller.chartData.isEmpty) {
          return Center(child: CircularProgressIndicator());
        }

        return CustomPaint(
          painter: CandlestickPainter(controller.chartData),
          size: Size.infinite,
        );
      }),
    );
  }

  Widget _buildMeterSelector() {
    return Obx(() {
      final int available = controller.purchasedTokens.value;
      const int hardMax = 1000; // absolute cap
      const int minSelectable = 50; // game's minimum bet
      final int maxSelectable = min(available, hardMax);

      // Check if user has insufficient funds
      final bool hasInsufficientFunds = available < minSelectable;

      // Keep UI value inside valid range - handle insufficient funds case
      final double uiValue = hasInsufficientFunds
          ? minSelectable.toDouble()
          : controller.predictionAmount.value.toDouble().clamp(
              minSelectable.toDouble(),
              maxSelectable.toDouble(),
            );

      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: hasInsufficientFunds
              ? Colors.red.withOpacity(0.1)
              : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasInsufficientFunds
                ? Colors.red.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Responsive size
            final double gaugeSize = constraints.maxWidth.clamp(220.0, 380.0);

            // If insufficient funds, show error state
            if (hasInsufficientFunds) {
              return Column(
                children: [
                  Text(
                    'Insufficient J Coins',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    height: gaugeSize * 0.6, // Smaller error display
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.warning_amber,
                            color: Colors.red,
                            size: 48,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'You have: $available J Coins',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Minimum required: $minSelectable J Coins',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Please buy more tokens to participate',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Normal gauge display when user has sufficient funds
            return Column(
              children: [
                Text(
                  'Select Amount (J Coins)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                SizedBox(height: 8),
                SizedBox(
                  height: gaugeSize,
                  child: SfRadialGauge(
                    axes: <RadialAxis>[
                      RadialAxis(
                        minimum: 0,
                        maximum: hardMax.toDouble(), // Always show 0..1000
                        startAngle: 150,
                        endAngle: 30,
                        interval: 250,
                        showTicks: true,
                        showLabels: true,
                        axisLabelStyle: GaugeTextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                        majorTickStyle: MajorTickStyle(
                          length: 8,
                          thickness: 2,
                          color: Colors.white24,
                        ),
                        minorTicksPerInterval: 4,
                        minorTickStyle: MinorTickStyle(
                          length: 4,
                          thickness: 1.5,
                          color: Colors.white12,
                        ),
                        axisLineStyle: AxisLineStyle(
                          thickness: 0.14,
                          thicknessUnit: GaugeSizeUnit.factor,
                          color: Colors.white10,
                        ),

                        // Show available vs locked arc
                        ranges: <GaugeRange>[
                          GaugeRange(
                            startValue: 0,
                            endValue: maxSelectable.toDouble(),
                            startWidth: 0.14,
                            endWidth: 0.14,
                            sizeUnit: GaugeSizeUnit.factor,
                            color: Colors.green.withOpacity(0.25),
                          ),
                          GaugeRange(
                            startValue: maxSelectable.toDouble(),
                            endValue: hardMax.toDouble(),
                            startWidth: 0.14,
                            endWidth: 0.14,
                            sizeUnit: GaugeSizeUnit.factor,
                            color: Colors.white12, // locked area
                          ),
                        ],

                        pointers: <GaugePointer>[
                          // Filled progress to current value
                          RangePointer(
                            value: uiValue,
                            width: 0.14,
                            sizeUnit: GaugeSizeUnit.factor,
                            cornerStyle: CornerStyle.bothCurve,
                            color: Color(0xFF667eea),
                          ),

                          // Draggable knob - only enable if user has sufficient funds
                          MarkerPointer(
                            value: uiValue,
                            enableDragging: maxSelectable >= minSelectable,
                            markerType: MarkerType.circle,
                            markerWidth: 24,
                            markerHeight: 24,
                            elevation: 2,
                            color: maxSelectable >= minSelectable
                                ? Color(0xFF667eea)
                                : Colors.grey,
                            borderWidth: 3,
                            borderColor: Colors.white,
                            onValueChanged: maxSelectable >= minSelectable
                                ? (double v) {
                                    // Snap to steps of 10
                                    final double snapped =
                                        (v / 10).round() * 10;
                                    // Clamp within allowed range
                                    final double clamped = snapped.clamp(
                                      minSelectable.toDouble(),
                                      maxSelectable.toDouble(),
                                    );
                                    controller.updatePredictionAmount(
                                      clamped.toInt(),
                                    );
                                  }
                                : null,
                          ),
                        ],

                        annotations: <GaugeAnnotation>[
                          GaugeAnnotation(
                            angle: 90,
                            positionFactor: 0.0,
                            widget: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${controller.predictionAmount.value} J Coins',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 22,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Available: $available  |  Max: $hardMax',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }

  Widget _buildPredictionButtons() {
    return LayoutBuilder(
      builder: (context, constraints) {
        double spacing = constraints.maxWidth * 0.03; // 3% of total width

        return Row(
          children: [
            Expanded(
              child: _buildPredictionButton(
                'green',
                'Predict Green',
                Colors.green,
              ),
            ),
            SizedBox(width: spacing),
            Expanded(
              child: _buildPredictionButton('red', 'Predict Red', Colors.red),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPredictionButton(String option, String label, Color color) {
    return Obx(() {
      bool isSelected = controller.selectedOption.value == option;
      bool canPredict =
          controller.isGameActive.value && controller.countdown.value > 0;

      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Transform.scale(
            scale: isSelected && canPredict ? _pulseAnimation.value : 1.0,
            child: GestureDetector(
              onTap: canPredict ? () => controller.selectOption(option) : null,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isSelected
                        ? [color, color.withOpacity(0.7)]
                        : [color.withOpacity(0.3), color.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected ? color : color.withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withOpacity(0.5),
                            blurRadius: 10,
                            offset: Offset(0, 5),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        option == 'green'
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
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
      );
    });
  }

  void _showInfoDialog() {
    Get.dialog(
      AlertDialog(
        backgroundColor: Color(0xFF2D2D2D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('How to Play', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoSection('🎮 Candle Prediction Game:', [
                '• Buy tokens with real money',
                '• Predict if the price will go up (GREEN) or down (RED)',
                '• Correct predictions earn 90% profit in withdrawable points',
                '• Wrong predictions lose your token bet',
              ]),
              SizedBox(height: 12),
              _buildInfoSection('🎲 Lucky Draw:', [
                '• Earn points from quizzes/ads',
                '• Convert points to lucky draw entries (1:1 ratio)',
                '• 30% chance to win 100-600 withdrawable points',
                '• Each entry costs 1 quiz/ad point',
              ]),
              SizedBox(height: 12),
              _buildInfoSection('💰 Point Types:', [
                '• Quiz/Ad Points: Earned from activities, used for lucky draw',
                '• Purchased Tokens: Bought with real money, used for predictions',
                '• Withdrawable Points: Real money value, can be cashed out',
              ]),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Got it!', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<String> points) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: Colors.yellow, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        ...points
            .map(
              (point) => Padding(
                padding: EdgeInsets.only(left: 8, bottom: 2),
                child: Text(
                  point,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            )
            .toList(),
      ],
    );
  }
}

class CandlestickPainter extends CustomPainter {
  final List<CandleData> candles;

  CandlestickPainter(this.candles);

  @override
  void paint(Canvas canvas, Size size) {
    if (candles.isEmpty) return;

    // More robust price range calculation
    double maxPrice = candles.map((c) => c.high).reduce(math.max);
    double minPrice = candles.map((c) => c.low).reduce(math.min);
    double priceRange = maxPrice - minPrice;

    // Ensure minimum range to prevent division by zero or very small numbers
    if (priceRange <= 0 || priceRange.isNaN || priceRange.isInfinite) {
      priceRange = 0.01;
      // Adjust min/max to center around current price
      double avgPrice = (maxPrice + minPrice) / 2;
      minPrice = avgPrice - 0.005;
      maxPrice = avgPrice + 0.005;
    }

    double candleWidth = (size.width / candles.length * 0.8).clamp(2.0, 20.0);
    double spacing = size.width / candles.length;

    for (int i = 0; i < candles.length; i++) {
      CandleData candle = candles[i];
      double x = i * spacing + spacing / 2;

      // Safer price normalization with bounds checking
      double openY = _normalizePrice(
        candle.open,
        minPrice,
        priceRange,
        size.height,
      );
      double closeY = _normalizePrice(
        candle.close,
        minPrice,
        priceRange,
        size.height,
      );
      double highY = _normalizePrice(
        candle.high,
        minPrice,
        priceRange,
        size.height,
      );
      double lowY = _normalizePrice(
        candle.low,
        minPrice,
        priceRange,
        size.height,
      );

      // Explicit color definition to avoid null/default issues
      Color candleColor;
      if (candle.isGreen) {
        candleColor = const Color(0xFF00C853); // Material Green A700
      } else {
        candleColor = const Color(0xFFD50000); // Material Red A700
      }

      // Draw wick (high-low line) with proper bounds
      if (highY.isFinite && lowY.isFinite && x.isFinite) {
        Paint wickPaint = Paint()
          ..color = candleColor
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

        canvas.drawLine(
          Offset(x, highY.clamp(0.0, size.height)),
          Offset(x, lowY.clamp(0.0, size.height)),
          wickPaint,
        );
      }

      // Draw body (open-close rectangle) with validation
      if (openY.isFinite && closeY.isFinite && x.isFinite) {
        double bodyTop = math.min(openY, closeY).clamp(0.0, size.height);
        double bodyBottom = math.max(openY, closeY).clamp(0.0, size.height);
        double bodyHeight = math.max(
          bodyBottom - bodyTop,
          3.0,
        ); // Minimum visible height

        Paint bodyPaint = Paint()
          ..color = candleColor
          ..style = PaintingStyle.fill;

        // Ensure rectangle is within canvas bounds
        double rectLeft = (x - candleWidth / 2).clamp(
          0.0,
          size.width - candleWidth,
        );
        double rectTop = bodyTop.clamp(0.0, size.height - bodyHeight);

        Rect candleRect = Rect.fromLTWH(
          rectLeft,
          rectTop,
          candleWidth,
          bodyHeight,
        );

        // Only draw if rectangle is valid
        if (candleRect.isFinite && !candleRect.isEmpty) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(candleRect, const Radius.circular(1)),
            bodyPaint,
          );

          // Add border for better visibility on some devices
          Paint borderPaint = Paint()
            ..color = candleColor.withOpacity(0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0;

          canvas.drawRRect(
            RRect.fromRectAndRadius(candleRect, const Radius.circular(1)),
            borderPaint,
          );

          // Enhanced glow effect for the latest candle
          if (i == candles.length - 1) {
            Paint glowPaint = Paint()
              ..color = candleColor.withOpacity(0.4)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

            Rect glowRect = candleRect.inflate(3);
            if (glowRect.isFinite && !glowRect.isEmpty) {
              canvas.drawRRect(
                RRect.fromRectAndRadius(glowRect, const Radius.circular(4)),
                glowPaint,
              );
            }
          }
        }
      }
    }

    // Draw price grid lines with better visibility
    Paint gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    for (int i = 1; i < 5; i++) {
      double y = size.height * i / 5;
      if (y.isFinite && y >= 0 && y <= size.height) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
  }

  // Helper method for safe price normalization
  double _normalizePrice(
    double price,
    double minPrice,
    double priceRange,
    double height,
  ) {
    if (!price.isFinite ||
        !minPrice.isFinite ||
        !priceRange.isFinite ||
        priceRange <= 0) {
      return height / 2; // Return middle if invalid
    }

    double normalized = height - (price - minPrice) / priceRange * height;
    return normalized.clamp(0.0, height);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return oldDelegate is! CandlestickPainter ||
        oldDelegate.candles.length != candles.length ||
        oldDelegate.candles.last.close != candles.last.close;
  }
}
