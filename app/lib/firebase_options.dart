import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

class AppFirebaseOptions {
  static FirebaseOptions get current => FirebaseOptions(
    apiKey: kIsWeb
        ? 'AIzaSyBkVYFTeQ0YpHJ-du7yFmNxghA4IohBfBA'
        : 'AIzaSyDxolgouPz0UwDj6B9SHoD7zgqUtVGiUuI',
    appId: kIsWeb
        ? '1:273979503185:web:743f495416611cca7f3e70'
        : '1:273979503185:android:08a58d0e33e079307f3e70',
    messagingSenderId: '273979503185',
    projectId: 'cumplemes',
    authDomain: 'cumplemes.firebaseapp.com',
    databaseURL: 'https://cumplemes-default-rtdb.firebaseio.com',
    storageBucket: 'cumplemes.firebasestorage.app',
  );
}
