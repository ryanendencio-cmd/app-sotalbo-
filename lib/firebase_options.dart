import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return const FirebaseOptions(
        apiKey: String.fromEnvironment(
          'FIREBASE_WEB_API_KEY',
          defaultValue: 'REPLACE_WEB_API_KEY',
        ),
        appId: String.fromEnvironment(
          'FIREBASE_WEB_APP_ID',
          defaultValue: 'REPLACE_WEB_APP_ID',
        ),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
          defaultValue: 'REPLACE_MESSAGING_SENDER_ID',
        ),
        projectId: String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: 'buildtrack-sotalbocons-system',
        ),
        authDomain: String.fromEnvironment(
          'FIREBASE_AUTH_DOMAIN',
          defaultValue: 'REPLACE_AUTH_DOMAIN',
        ),
        storageBucket: String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
          defaultValue: 'REPLACE_STORAGE_BUCKET',
        ),
      );
    }

    if (Platform.isAndroid) {
      return const FirebaseOptions(
        apiKey: String.fromEnvironment(
          'FIREBASE_ANDROID_API_KEY',
          defaultValue: 'AIzaSyBbtWsnf08eiKhNAsAojlwhAyESJ5qs2L8',
        ),
        appId: String.fromEnvironment(
          'FIREBASE_ANDROID_APP_ID',
          defaultValue: '1:126486188973:android:b3bd89276c219b73154724',
        ),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
          defaultValue: '126486188973',
        ),
        projectId: String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: 'buildtrack-sotalbocons-system',
        ),
        storageBucket: String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
          defaultValue: 'buildtrack-sotalbocons-system.firebasestorage.app',
        ),
      );
    }

    if (Platform.isIOS) {
      return const FirebaseOptions(
        apiKey: String.fromEnvironment(
          'FIREBASE_IOS_API_KEY',
          defaultValue: 'REPLACE_IOS_API_KEY',
        ),
        appId: String.fromEnvironment(
          'FIREBASE_IOS_APP_ID',
          defaultValue: 'REPLACE_IOS_APP_ID',
        ),
        messagingSenderId: String.fromEnvironment(
          'FIREBASE_MESSAGING_SENDER_ID',
          defaultValue: 'REPLACE_MESSAGING_SENDER_ID',
        ),
        projectId: String.fromEnvironment(
          'FIREBASE_PROJECT_ID',
          defaultValue: 'buildtrack-sotalbocons-system',
        ),
        storageBucket: String.fromEnvironment(
          'FIREBASE_STORAGE_BUCKET',
          defaultValue: 'REPLACE_STORAGE_BUCKET',
        ),
        iosBundleId: String.fromEnvironment(
          'FIREBASE_IOS_BUNDLE_ID',
          defaultValue: 'com.example.buildtrack',
        ),
      );
    }

    throw UnsupportedError(
      'DefaultFirebaseOptions are not supported for this platform.',
    );
  }
}
