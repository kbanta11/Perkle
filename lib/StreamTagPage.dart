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


//New Version
class StreamTagPageMobile extends StatelessWidget {
  String tag;

  StreamTagPageMobile({this.tag});

  @override
  build(BuildContext context) {
    return MainPageTemplate(
      bottomNavIndex: 1,
      pageTitle: tag ?? '',
      body: tag == null ? Center(child: Text('No Tag Selected')) : Timeline(tagStream: DBService().streamTagPosts(tag), type: TimelineType.STREAMTAG),
    );
  }
}