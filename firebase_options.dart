import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // 🌐 WEB CONFIG (MOST IMPORTANT)
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyC9bKr5_A3eRpYg5XWnQfYFICbPwkguVJU',
    appId: '1:925126460782:web:e1faee64ba5778933b2d7f',
    messagingSenderId: '925126460782',
    projectId: 'faculty-interaction-app',
    authDomain: 'faculty-interaction-app.firebaseapp.com',
    databaseURL:
        'https://faculty-interaction-app-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'faculty-interaction-app.firebasestorage.app',
    measurementId: 'G-Q2R05VY3Q0',
  );

  // 🤖 ANDROID CONFIG (BASIC SAFE VERSION)
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC9bKr5_A3eRpYg5XWnQfYFICbPwkguVJU',
    appId: '1:925126460782:android:b92760d14a8e4ea43b2d7f',
    messagingSenderId: '925126460782',
    projectId: 'faculty-interaction-app',
    databaseURL:
        'https://faculty-interaction-app-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'faculty-interaction-app.firebasestorage.app',
  );

  // 🍎 OPTIONAL (SAFE PLACEHOLDER)
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'YOUR_IOS_API_KEY',
    appId: 'YOUR_IOS_APP_ID',
    messagingSenderId: '925126460782',
    projectId: 'faculty-interaction-app',
    databaseURL:
        'https://faculty-interaction-app-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'faculty-interaction-app.firebasestorage.app',
  );
}