import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/UserManagement.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_review/launch_review.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:package_info/package_info.dart';
import 'package:podcast_search/podcast_search.dart';

import 'LoginPage.dart';
import 'SignUpPage.dart';
import 'HomePage.dart';
import 'SearchPage.dart';
import 'Dashboard.dart';
import 'ReplyToEpisode.dart';

void main() async {
  runApp(new MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({ Key key }) : super(key: key);

  @override
  MainAppState createState() => MainAppState();
}

class MainAppState extends State<MainApp> {
  Future<bool> updateNeeded() async {
    int minBuildNumber = await DBService().getConfigMinBuildNumber();

    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    print('Current Build Number: ${packageInfo.buildNumber}/Current Version: ${packageInfo.version}');
    int buildNumber = int.parse(packageInfo.buildNumber.trim().replaceAll(".", ""));
    print('Min Version: $minBuildNumber; Current Build Number: $buildNumber');
    return buildNumber < minBuildNumber;
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return MultiProvider(
      providers: [
        StreamProvider<FirebaseUser>(create: (_) => FirebaseAuth.instance.onAuthStateChanged),
        ChangeNotifierProvider<MainAppProvider>(create: (_) => MainAppProvider()),
        FutureProvider<bool>(create: (_) => updateNeeded()),
      ],
      child: Consumer<FirebaseUser>(
        builder: (context, currentUser, _) {
          bool promptUpdate = Provider.of<bool>(context);
          print('Prompt Update: $promptUpdate');
          return MaterialApp(
            title: 'Perkl',
            theme: new ThemeData (
                primarySwatch: Colors.deepPurple
            ),
            home: promptUpdate == null ? Center(child: CircularProgressIndicator()) : promptUpdate ? Scaffold(body: Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage("assets/images/drawable-xxxhdpi/login-bg.png"),
                    fit: BoxFit.cover,
                  ),
                ),
              child: SimpleDialog(
                contentPadding: EdgeInsets.fromLTRB(10, 15, 10, 5),
                title: Center(child: Text('Update Required!', style: TextStyle(color: Colors.deepPurple),)),
                children: <Widget>[
                  Center(child: Text('It looks like you have an outdated version of our app. You\'ll need to upgrade before you can continue.', style: TextStyle(fontSize: 16),)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      FlatButton(
                        child: Text('Upgrade Now!', style: TextStyle(color: Colors.white),),
                        color: Colors.deepPurple,
                        onPressed: () {
                          LaunchReview.launch(androidAppId: 'com.test.perklapp', iOSAppId: '1516543692');
                        }
                      )
                    ],
                  )
                ],
              ),
            )) : currentUser == null ? Scaffold(body: LoginPage()) : StreamProvider<User>(
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

class MainAppProvider extends ChangeNotifier {
  bool showLoadingDialog = false;
  ActivityManager activityManager = new ActivityManager();
  List<PostPodItem> queue = new List<PostPodItem>();
  List<Post> pagePosts;
  bool isPlaying = false;
  PostPodItem currentPostPodItem;
  String currentPostPodId;
  PostType currentPostType;
  AudioPlayer player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
  //SoundPlayer soundPlayer = SoundPlayer.withShadeUI(canSkipBackward: false, playInBackground: true);
  bool panelOpen = true;
  PostPosition position;
  PostDuration postLength;
  //For showing recording button time
  bool isRecording = false;
  Duration recordingTime;

  playPost(PostPodItem newPostPod) async {

    if(isPlaying) {
      player.stop();
      player.dispose();
    }

    if(currentPostPodItem != null && currentPostPodItem.id == newPostPod.id && currentPostPodItem.type == newPostPod.type) {
      player.resume();
      isPlaying = true;
      notifyListeners();
      return;
    }

    player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
    //soundPlayer.onStopped =  ({wasUser}) => soundPlayer.release();

    currentPostPodItem = newPostPod;
    currentPostType = newPostPod.type;
    currentPostPodId = newPostPod.id;
    isPlaying = true;
    if(queue.where((PostPodItem p) => p.id == newPostPod.id).length > 0) {
      queue.removeWhere((p) => p.id == newPostPod.id);
    }
    await player.play(newPostPod.audioUrl).catchError((e) {
      print('Error playing post: $e');
    });

    player.onPlayerCompletion.listen((_) async {
      stopPost();
      playPostFromQueue();
    });
    /*
    player.onDurationChanged.listen((d) {
      postLength = PostDuration(duration: d);
      //notifyListeners();
    });
    player.onAudioPositionChanged.listen((d) {
      position = PostPosition(duration: d);
      //notifyListeners();
    });
     */

    notifyListeners();
  }

  skipAhead() async {
    if(currentPostPodItem != null) {
      Duration duration = Duration(milliseconds: await player.getDuration());
      Duration position = Duration(milliseconds: await player.getCurrentPosition());
      print('Duration ms: ${duration.inSeconds}/Position ms: ${position.inSeconds}');
      if(position.inSeconds + 30 >= duration.inSeconds)
        player.seek(Duration(seconds: duration.inSeconds - 15));
      else
        player.seek(Duration(seconds: position.inSeconds + 30));
    }
  }

  skipBack() async {
    if(currentPostPodItem != null) {
      Duration duration = Duration(milliseconds: await player.getDuration());
      Duration position = Duration(milliseconds: await player.getCurrentPosition());
      print('Duration ms: ${duration.inSeconds}/Position ms: ${position.inSeconds}');
      if(position.inSeconds - 30 <= 0)
        player.seek(Duration(seconds: 0));
      else
        player.seek(Duration(seconds: position.inSeconds - 30));
    }
  }

  stopPost() {
    isPlaying = false;
    currentPostPodItem = null;
    player.stop();
    player.dispose();
    player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
    notifyListeners();
  }

  pausePost() {
    print('Pausing...');
    player.pause();
    isPlaying = false;
    notifyListeners();
  }

  updatePanelState() {
    panelOpen = !panelOpen;
    notifyListeners();
  }

  addPostToQueue(PostPodItem post) {
    queue.add(post);
    notifyListeners();
  }

  removeFromQueue(PostPodItem post) {
    queue.removeWhere((element) => element.id == post.id);
    notifyListeners();
  }

  playPostFromQueue() async {
    await new Future.delayed(const Duration(seconds : 2));
    if(queue.length > 0) {
      PostPodItem currentPost = queue.removeAt(0);
      print('playing next post: ${currentPost.id}');
      playPost(currentPost);
    }
  }

  setPagePosts(List<Post> posts) {
    pagePosts = posts;
  }

  changeRecordingStatus() {
    isRecording = !isRecording;
    notifyListeners();
  }
  setRecordingTime(Duration duration) {
    recordingTime = duration;
    notifyListeners();
  }

  replyToEpisode(Episode episode, Podcast podcast, BuildContext context) {
    if(isPlaying) {
      pausePost();
    }
    showDialog(
      context: context,
      builder: (context) {
       return ReplyToEpisodeDialog(episode, podcast);
      }
    );
  }
}