import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:jeetloo/quizsetup/models/questions.dart';

class ResultScreen extends StatefulWidget {
  const ResultScreen({super.key, required this.score});

  final int score;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with TickerProviderStateMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _rewarded = false;
  late AnimationController _animationController;
  late AnimationController _celebrationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _celebrationAnimation;

  @override
  void initState() {
    super.initState();
    _rewardUserPoints();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _celebrationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _celebrationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _celebrationController, curve: Curves.bounceOut),
    );

    // Start animations
    _animationController.forward();
    _celebrationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _celebrationController.dispose();
    super.dispose();
  }

  Future<void> _rewardUserPoints() async {
    if (_rewarded) return; // prevent multiple updates if rebuilds happen
    final user = _auth.currentUser;
    if (user == null) return;

    final userId = user.uid;

    // Define how many points user gets per quiz score.
    // For example: 10 points per score unit (you can adjust)
    int pointsToAdd = widget.score * 10;

    final userDocRef = _firestore.collection('users').doc(userId);

    try {
      await userDocRef.update({'points': FieldValue.increment(pointsToAdd)});

      setState(() {
        _rewarded = true; // mark rewarded done
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.stars, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(
                child: Text('You earned $pointsToAdd points for this quiz!'),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      // Handle error (optional)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Flexible(child: Text('Failed to update points: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Color _getScoreColor() {
    final percentage = (widget.score / questions.length * 100).round();
    if (percentage >= 80) return Colors.green;
    if (percentage >= 60) return Colors.orange;
    return Colors.red;
  }

  String _getPerformanceMessage() {
    final percentage = (widget.score / questions.length * 100).round();
    if (percentage >= 90) return "Outstanding! 🎉";
    if (percentage >= 80) return "Excellent! 👏";
    if (percentage >= 70) return "Great Job! 😊";
    if (percentage >= 60) return "Good Work! 👍";
    if (percentage >= 50) return "Keep Trying! 💪";
    return "Practice More! 📚";
  }

  Widget _buildConfetti() {
    final percentage = (widget.score / questions.length * 100).round();
    if (percentage < 70) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _celebrationAnimation,
      builder: (context, child) {
        return Positioned.fill(
          child: CustomPaint(
            painter: ConfettiPainter(_celebrationAnimation.value),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isTablet = size.width > 600;
    final isLandscape = size.width > size.height;
    final percentage = (widget.score / questions.length * 100).round();
    final scoreColor = _getScoreColor();

    // Responsive sizing
    final headerIconSize = isTablet ? 80.0 : 60.0;
    final titleFontSize = isTablet
        ? 40.0
        : isLandscape
        ? 28.0
        : 32.0;
    final messageFontSize = isTablet
        ? 24.0
        : isLandscape
        ? 18.0
        : 20.0;
    final scoreFontSize = isTablet
        ? 100.0
        : isLandscape
        ? 60.0
        : 80.0;
    final circleSize = isTablet
        ? 300.0
        : isLandscape
        ? 200.0
        : 250.0;
    final innerCircleSize = isTablet
        ? 240.0
        : isLandscape
        ? 160.0
        : 200.0;
    final padding = isTablet
        ? 40.0
        : isLandscape
        ? 16.0
        : 20.0;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scoreColor.withOpacity(0.1),
              Colors.white,
              scoreColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Stack(
          children: [
            _buildConfetti(),
            SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight:
                        size.height -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(padding),
                    child: isLandscape && !isTablet
                        ? _buildLandscapeLayout(
                            scoreColor,
                            headerIconSize,
                            titleFontSize,
                            messageFontSize,
                            scoreFontSize,
                            circleSize,
                            innerCircleSize,
                            percentage,
                          )
                        : _buildPortraitLayout(
                            scoreColor,
                            headerIconSize,
                            titleFontSize,
                            messageFontSize,
                            scoreFontSize,
                            circleSize,
                            innerCircleSize,
                            percentage,
                            isTablet,
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(
    Color scoreColor,
    double headerIconSize,
    double titleFontSize,
    double messageFontSize,
    double scoreFontSize,
    double circleSize,
    double innerCircleSize,
    int percentage,
    bool isTablet,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Header Section
        _buildHeaderSection(
          scoreColor,
          headerIconSize,
          titleFontSize,
          messageFontSize,
        ),

        // Score Display Section
        _buildScoreSection(
          scoreColor,
          scoreFontSize,
          circleSize,
          innerCircleSize,
          percentage,
          isTablet,
        ),

        // Points and Stats Section
        _buildStatsSection(isTablet),

        // Action Buttons Section
        _buildActionButtons(scoreColor, isTablet),
      ],
    );
  }

  Widget _buildLandscapeLayout(
    Color scoreColor,
    double headerIconSize,
    double titleFontSize,
    double messageFontSize,
    double scoreFontSize,
    double circleSize,
    double innerCircleSize,
    int percentage,
  ) {
    return Column(
      children: [
        // Header Section (smaller in landscape)
        SizedBox(
          height: 100,
          child: _buildHeaderSection(
            scoreColor,
            headerIconSize * 0.7,
            titleFontSize,
            messageFontSize,
          ),
        ),

        Expanded(
          child: Row(
            children: [
              // Left side - Score Display
              Expanded(
                flex: 2,
                child: _buildScoreSection(
                  scoreColor,
                  scoreFontSize,
                  circleSize,
                  innerCircleSize,
                  percentage,
                  false,
                ),
              ),

              const SizedBox(width: 20),

              // Right side - Stats and Buttons
              Expanded(
                flex: 1,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatsSection(false, isVertical: true),
                    const SizedBox(height: 20),
                    _buildActionButtons(scoreColor, false, isCompact: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(
    Color scoreColor,
    double iconSize,
    double titleFontSize,
    double messageFontSize,
  ) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.quiz, size: iconSize, color: scoreColor),
          SizedBox(height: iconSize * 0.27),
          FittedBox(
            child: Text(
              'Quiz Complete!',
              style: TextStyle(
                fontSize: titleFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          SizedBox(height: iconSize * 0.13),
          FittedBox(
            child: Text(
              _getPerformanceMessage(),
              style: TextStyle(
                fontSize: messageFontSize,
                fontWeight: FontWeight.w500,
                color: scoreColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection(
    Color scoreColor,
    double scoreFontSize,
    double circleSize,
    double innerCircleSize,
    int percentage,
    bool isTablet,
  ) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        constraints: BoxConstraints(maxWidth: isTablet ? 400 : 350),
        padding: EdgeInsets.all(isTablet ? 40 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: scoreColor.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your Score',
              style: TextStyle(
                fontSize: isTablet ? 28 : 24,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: isTablet ? 30 : 20),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: circleSize,
                  width: circleSize,
                  child: CircularProgressIndicator(
                    strokeWidth: isTablet ? 15 : 12,
                    value: widget.score / questions.length,
                    color: scoreColor,
                    backgroundColor: scoreColor.withOpacity(0.1),
                  ),
                ),
                Container(
                  height: innerCircleSize,
                  width: innerCircleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scoreColor.withOpacity(0.05),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        child: Text(
                          widget.score.toString(),
                          style: TextStyle(
                            fontSize: scoreFontSize,
                            fontWeight: FontWeight.bold,
                            color: scoreColor,
                          ),
                        ),
                      ),
                      Container(
                        height: 2,
                        width: innerCircleSize * 0.3,
                        color: scoreColor.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      Text(
                        '${questions.length}',
                        style: TextStyle(
                          fontSize: scoreFontSize * 0.3,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isTablet ? 30 : 20),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 30 : 20,
                vertical: isTablet ? 15 : 10,
              ),
              decoration: BoxDecoration(
                color: scoreColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$percentage%',
                style: TextStyle(
                  fontSize: isTablet ? 32 : 28,
                  fontWeight: FontWeight.bold,
                  color: scoreColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(bool isTablet, {bool isVertical = false}) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        constraints: BoxConstraints(maxWidth: isTablet ? 500 : double.infinity),
        padding: EdgeInsets.all(isTablet ? 25 : 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: isVertical
            ? Column(
                children: [
                  _buildStatItem(
                    icon: Icons.star,
                    label: 'Points Earned',
                    value: '${widget.score * 10}',
                    color: Colors.amber,
                    isTablet: isTablet,
                  ),
                  const SizedBox(height: 15),
                  _buildStatItem(
                    icon: Icons.check_circle,
                    label: 'Correct',
                    value: '${widget.score}',
                    color: Colors.green,
                    isTablet: isTablet,
                  ),
                  const SizedBox(height: 15),
                  _buildStatItem(
                    icon: Icons.cancel,
                    label: 'Incorrect',
                    value: '${questions.length - widget.score}',
                    color: Colors.red,
                    isTablet: isTablet,
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.star,
                      label: 'Points Earned',
                      value: '${widget.score * 10}',
                      color: Colors.amber,
                      isTablet: isTablet,
                    ),
                  ),
                  Container(height: 40, width: 1, color: Colors.grey[300]),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.check_circle,
                      label: 'Correct',
                      value: '${widget.score}',
                      color: Colors.green,
                      isTablet: isTablet,
                    ),
                  ),
                  Container(height: 40, width: 1, color: Colors.grey[300]),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.cancel,
                      label: 'Incorrect',
                      value: '${questions.length - widget.score}',
                      color: Colors.red,
                      isTablet: isTablet,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildActionButtons(
    Color scoreColor,
    bool isTablet, {
    bool isCompact = false,
  }) {
    final buttonHeight = isTablet
        ? 65.0
        : isCompact
        ? 45.0
        : 55.0;
    final fontSize = isTablet
        ? 20.0
        : isCompact
        ? 16.0
        : 18.0;
    final iconSize = isTablet
        ? 28.0
        : isCompact
        ? 20.0
        : 24.0;

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        constraints: BoxConstraints(maxWidth: isTablet ? 400 : double.infinity),
        child: Column(
          children: [
            // Home Button
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: scoreColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.home, size: iconSize),
                    SizedBox(width: isCompact ? 6 : 8),
                    Flexible(
                      child: Text(
                        'Go Back to Home',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: isCompact ? 8 : 12),

            // Try Again Button
            SizedBox(
              width: double.infinity,
              height: buttonHeight,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: scoreColor,
                  side: BorderSide(color: scoreColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.refresh, size: iconSize),
                    SizedBox(width: isCompact ? 6 : 8),
                    Flexible(
                      child: Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isTablet,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: isTablet ? 28 : 24),
        SizedBox(height: isTablet ? 6 : 4),
        FittedBox(
          child: Text(
            value,
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        FittedBox(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

class ConfettiPainter extends CustomPainter {
  final double animation;

  ConfettiPainter(this.animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final colors = [
      Colors.red,
      Colors.blue,
      Colors.green,
      Colors.yellow,
      Colors.purple,
    ];

    for (int i = 0; i < 50; i++) {
      paint.color = colors[i % colors.length];
      final x = (i * 37) % size.width;
      final y = (animation * size.height + i * 23) % size.height;

      canvas.drawCircle(Offset(x, y), 3 + (i % 3), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
