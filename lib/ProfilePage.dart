import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';
import 'services/models.dart';

import 'main.dart';
import 'MainPageTemplate.dart';
import 'PageComponents.dart';
import 'HomePage.dart';
import 'ListPage.dart';
import 'DiscoverPage.dart';
import 'Timeline.dart';

/*--------------------------------------------
class ProfilePage extends StatefulWidget {
  final String userId;
  ActivityManager activityManager;

  ProfilePage({Key key, @required this.userId, this.activityManager}) : super(key: key);

  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String userId;
  int _selectedIndex = 3;

  void _onItemTapped(int index) async {
    print('Activity Manager: ${widget.activityManager}');
    if(index == 0) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(activityManager: widget.activityManager,),
      ));
    }
    if(index == 1) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => DiscoverPage(activityManager: widget.activityManager),
      ));
    }
    if(index == 2) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ListPage(type: 'conversation', activityManager: widget.activityManager,),
      ));
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<String> _getUsername(String uid) async {
    return await Firestore.instance.collection('/users').document(uid).get().then((snapshot) async {
      return snapshot.data['username'].toString();
    });
  }

  @override
  void initState() {
    userId = widget.userId;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ActivityManager activityManager = widget.activityManager;
      return Scaffold(

        body: Container(
          child: Column(
            children: <Widget>[
              topPanel(context, activityManager),
              SizedBox(height: 5.0),
              UserInfoSection(userId: userId),
              Divider(height: 1.0),
              Expanded(
                child: TimelineSection(idMap: {'userId': userId}, activityManager: activityManager,),
              ),
            ]
          ),
        ),

        bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
      );
  }
}
----------------------------------------*/

//--------------------------------------------------
//New Version
class ProfilePageMobile extends StatelessWidget {
  String userId;

  ProfilePageMobile({this.userId});

  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return userId == null ? Center(child: CircularProgressIndicator(),) : MultiProvider(
      providers: [
        StreamProvider<User>(create: (_) => UserManagement().streamUserDoc(userId)),
      ],
      child: Consumer<User>(
          builder: (context, user, _) {
            return user == null ? Center(child: CircularProgressIndicator()) : MainPageTemplate(
                bottomNavIndex: 3,
                body: Column(
                  children: <Widget>[
                    UserInfoSection(userId: userId),
                    Divider(height: 5.0),
                    Expanded(
                      child: Timeline(userId: user.uid,)
                    )
                  ],
                ),
            );
          }
      ),
    );
  }
}