import 'package:ai_calendar_app/providers/aiFunctions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

class AuthProvider with ChangeNotifier {
  String _accessToken = "";
  String _refreshToken = "";
  String displayName = "";

  String get accessToken => _accessToken;
  String get refreshToken => _refreshToken;

  final FirebaseAuth auth = FirebaseAuth.instance;
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: ['email', 'https://www.googleapis.com/auth/calendar'],
  );

  Future<void> autoSignIn(BuildContext context) async {
    try {
      GoogleSignInAuthentication? googleAuth;
      // Attempt silent sign in first
      final GoogleSignInAccount? googleUser =
          await googleSignIn.signInSilently();

      if (googleUser != null) {
        googleAuth = await googleUser.authentication;
      } else {
        // Perform interactive sign in
        final GoogleSignInAccount? googleUserInteractive =
            await googleSignIn.signIn();
        if (googleUserInteractive != null) {
          googleAuth = await googleUserInteractive.authentication;
        }
      }

      if (googleAuth != null && googleAuth.accessToken != null) {
        _accessToken = googleAuth.accessToken!;
        _refreshToken =
            googleAuth.idToken ?? ''; // refreshToken is usually the idToken

        final UserCredential userCredential = await auth.signInWithCredential(
          GoogleAuthProvider.credential(
            accessToken: googleAuth.accessToken,
            idToken: googleAuth.idToken,
          ),
        );

        displayName = userCredential.user?.displayName ?? '';
        notifyListeners();

        final aiFunctions = Provider.of<AIFunctions>(context, listen: false);
        aiFunctions.setAuthTokens(_accessToken, _refreshToken);
        await aiFunctions.fetchEvents();
      }
    } catch (error) {
      print("Error during sign in: $error");
      // Handle the error, possibly by showing an error message to the user
    }
  }
}
