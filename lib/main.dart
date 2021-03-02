import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/UserManagement.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:launch_review/launch_review.dart';
//import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'package:package_info/package_info.dart';
import 'package:podcast_search/podcast_search.dart';
import 'services/local_services.dart';
import 'AddPostDialog.dart';
import 'LoginPage.dart';
//import 'PlayerTask.dart';
import 'ShareToDialog.dart';
import 'SignUpPage.dart';
import 'HomePage.dart';
import 'SearchPage.dart';
import 'ReplyToEpisode.dart';
import 'PlayerAudioHandler.dart';

AudioHandler _audioHandler;
FirebaseApp fbApp;


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  fbApp = await Firebase.initializeApp();
  _audioHandler = await AudioService.init(
    builder: () => PlayerAudioHandler(),
    config: AudioServiceConfig(
      androidNotificationChannelName: 'Perkl',
      androidNotificationOngoing: true,
      androidEnableQueue: true,
    ),
  );
  print('Audio Handler: $_audioHandler');
  runApp(new MainApp());
  print('app running');
}

class TestApp extends StatelessWidget {
  @override
  build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(body: Text('test'),)
    );
  }
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
  void initState() {
    super.initState();
    print('Main App init State');
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    print('Building Main App State');
    return fbApp == null ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 160,
              width: 160,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/images/logo.png')
                )
              ),
            ),
            SizedBox(height: 10),
            SpinKitPulse(size: 100, color: Colors.red,)
          ],
        )
    ) : MultiProvider(
      providers: [
        StreamProvider<User>(create: (_) => FirebaseAuth.instance.userChanges()),
        FutureProvider<bool>(create: (_) => updateNeeded()),
      ],
      child: Consumer<User>(
        builder: (context, firebaseUser, _) {

          bool promptUpdate = Provider.of<bool>(context);
          print('Prompt Update: $promptUpdate');
          if(firebaseUser == null) {
            return MaterialApp(theme: new ThemeData (
                primarySwatch: Colors.deepPurple
            ), home: Scaffold(body: LoginPage()));
          }
          return StreamProvider<PerklUser>(
            create: (_) => UserManagement().streamCurrentUser(firebaseUser),
            child: Consumer<PerklUser>(
                builder: (context, user, _) {
                  //print('Temporary User: $userTemp/Firebase User: $firebaseUser');
                  //print('Temp User Followed Podcasts: ${user != null ? user.followedPodcasts : ''}');
                  if(user == null) {
                    return Center(child: CircularProgressIndicator());
                  }
                  DBService().updateTimeline(timelineId: user.mainFeedTimelineId, user: user, reload: true);
                  return ChangeNotifierProvider<MainAppProvider>(
                      create: (_) => MainAppProvider(),
                      child: Consumer<MainAppProvider>(
                        builder: (context, map, _) {
                          DBService().syncConversationPostsHeard();
                          return MultiProvider(
                            providers: [
                              StreamProvider<PlaybackState>(create: (_) => _audioHandler.playbackState,),
                              StreamProvider<List<MediaItem>>(create: (_) => _audioHandler.queue),
                              StreamProvider<MediaItem>(create: (_) => _audioHandler.mediaItem),
                            ],
                            child: MaterialApp(
                              title: 'Perkl',
                              theme: new ThemeData (
                                  primarySwatch: Colors.deepPurple
                              ),
                              home: promptUpdate == null ?
                              Center(child: CircularProgressIndicator()) : promptUpdate ? Scaffold(body: Container(
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
                                            child: Text('Update Now!', style: TextStyle(color: Colors.white),),
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
                            ),
                          );
                        }
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
  //List<PostPodItem> queue = new List<PostPodItem>();
  List<Post> pagePosts;

  PostPodItem currentPostPodItem;
  String currentPostPodId;
  PostType currentPostType;
  //AudioPlayer player = new AudioPlayer();
  bool panelOpen = true;
  PostPosition position;
  PostDuration postLength;
  //For showing recording button time
  bool isRecording = false;
  Duration recordingTime;
  String _postAudioPath;
  DateTime _startRecordDate;

  playPost(PostPodItem newPostPod) async {
    MediaItem mediaItem = newPostPod.toMediaItem(FirebaseAuth.instance.currentUser.uid);
    _audioHandler.playMediaItem(mediaItem);
    notifyListeners();
  }

  playMediaItem(MediaItem mediaItem) async {
    _audioHandler.playMediaItem(mediaItem);
    notifyListeners();
  }

  stopPost() {
    //isPlaying = false;
    currentPostPodItem = null;
    _audioHandler.stop();
    notifyListeners();
  }

  resume() {
    _audioHandler.play();
    notifyListeners();
  }

  skipToNext() {
    _audioHandler.skipToNext();
    notifyListeners();
  }

  pausePost() {
    //print('Pausing...');
    //player.pause();
    _audioHandler.pause();
    //AudioService.pause();
    //isPlaying = false;
    notifyListeners();
  }

  rewind(Duration interval) {
    _audioHandler.rewind(interval);
    notifyListeners();
  }

  fastForward(Duration interval) {
    _audioHandler.fastForward(interval);
    notifyListeners();
  }


  updatePanelState() {
    panelOpen = !panelOpen;
    notifyListeners();
  }

  addPostToQueue(PostPodItem post) async {
    MediaItem mediaItem = post.toMediaItem(FirebaseAuth.instance.currentUser.uid);
    _audioHandler.addQueueItem(mediaItem);
    /*
    if(!AudioService.running) {
      await AudioService.start(
        backgroundTaskEntrypoint: _backgroundTaskEntrypoint,
        params: {'mediaItem': mediaItem.toJson()},
      );
    } else {
      AudioService.addQueueItem(mediaItem);
    }
    */
    //queue.add(post);
    notifyListeners();
  }

  insertPostToQueueFirst(PostPodItem post) async {
    MediaItem mediaItem = post.toMediaItem(FirebaseAuth.instance.currentUser.uid);
    //queue.insert(0, post);
    print('Media Item: $mediaItem');
    _audioHandler.insertQueueItem(0, mediaItem);
    //AudioService.addQueueItemAt(mediaItem, 0);
    notifyListeners();
  }

  addUnheardToQueue({String conversationId, String userId}) async {
    /*
    if(!AudioService.running) {
      await AudioService.start(
        backgroundTaskEntrypoint: _backgroundTaskEntrypoint,
        params: {},
      );
    }
     */

    List<DirectPost> unheardPosts = List<DirectPost>();
    List<String> heardPostIDs = await DBService().getHeardPostIds(conversationId: conversationId, userId: userId);
    List<DirectPost> conversationPosts = await DBService().getDirectPosts(conversationId);
    unheardPosts = conversationPosts;
    if(heardPostIDs != null) {
      unheardPosts.removeWhere((DirectPost post) => heardPostIDs.contains(post.id));
    }
    unheardPosts.removeWhere((DirectPost post) => post.senderUID == userId);
    //print('Unheard posts: $unheardPosts');
    List<MediaItem> currentQueue = _audioHandler.queue.value;
    List<MediaItem> unheardMediaItems = unheardPosts.map((item) {
      PostPodItem post = PostPodItem.fromDirectPost(item);
      MediaItem mediaItem = post.toMediaItem(FirebaseAuth.instance.currentUser.uid);
      return mediaItem;
    }).toList();
    //print('Unheard media items: $unheardMediaItems');
    if(currentQueue == null || currentQueue.length == 0) {
      print('setting queue to just unheard items: $unheardMediaItems');
      await _audioHandler.updateQueue(unheardMediaItems.reversed.toList());
    } else {
      print('adding unheard to current queue');
      currentQueue.insertAll(0, unheardMediaItems.reversed.toList());
      await _audioHandler.updateQueue(currentQueue);
    }
    /*
    unheardPosts.forEach((DirectPost post) {
      PostPodItem newItem = PostPodItem.fromDirectPost(post);
      insertPostToQueueFirst(newItem);
    });
     */
    await _audioHandler.skipToNext();
  }

  removeFromQueue(PostPodItem post) {
    MediaItem mediaItem = post.toMediaItem(FirebaseAuth.instance.currentUser.uid);
    //queue.removeWhere((element) => element.id == post.id);
    _audioHandler.removeQueueItem(mediaItem);
    //AudioService.removeQueueItem(mediaItem);
    notifyListeners();
  }

  removeQueueItem(MediaItem item) {
    _audioHandler.removeQueueItem(item);
    //AudioService.removeQueueItem(mediaItem);
    notifyListeners();
  }

  setSpeed(double speed) {
    _audioHandler.setSpeed(speed);
    notifyListeners();
  }

  setPagePosts(List<Post> posts) {
    pagePosts = posts;
  }

  changeRecordingStatus() {
    isRecording = !isRecording;
    notifyListeners();
  }

  startRecording() async {
    if(_audioHandler.playbackState != null && _audioHandler.playbackState.value.playing) {
      pausePost();
    }
    isRecording = true;
    print('starting recorder...');
    List<dynamic> startRecordVals = await activityManager.startRecordNewPost(this);
    print('Start Record Vals: $startRecordVals');
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
    if(_audioHandler.playbackState.value.playing) {
      pausePost();
    }
    showDialog(
      context: context,
      builder: (context) {
       return ReplyToEpisodeDialog(episode, podcast);
      }
    );
  }

  shareToConversation(BuildContext context, {Episode episode, Podcast podcast, PerklUser user}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ShareToDialog(recordingLocation: episode.contentUrl, episode: episode, podcast: podcast, currentUser: user,);
      }
    );
  }
}