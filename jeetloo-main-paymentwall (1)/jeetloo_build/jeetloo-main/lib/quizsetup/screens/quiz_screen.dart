import 'package:flutter/material.dart';
import 'package:jeetloo/quizsetup/models/questions.dart'; // must export `questions` (110 items)
import 'package:jeetloo/quizsetup/screens/result_screen.dart';
import 'package:jeetloo/quizsetup/widgets/answer_card.dart';
import 'package:jeetloo/quizsetup/widgets/next_button.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  // --- NEW: we will play only 9 random questions from the full bank ---
  late final List selectedQuestions;

  int? selectedAnswerIndex;
  int questionIndex = 0;
  int score = 0;

  late AnimationController _progressController;
  late AnimationController _questionController;
  late AnimationController _answersController;
  late Animation<double> _progressAnimation;
  late Animation<Offset> _questionSlideAnimation;
  late Animation<double> _questionFadeAnimation;
  late Animation<double> _answersScaleAnimation;

  @override
  void initState() {
    super.initState();
    _prepareRandomQuiz(); // ← pick 9 random questions first
    _setupAnimations();
    _startAnimations();
  }

  // --- NEW: Build a 9-question random set from the full list ---
  void _prepareRandomQuiz() {
    // Make a copy so we don't mutate the original exported list
    final pool = List.of(questions);
    pool.shuffle(); // randomize order
    selectedQuestions = pool.take(9).toList(); // pick first 9
  }

  void _setupAnimations() {
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _questionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _answersController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _progressAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );

    _questionSlideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _questionController,
            curve: Curves.easeOutCubic,
          ),
        );

    _questionFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _questionController, curve: Curves.easeIn),
    );

    _answersScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _answersController, curve: Curves.elasticOut),
    );
  }

  void _startAnimations() {
    _progressController.forward();
    _questionController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _answersController.forward();
    });
  }

  void _resetAnimations() {
    _questionController.reset();
    _answersController.reset();
    _questionController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      _answersController.forward();
    });
  }

  @override
  void dispose() {
    _progressController.dispose();
    _questionController.dispose();
    _answersController.dispose();
    super.dispose();
  }

  void pickAnswer(int value) {
    selectedAnswerIndex = value;
    final question = selectedQuestions[questionIndex];
    if (selectedAnswerIndex == question.correctAnswerIndex) {
      score++;
    }
    setState(() {});
  }

  void goToNextQuestion() {
    if (questionIndex < selectedQuestions.length - 1) {
      setState(() {
        questionIndex++;
        selectedAnswerIndex = null;
      });
      _resetAnimations();
      // Update progress against the 9-question set
      _progressController.animateTo(
        (questionIndex + 1) / selectedQuestions.length,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = selectedQuestions[questionIndex];
    final total = selectedQuestions.length; // should be 9
    bool isLastQuestion = questionIndex == total - 1;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenHeight < 700;
    final isTablet = screenWidth > 600;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2), Color(0xFFf093fb)],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    children: [
                      // Custom App Bar with Progress
                      _buildCustomAppBar(isSmallScreen, total),

                      // Main Content
                      Container(
                        height:
                            constraints.maxHeight - (isSmallScreen ? 120 : 140),
                        margin: EdgeInsets.symmetric(
                          horizontal: isTablet
                              ? screenWidth * 0.15
                              : screenWidth * 0.05,
                          vertical: isSmallScreen ? 8 : 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Column(
                            children: [
                              // Question Section
                              Expanded(
                                flex: isSmallScreen ? 2 : 2,
                                child: _buildQuestionSection(
                                  question,
                                  isSmallScreen,
                                ),
                              ),

                              // Answers Section
                              Expanded(
                                flex: isSmallScreen ? 5 : 6,
                                child: _buildAnswersSection(
                                  question,
                                  isSmallScreen,
                                ),
                              ),

                              // Button Section - Fixed height
                              _buildButtonSection(
                                isLastQuestion,
                                isSmallScreen,
                              ),
                            ],
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

  Widget _buildCustomAppBar(bool isSmallScreen, int total) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_back_ios,
                  color: Colors.white,
                  size: isSmallScreen ? 20 : 24,
                ),
              ),
              Text(
                'Quiz Challenge',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${questionIndex + 1}/$total',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),

          // Progress Bar
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, child) {
              return Container(
                height: isSmallScreen ? 6 : 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  // progress based on 9-question set
                  widthFactor: (questionIndex + 1) / total,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.amber, Colors.orange],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionSection(question, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Center(
        child: SlideTransition(
          position: _questionSlideAnimation,
          child: FadeTransition(
            opacity: _questionFadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    question.question,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2D3748),
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: isSmallScreen ? 3 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnswersSection(question, bool isSmallScreen) {
    return AnimatedBuilder(
      animation: _answersScaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _answersScaleAnimation.value,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16 : 16,
              vertical: isSmallScreen ? 8 : 12,
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: question.options.length,
                    itemBuilder: (context, index) {
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 200 + (index * 100)),
                        margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
                        child: GestureDetector(
                          onTap: selectedAnswerIndex == null
                              ? () => pickAnswer(index)
                              : null,
                          child: _buildAnimatedAnswerCard(
                            currentIndex: index,
                            question: question.options[index],
                            isSelected: selectedAnswerIndex == index,
                            selectedAnswerIndex: selectedAnswerIndex,
                            correctAnswerIndex: question.correctAnswerIndex,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedAnswerCard({
    required int currentIndex,
    required String question,
    required bool isSelected,
    required int? selectedAnswerIndex,
    required int correctAnswerIndex,
  }) {
    bool isCorrect = currentIndex == correctAnswerIndex;
    bool isWrong =
        selectedAnswerIndex != null &&
        currentIndex == selectedAnswerIndex &&
        !isCorrect;
    bool showResult = selectedAnswerIndex != null;

    Color cardColor;
    Color textColor;
    IconData? icon;

    if (showResult) {
      if (isCorrect) {
        cardColor = Colors.green.withOpacity(0.1);
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
      } else if (isWrong) {
        cardColor = Colors.red.withOpacity(0.1);
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
      } else {
        cardColor = Colors.grey.withOpacity(0.1);
        textColor = Colors.grey.shade600;
      }
    } else {
      cardColor = isSelected
          ? const Color(0xFF667eea).withOpacity(0.1)
          : Colors.grey.withOpacity(0.05);
      textColor = isSelected
          ? const Color(0xFF667eea)
          : const Color(0xFF2D3748);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: showResult
              ? (isCorrect
                    ? Colors.green
                    : isWrong
                    ? Colors.red
                    : Colors.transparent)
              : (isSelected ? const Color(0xFF667eea) : Colors.transparent),
          width: 2,
        ),
        boxShadow: isSelected || showResult
            ? [
                BoxShadow(
                  color:
                      (showResult
                              ? (isCorrect ? Colors.green : Colors.red)
                              : const Color(0xFF667eea))
                          .withOpacity(0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: textColor.withOpacity(0.2),
            ),
            child: Center(
              child: showResult && icon != null
                  ? Icon(icon, color: textColor, size: 18)
                  : Text(
                      String.fromCharCode(65 + currentIndex), // A, B, C, D
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              question,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonSection(bool isLastQuestion, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: isSmallScreen ? 48 : 56,
        child: ElevatedButton(
          onPressed: isLastQuestion
              ? () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => ResultScreen(score: score),
                    ),
                  );
                }
              : (selectedAnswerIndex != null ? goToNextQuestion : null),
          style: ElevatedButton.styleFrom(
            backgroundColor: selectedAnswerIndex != null
                ? const Color(0xFF667eea)
                : Colors.grey.shade300,
            foregroundColor: Colors.white,
            elevation: selectedAnswerIndex != null ? 8 : 0,
            shadowColor: const Color(0xFF667eea).withOpacity(0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isLastQuestion ? 'Finish Quiz' : 'Next Question',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              Icon(
                isLastQuestion ? Icons.flag : Icons.arrow_forward,
                size: isSmallScreen ? 18 : 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
