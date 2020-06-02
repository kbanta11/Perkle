import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';

import 'LoginPage.dart';
import 'SignUpPage.dart';
import 'HomePage.dart';
import 'SearchPage.dart';
import 'Dashboard.dart';

void main() async {
  runApp(new MainApp());
}

class MainApp extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MultiProvider(
      providers: [
        StreamProvider<FirebaseUser>(create: (_) => FirebaseAuth.instance.onAuthStateChanged),
        ChangeNotifierProvider<MainAppProvider>(create: (_) => MainAppProvider())
      ],
      child: Consumer<FirebaseUser>(
        builder: (context, currentUser, _) {
          return MaterialApp(
            title: 'Perkl',
            theme: new ThemeData (
                primarySwatch: Colors.deepPurple
            ),
            home: currentUser == null ? Scaffold(body:LoginPage()) : HomePageMobile(),
            routes: <String, WidgetBuilder> {
              '/landingpage': (BuildContext context) => new MainApp(),
              '/signup': (BuildContext context) => new SignUpPage(),
              '/homepage': (BuildContext context) => new HomePageMobile(),
              '/searchpage': (BuildContext context) => new SearchPageMobile(),
              // '/dashboard': (BuildContext context) => new DashboardPage(),
            },
          );
        },
      )
    );
  }
}

enum PostType {
  POST,
  DIRECT_POST
}

class MainAppProvider extends ChangeNotifier {
  ActivityManager activityManager = new ActivityManager();
  bool isPlaying;
  String currentPostId;
  Post currentPostObj;
  DirectPost currentDirectPostObj;
  PostType currentPostType;
  AudioPlayer player = new AudioPlayer();
  bool panelOpen = true;

  playPost({Post post, DirectPost directPost}) {
    if(post != null) {
      currentPostId = post.id;
      currentPostObj = post;
      currentPostType = PostType.POST;
      isPlaying = true;
      player.play(post.audioFileLocation);
    }
    if(directPost != null) {
      currentPostId = directPost.id;
      currentDirectPostObj = directPost;
      currentPostType = PostType.DIRECT_POST;
      isPlaying = true;
      player.play(directPost.audioFileLocation);
    }
    player.onPlayerCompletion.listen((_) {
      stopPost();
    });
    notifyListeners();
  }

  stopPost() {
    isPlaying = false;
    player.stop();
    notifyListeners();
  }

  pausePost() {
    player.pause();
    isPlaying = false;
    notifyListeners();
  }

  updatePanelState() {
    panelOpen = !panelOpen;
    notifyListeners();
  }
}