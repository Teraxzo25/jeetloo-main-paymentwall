import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

class QuizController extends GetxController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  var canPlayQuiz = true.obs;

  @override
  void onInit() {
    super.onInit();
    checkQuizAvailability();
  }

  Future<void> checkQuizAvailability() async {
    DocumentSnapshot doc = await _firestore
        .collection('users')
        .doc(userId)
        .get();

    if (doc.exists && doc['lastQuizTime'] != null) {
      DateTime lastQuiz = (doc['lastQuizTime'] as Timestamp).toDate();
      Duration diff = DateTime.now().difference(lastQuiz);

      canPlayQuiz.value = diff.inHours >= 24;
    } else {
      canPlayQuiz.value = true; // First time playing
    }
  }

  Future<void> markQuizPlayed() async {
    await _firestore.collection('users').doc(userId).update({
      'lastQuizTime': DateTime.now(),
    });
    canPlayQuiz.value = false;
  }
}
