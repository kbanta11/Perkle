import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/UserManagement.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:launch_review/launch_review.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:package_info/package_info.dart';
import 'package:podcast_search/podcast_search.dart';

import 'AddPostDialog.dart';
import 'LoginPage.dart';
import 'ShareToDialog.dart';
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
        FutureProvider<bool>(create: (_) => updateNeeded()),
      ],
      child: Consumer<FirebaseUser>(
        builder: (context, firebaseUser, _) {

          bool promptUpdate = Provider.of<bool>(context);
          print('Prompt Update: $promptUpdate');
          if(firebaseUser == null) {
            return MaterialApp(home: Scaffold(body: LoginPage()));
          }
          return StreamProvider<User>(
            create: (_) => UserManagement().streamCurrentUser(firebaseUser),
            child: Consumer<User>(
                builder: (context, user, _) {
                  //print('Temporary User: $userTemp/Firebase User: $firebaseUser');
                  print('Temp User Followed Podcasts: ${user != null ? user.followedPodcasts : ''}');
                  if(user == null) {
                    return Center(child: CircularProgressIndicator());
                  }
                  DBService().updateTimeline(timelineId: user.mainFeedTimelineId, user: user, reload: true);
                  return ChangeNotifierProvider<MainAppProvider>(
                      create: (_) => MainAppProvider(),
                      child: MaterialApp(
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
                        )) : HomePageMobile(),
                        routes: <String, WidgetBuilder> {
                          '/landingpage': (BuildContext context) => new MainApp(),
                          '/signup': (BuildContext context) => new SignUpPage(),
                          '/homepage': (BuildContext context) => new HomePageMobile(),
                          '/searchpage': (BuildContext context) => new SearchPageMobile(),
                          // '/dashboard': (BuildContext context) => new DashboardPage(),
                        },
                      )
                  );
                }
            ),
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
  String _postAudioPath;
  DateTime _startRecordDate;

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

    String localPath = await getApplicationDocumentsDirectory().then((directory) => directory.path);
    File localFile;

    if(await File('$localPath/local_data.json').exists()) {
      localFile = File('$localPath/local_data.json');
    } else {
      localFile = null;
    }

    Duration startDuration = new Duration(milliseconds: 0);
    if(localFile != null) {
      String localJsonString = await localFile.readAsString();
      Map<String, dynamic> localJsonMap = jsonDecode(localJsonString);
      print(localJsonMap);
      if(localJsonMap['posts_in_progress'] != null && localJsonMap['posts_in_progress'][newPostPod.audioUrl] != null) {
        int currentMs = localJsonMap['posts_in_progress'][newPostPod.audioUrl];
        if(currentMs >= 15000) {
          startDuration = new Duration(milliseconds: currentMs - 10000);
        }
      }
    }

    await player.play(newPostPod.audioUrl, position: startDuration).catchError((e) {
      print('Error playing post: $e');
    });
    if(newPostPod.type == PostType.DIRECT_POST) {
      FirebaseUser user = await FirebaseAuth.instance.currentUser();
      await DBService().markDirectPostHeard(conversationId: newPostPod.directPost.conversationId, userId: user.uid, postId: newPostPod.directPost.id);
    }

    player.onAudioPositionChanged.listen((event) {
      if(event != null) {
        activityManager.updateTimeListened(event, newPostPod.audioUrl);
      }
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
      //print('Duration ms: ${duration.inSeconds}/Position ms: ${position.inSeconds}');
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
      //print('Duration ms: ${duration.inSeconds}/Position ms: ${position.inSeconds}');
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
    //print('Pausing...');
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

  insertPostToQueueFirst(PostPodItem post) {
    queue.insert(0, post);
    notifyListeners();
  }

  addUnheardToQueue({String conversationId, String userId}) async {
    List<DirectPost> unheardPosts = List<DirectPost>();
    List<String> heardPostIDs = await DBService().getHeardPostIds(conversationId: conversationId, userId: userId);
    List<DirectPost> conversationPosts = await DBService().getDirectPosts(conversationId);
    unheardPosts = conversationPosts;
    if(heardPostIDs != null) {
      unheardPosts.removeWhere((DirectPost post) => heardPostIDs.contains(post.id));
    }
    unheardPosts.removeWhere((DirectPost post) => post.senderUID == userId);
    unheardPosts.forEach((DirectPost post) {
      PostPodItem newItem = PostPodItem.fromDirectPost(post);
      insertPostToQueueFirst(newItem);
    });
    playPostFromQueue();
  }

  removeFromQueue(PostPodItem post) {
    queue.removeWhere((element) => element.id == post.id);
    notifyListeners();
  }

  playPostFromQueue() async {
    await new Future.delayed(const Duration(seconds : 2));
    if(queue.length > 0) {
      PostPodItem currentPost = queue.removeAt(0);
      //print('playing next post: ${currentPost.id}');
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

  startRecording() async {
    if(isPlaying) {
      pausePost();
    }
    isRecording = true;
    List<dynamic> startRecordVals = await activityManager.startRecordNewPost(this);
    String postPath = startRecordVals[0];
    DateTime startDate = startRecordVals[1];
    _postAudioPath = postPath;
    _startRecordDate = startDate;
    notifyListeners();
  }

  stopRecording(BuildContext context) async {
    isRecording = false;
    List<dynamic> stopRecordVals = await activityManager.stopRecordNewPost(_postAudioPath, _startRecordDate);
    String recordingLocation = stopRecordVals[0];
    int secondsLength = stopRecordVals[1];
    print('$recordingLocation -/- Length: $secondsLength');
    DateTime date = new DateTime.now();
    notifyListeners();
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AddPostDialog(date: date, recordingLocation: recordingLocation, secondsLength: secondsLength,);
      }
    );
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

  shareToConversation(BuildContext context, {Episode episode, Podcast podcast, User user}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ShareToDialog(recordingLocation: episode.contentUrl, episode: episode, podcast: podcast, currentUser: user,);
      }
    );
  }
}