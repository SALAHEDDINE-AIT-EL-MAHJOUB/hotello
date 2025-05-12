import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AdminUtils {
  static Future<bool> isUserAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }
    
    try {
      final userSnapshot = await FirebaseDatabase.instance
          .ref()
          .child('users/${user.uid}')
          .get();
      
      if (userSnapshot.exists) {
        final userData = userSnapshot.value as Map<dynamic, dynamic>?;
        return userData != null && userData['isAdmin'] == true;
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
    
    return false;
  }

  static Future<void> setUserAsAdmin(String userEmail) async {
    try {
      // First find the user by email
      final usersSnapshot = await FirebaseDatabase.instance.ref('users').get();
      String? userId;
      
      if (usersSnapshot.exists) {
        final usersData = usersSnapshot.value as Map<dynamic, dynamic>;
        usersData.forEach((key, value) {
          if (value['email'] == userEmail) {
            userId = key;
          }
        });
        
        if (userId != null) {
          await FirebaseDatabase.instance
              .ref('users/$userId')
              .update({'isAdmin': true});
          return;
        }
      }
      
      throw Exception('User not found');
    } catch (e) {
      print('Error setting user as admin: $e');
      rethrow;
    }
  }
}