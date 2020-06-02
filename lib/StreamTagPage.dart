import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'PageComponents.dart';
import 'ProfilePage.dart';
import 'ListPage.dart';
import 'HomePage.dart';
import 'Timeline.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

/*------------------------
class StreamTagPage extends StatefulWidget {
  final ActivityManager activityManager;
  final String tag;

  StreamTagPage({Key key, @required this.activityManager, @required this.tag}) : super(key: key);

  @override
  _StreamTagPageState createState() => new _StreamTagPageState();
}

class _StreamTagPageState extends State<StreamTagPage> {

  void _onItemTapped(int index, {ActivityManager actManage}) async {
    print('Activity Manager: $actManage');
    String uid = await UserManagement().getUID();
    if(index == 3) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid, activityManager: widget.activityManager),
      ));
    }
    if(index == 2) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ListPage(type: 'conversation', activityManager: widget.activityManager),
      ));
    }
    if(index == 0) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(activityManager: widget.activityManager)
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Stream tag on page - ${widget.tag}');
    return Scaffold(
      body: Column(
        children: <Widget>[
          topPanel(context, widget.activityManager, pageTitle: '#${widget.tag}'),
          Expanded(
            child: Padding(
              padding: EdgeInsets.fromLTRB(5, 5, 5, 5),
              child: Container(
                child: TimelineSection(activityManager: widget.activityManager, streamTag: widget.tag,)
              )
            )
          ),
        ]
      ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, 0, noSelection: true),
    );
  }
}
-------------------------------*/


//New Version
class StreamTagPageMobile extends StatelessWidget {
  String tag;

  StreamTagPageMobile({this.tag});

  @override
  build(BuildContext context) {
    return MainPageTemplate(
      bottomNavIndex: 1,
      pageTitle: tag ?? '',
      body: tag == null ? Center(child: Text('No Tag Selected')) : Timeline(tagStream: DBService().streamTagPosts(tag),),
    );
  }
}