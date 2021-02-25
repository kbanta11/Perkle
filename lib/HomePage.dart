import 'dart:convert';

import 'package:Perkl/main.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
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
import 'package:flushbar/flushbar.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Show Username dialog
Future<void> _showUsernameDialog(BuildContext context) async {
  String username = await UserManagement().getUserData().then((DocumentReference doc) {
    return doc.get().then((DocumentSnapshot snapshot) {
      return snapshot.data()['username'].toString();
    });
  });
  print('username (in dialog): $username-------------');
  if (username == null || username == '' || username == 'null'){
    print('showing username dialog-----------');
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return new WillPopScope(
            onWillPop: () async => false,
            child: UsernameDialog(),
          );
        }
    );
  } else {
    print('show dialog if evaluating false');
  }
  print('show dialog if state skipped?');
  return null;
}

//HomePage Provider Rebuild
class HomePageMobile extends StatefulWidget {
  bool redirectOnNotification;

  HomePageMobile({Key key, this.redirectOnNotification}) : super(key: key);

  @override
  HomePageMobileState createState() => HomePageMobileState();
}

class HomePageMobileState extends State<HomePageMobile> {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  StreamSubscription iosSubscription;

  _saveDeviceToken() async {
    // Get the current user
    String uid = FirebaseAuth.instance.currentUser.uid;
    // FirebaseUser user = await _auth.currentUser();

    // Get the token for this device
    String userToken = await _firebaseMessaging.getToken();

    // Save it to Firestore
    if (userToken != null && uid != null) {
      DBService().updateDeviceToken(userToken, uid);
    }
  }

  Future<bool> showTutorial() async {
    LocalService localService = new LocalService();
    bool tutorialCompleted = await localService.getData('tutorial_complete') ?? false;

    //Change to show tutorial screens for production
    return true; //return tutorialCompleted?
  }

  @override
  void initState() {
    super.initState();
    showTutorial().then((show) {
      if(!show) {
        WidgetsBinding.instance.addPostFrameCallback((_) async {
          await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                return TutorialDialog();
              }
          );
        });
      }
    });
    //print('Skipping checking username');
    _saveDeviceToken();
  }

  @override
  build(BuildContext context) {
    User firebaseUser = Provider.of<User>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PerklUser user = Provider.of<PerklUser>(context);
    DBService().updateTimeline(timelineId: user.mainFeedTimelineId, user: user, reload: false);
    if(user == null)
      return Center(child: CircularProgressIndicator());
    if(user.username == null || user.username.length == 0) {
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

    return MainPageTemplate(
        bottomNavIndex: 0,
        body: Timeline(timelineId: user.mainFeedTimelineId, type: TimelineType.MAINFEED,)
    );
  }
}

