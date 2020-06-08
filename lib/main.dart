import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/UserManagement.dart';
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
            home: currentUser == null ? Scaffold(body: LoginPage()) : StreamProvider<User>(
              create: (context) => UserManagement().streamCurrentUser(currentUser),
              child: Consumer<User>(
                builder: (context, user, _) {
                  return user == null ? Scaffold(body:LoginPage()) : HomePageMobile();
                },
              ),
            ),
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
  bool showLoadingDialog = false;
  ActivityManager activityManager = new ActivityManager();
  List<Post> queue = new List<Post>();
  List<Post> pagePosts;
  bool isPlaying;
  String currentPostId;
  Post currentPostObj;
  DirectPost currentDirectPostObj;
  PostType currentPostType;
  AudioPlayer player = new AudioPlayer();
  bool panelOpen = true;
  PostPosition position;
  PostDuration postLength;

  playPost({Post post, DirectPost directPost}) {
    player = new AudioPlayer();
    if(post != null) {
      currentPostId = post.id;
      currentPostObj = post;
      currentPostType = PostType.POST;
      if(queue.where((p) => p.id == post.id).length > 0) {
        queue.removeWhere((p) => p.id == post.id);
      }
      isPlaying = true;
      player.play(post.audioFileLocation);
    }
    if(directPost != null) {
      currentPostId = directPost.id;
      currentDirectPostObj = directPost;
      currentPostType = PostType.DIRECT_POST;
      isPlaying = true;
      player.play(directPost.audioFileLocation).catchError((e) {
        print('error playing post: $e');
      });
    }
    player.onPlayerCompletion.listen((_) async {
      stopPost();
      playPostFromQueue();
    });
    player.onDurationChanged.listen((d) {
      postLength = PostDuration(duration: d);
      notifyListeners();
    });
    player.onAudioPositionChanged.listen((d) {
      position = PostPosition(duration: d);
      notifyListeners();
    });
    notifyListeners();
  }

  stopPost() {
    isPlaying = false;
    //player.stop();
    player.dispose();
    //player = new AudioPlayer();
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

  addPostToQueue(Post post) {
    queue.add(post);
    print('Queue Length: ${queue.length}');
    notifyListeners();
  }

  playPostFromQueue() async {
    await new Future.delayed(const Duration(seconds : 2));
    if(queue.length > 0) {
      Post currentPost = queue.removeAt(0);
      print('playing next post: ${currentPost.id}');
      playPost(post: currentPost);
    }
  }

  setPagePosts(List<Post> posts) {
    pagePosts = posts;
  }
}