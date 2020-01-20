import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:async';
import 'PageComponents.dart';
import 'ProfilePage.dart';
import 'ListPage.dart';
import 'DiscoverPage.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class HomePage extends StatefulWidget {
  ActivityManager activityManager;

  HomePage({Key key, this.activityManager}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Future<FirebaseUser> currentUser = FirebaseAuth.instance.currentUser();
  DocumentReference userDoc;
  int _selectedIndex = 0;
  ActivityManager _activityManager;
  final Firestore _db = Firestore.instance;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  StreamSubscription iosSubscription;

  _saveDeviceToken() async {
    // Get the current user
    String uid = await FirebaseAuth.instance.currentUser().then((user) {
      return user.uid;
    });
    // FirebaseUser user = await _auth.currentUser();

    // Get the token for this device
    String userToken = await _firebaseMessaging.getToken();

    // Save it to Firestore
    if (userToken != null) {
      var tokens = _db
          .collection('users')
          .document(uid)
          .collection('tokens')
          .document(userToken);

      await tokens.setData({
        'token': userToken,
        'createdAt': FieldValue.serverTimestamp(), // optional
        'platform': Platform.operatingSystem // optional
      });
    }
  }

  void _onItemTapped(int index, {ActivityManager actManage}) async {
    print('Activity Manager: $actManage');
    String uid = await _getUID();
    if(index == 3) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid, activityManager: actManage),
      ));
    }
    if(index == 2) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ListPage(type: 'conversation', activityManager: actManage),
      ));
    }
    if(index == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DiscoverPage(activityManager: actManage),
      ));
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<String> _getUID() async {
    return await currentUser.then((user) async {
      return user.uid.toString();
    });
  }

  _HomePageState () {
    UserManagement().getUserData().then((DocumentReference doc) => setState(() {
      userDoc = doc;
    }));
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _showUsernameDialog(context);
    });
    if (Platform.isIOS) {
      iosSubscription = _firebaseMessaging.onIosSettingsRegistered.listen((data) {
        // save the token  OR subscribe to a topic here
      });

      _firebaseMessaging.requestNotificationPermissions(IosNotificationSettings());
    }

    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> message) async {
        print("onMessage: $message");
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            content: ListTile(
              title: Text(message['notification']['title']),
              subtitle: Text(message['notification']['body']),
            ),
            actions: <Widget>[
              FlatButton(
                child: Text('Ok'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
        // TODO optional
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
        // TODO optional
      },
    );
    _saveDeviceToken();
  }

  @override
  Widget build(BuildContext context) {
    if(widget.activityManager == null)
      _activityManager = new ActivityManager();
    else
      _activityManager = widget.activityManager;

    if (currentUser == null) {
      Navigator.of(context).pushReplacementNamed('/landingpage');
    }

    return new Scaffold(
      body: Container(
          child: Stack(
            children: <Widget>[
              new Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  topPanel(context, _activityManager),
                  Expanded(
                    child:  Padding(
                        padding: EdgeInsets.only(top: 5.0, right: 5.0, left: 5.0, bottom: 5.0),
                        child:Container(
                          child: new FutureBuilder(
                              future: UserManagement().getUserData().then((document) {
                                return document.get().then((snapshot) {
                                  return snapshot.data['mainFeedTimelineId'].toString();
                                });
                              }),
                              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                                if(snapshot == null || snapshot.data == 'null')
                                  return Text('Your feed is empty! Start following users to fill your feed.');
                                print('Setting timeline id: ${snapshot.data}');
                                return  TimelineSection(idMap: {'timelineId': snapshot.data}, activityManager: _activityManager,);
                              }
                          ),
                        )
                    ),
                  ),
                ],
              ),
              Positioned.fill(
                top: 180.0,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: PlaylistControls(activityManager: _activityManager)
                ),
              ),
            ],
          ),
        ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex, activityManager: _activityManager),
    );
  }
}


// Show Username dialog
Future<void> _showUsernameDialog(BuildContext context) async {
  String username = await UserManagement().getUserData().then((DocumentReference doc) {
    return doc.get().then((DocumentSnapshot snapshot) {
      return snapshot.data['username'].toString();
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





