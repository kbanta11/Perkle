import 'dart:convert';

import 'package:Perkl/main.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share/share.dart';
import 'dart:io';
import 'dart:async';
import 'MainPageTemplate.dart';
import 'PageComponents.dart';
import 'ProfilePage.dart';
import 'ListPage.dart';
import 'DiscoverPage.dart';
import 'ConversationPage.dart';
import 'Timeline.dart';

import 'TutorialDialog.dart';
import 'services/models.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'services/local_services.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

List<Map<String, dynamic>> currentTutorials = [{'index': 0, 'file': 'https://firebasestorage.googleapis.com/v0/b/flutter-fire-test-be63e.appspot.com/o/AppFiles%2FPerkl_Tutorial-Posting.mp4?alt=media&token=4b25145f-64de-4b92-bd52-1bb6a083c375', 'text': 'How To Post'},
  {'index': 1, 'file': 'https://firebasestorage.googleapis.com/v0/b/flutter-fire-test-be63e.appspot.com/o/AppFiles%2FPerkl_Tutorial-Following.mp4?alt=media&token=f9c9c761-db53-4b4c-bce2-e81365377c31', 'text': 'Finding and Following'},
  {'index': 2, 'file': 'https://firebasestorage.googleapis.com/v0/b/flutter-fire-test-be63e.appspot.com/o/AppFiles%2FPerkl_Tutorial-Conversation.mp4?alt=media&token=85f46bad-23dc-4461-b410-ed3aff12f4a9', 'text': 'Conversation on Perkl'}
  ];

//HomePage Provider Rebuild
class HomePageMobile extends StatefulWidget {
  bool? redirectOnNotification;

  HomePageMobile({Key? key, this.redirectOnNotification}) : super(key: key);

  @override
  HomePageMobileState createState() => HomePageMobileState();
}

class HomePageMobileState extends State<HomePageMobile> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  StreamSubscription? iosSubscription;

  _saveDeviceToken() async {
    // Get the current user
    String? uid = FirebaseAuth.instance.currentUser?.uid;
    // FirebaseUser user = await _auth.currentUser();

    // Get the token for this device
    String? userToken = await _firebaseMessaging.getToken();

    // Save it to Firestore
    if (userToken != null && uid != null) {
      DBService().updateDeviceToken(userToken, uid);
    }
  }

  Future<bool> showTutorial() async {
    LocalService localService = new LocalService();
    int tutorialComplete = await localService.getData('tutorial_version');
    if(tutorialComplete == null) {
      return true;
    }
    //change tutorial version
    if(tutorialComplete >= 1) {
      return false;
    }
    return true;
    /*
    List<dynamic> tutorialCompleted = await localService.getData('tutorial_index_complete');
    print('Tutorials Completed: $tutorialCompleted');
    if(tutorialCompleted == null) {
      return currentTutorials;
    } else {
      //List<int> tutorialsToComplete = CURRENT_TUTORIAL_INDICES.removeWhere((element) => tutorialCompleted.contains(element));
      //Get current tutorials whose index is not the index of a completed tutorial
      if(currentTutorials.where((element) => !tutorialCompleted.map((completed) => completed['index']).toList().contains(element['index'])).length > 0) {
        print('Already completed index list: ${tutorialCompleted.map((completed) => completed['index']).toList()}');
        print('Unheard tutorials: ${currentTutorials.where((element) {
          List<dynamic> completedIndices = tutorialCompleted.map((completed) => completed['index']).toList();
         return !(completedIndices.contains(element['index']));
        })}');
        return currentTutorials.where((element) => !tutorialCompleted.map((completed) => completed['index']).toList().contains(element['index'])).toList();
      }
    }
    //Change to show tutorial screens for production
    return null; //return tutorialCompleted?
     */
  }

  Future<void> promptShare(BuildContext context) async {
    int? lastPromptedMilliseconds = await LocalService().getData('lastPromptedMilliseconds');
    if(lastPromptedMilliseconds == null) {
      WidgetsBinding.instance?.addPostFrameCallback((timeStamp) async {
        await showDialog(
          context: context,
          builder: (context) {
            return SimpleDialog(
              contentPadding: EdgeInsets.all(15),
              title: Center(child: Text('Invite your Friends!')),
              children: [
                Center(child: Text('The perfect way to get started is to invite your friends to join you!', textAlign: TextAlign.center,)),
                SizedBox(height: 10,),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        child: Text('Not now.'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      ),
                      TextButton(
                        child: Text('Share!', style: TextStyle(color: Colors.white)),
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                        ),
                        onPressed: () {
                          Share.share('Hey! I wanna hear your voice! Join me on Perkl @ https://www.perklapp.com', subject: 'Hey! Join me on Perkl!');
                        },
                      )
                    ]
                ),
              ],
            );
          }
        ).then((_) {
          LocalService().setData('lastPromptedMilliseconds', DateTime.now().millisecondsSinceEpoch);
        });
      });
    } else {
      if(DateTime.now().millisecondsSinceEpoch - lastPromptedMilliseconds > 604800000) {
        WidgetsBinding.instance?.addPostFrameCallback((timeStamp) async {
          await showDialog(
              context: context,
              builder: (context) {
                return SimpleDialog(
                  contentPadding: EdgeInsets.all(15),
                  title: Center(child: Text('Invite your Friends!')),
                  children: [
                    Center(child: Text('Liking Perkl? Invite your friends to come join you!', textAlign: TextAlign.center)),
                    Row(
                      children: [
                        FlatButton(
                          child: Text('Not now.'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        FlatButton(
                          child: Text('Share!'),
                          color: Colors.deepPurple,
                          onPressed: () {
                            Share.share('Hey! I wanna hear your voice! Join me on Perkl @ https://www.perklapp.com', subject: 'Hey! Join me on Perkl!');
                          },
                        )
                      ]
                    ),
                  ],
                );
              }
          ).then((_) {
            LocalService().setData('lastPromptedMilliseconds', DateTime.now().millisecondsSinceEpoch);
          });
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    promptShare(context).then((_) {
      showTutorial();
    });

    //showTutorial().then((_) {
    //  promptShare(context);
    //});
    //print('Skipping checking username');
    _saveDeviceToken();
  }

  @override
  build(BuildContext context) {
    User? firebaseUser = Provider.of<User?>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PerklUser? user = Provider.of<PerklUser?>(context);
    DBService().updateTimeline(timelineId: user?.mainFeedTimelineId, user: user, reload: false);
    if(user == null)
      return Center(child: CircularProgressIndicator());
    if(user.username == null || user.username?.length == 0) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage("assets/images/drawable-xxxhdpi/login-bg.png"),
              fit: BoxFit.cover,
            ),
          ),
          child: WillPopScope(
            onWillPop: () async => false,
            child: UsernameDialog(),
          ),
        ),
      );
    }

    return FutureBuilder(
      future: showTutorial(),
      builder: (context, AsyncSnapshot<bool> showSnap) {
        if(showSnap.hasData && (showSnap.data ?? false)) {
          print('### Snap Data: ${showSnap.data}');
          return TutorialPage();
        }
        return MainPageTemplate(
            bottomNavIndex: 0,
            body: Timeline(timelineId: user.mainFeedTimelineId, type: TimelineType.MAINFEED,)
        );
      }
    );
  }
}

