//import 'dart:convert';
import 'package:Perkl/main.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'AddPostDialog.dart';
import 'ConversationPage.dart';
import 'MainPageTemplate.dart';
//import 'PageComponents.dart';
//import 'HomePage.dart';
//import 'ProfilePage.dart';
//import 'DiscoverPage.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';


//New Version
class ConversationListPageMobile extends StatelessWidget {
  @override
  build(BuildContext context) {
    User firebaseUser = Provider.of<User>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PerklUser currentUser = Provider.of<PerklUser>(context);
    return MultiProvider(
      providers: [
        StreamProvider<PerklUser>(create: (_) => UserManagement().streamCurrentUser(firebaseUser)),
        StreamProvider<List<Conversation>>(create: (_) => DBService().streamConversations(firebaseUser.uid)),
      ],
      child: Consumer<List<Conversation>>(
        builder: (context, conversations, _) {
          PerklUser user = Provider.of<PerklUser>(context);
          List<DayPosts> days = <DayPosts>[];
          if(conversations != null) {
            conversations.forEach((convo) {
              if(days.where((d) => d.date.year == convo.lastDate.year && d.date.month == convo.lastDate.month && d.date.day == convo.lastDate.day).length > 0) {
                days.where((d) => d.date.year == convo.lastDate.year && d.date.month == convo.lastDate.month && d.date.day == convo.lastDate.day).first.list.add(convo);
              } else {
                List list = [];
                list.add(convo);
                days.add(DayPosts(date: DateTime(convo.lastDate.year, convo.lastDate.month, convo.lastDate.day), list: list));
              }
            });
          }
          return MainPageTemplate(
            bottomNavIndex: 2,
            body: Stack(
              children: <Widget>[
                conversations == null ? Center(child: Text('You haven\'t started any conversations yet!'))
                    : ListView(
                  children: days.map((day) {
                    return Container(
                      margin: EdgeInsets.only(left: 10, bottom: 10),
                      padding: EdgeInsets.only(left: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: Colors.deepPurple[500], width: 2)
                        )
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(day.date.year == DateTime.now().year && day.date.month == DateTime.now().month && day.date.day == DateTime.now().day ? 'Today' : DateFormat('MMMM dd, yyyy').format(day.date), style: TextStyle(fontSize: 16, color: Colors.deepPurple[500]),),
                          user == null ? Center(child: CircularProgressIndicator()) : Column(
                            children: day.list.map((conversation) {
                              Conversation convo = conversation;
                              String firstOtherUid = convo.memberList.where((item) => item != user.uid).first;
                              int unreadPosts = convo.conversationMembers[firebaseUser.uid]['unreadPosts'];
                              print('conversation: ${convo.id}/Unheard Posts: ${unreadPosts}');
                              if(unreadPosts == null) {
                                unreadPosts = 0;
                              }


                              return Card(
                                  elevation: 5,
                                  margin: EdgeInsets.all(5),
                                  child: Padding(
                                      padding: EdgeInsets.all(5),
                                      child: InkWell(
                                        child: Row(
                                          children: <Widget>[
                                            StreamProvider<PerklUser>(
                                                create: (context) => UserManagement().streamUserDoc(firstOtherUid),
                                                child: Consumer<PerklUser>(
                                                  builder: (context, firstUser, _) {
                                                    if(firstUser == null || firstUser.profilePicUrl == null)
                                                      return Container(
                                                          height: 60.0,
                                                          width: 60.0,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Colors.deepPurple,
                                                          )
                                                      );
                                                    return Container(
                                                        height: 60.0,
                                                        width: 60.0,
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: Colors.deepPurple,
                                                          image: DecorationImage(
                                                            fit: BoxFit.cover,
                                                            image: NetworkImage(firstUser.profilePicUrl),
                                                          ),
                                                        )
                                                    );
                                                  },
                                                )
                                            ),
                                            SizedBox(width: 5),
                                            Expanded(child: Text('${conversation.getTitle(currentUser)}', style: TextStyle(fontSize: 18))),
                                            SizedBox(width: 5),
                                            Row(
                                              children: <Widget>[
                                                FaIcon(unreadPosts > 0 ? FontAwesomeIcons.solidComments : FontAwesomeIcons.comments,
                                                  color: Colors.deepPurple,
                                                  size: 24,
                                                ),
                                                SizedBox(width: 5),
                                                Container(
                                                  width: 30,
                                                  height: 30,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: Colors.deepPurple,
                                                  ),
                                                  child: InkWell(
                                                    child: Center(child: FaIcon(FontAwesomeIcons.play, color: Colors.white, size: 14,)),
                                                    onTap: () async {
                                                      await mp.addUnheardToQueue(conversationId: conversation.id, userId: firebaseUser.uid);
                                                    },
                                                  ),
                                                ),
                                                SizedBox(width: 5),
                                                Container(
                                                  height: 30,
                                                  width: 30,
                                                  decoration: BoxDecoration(
                                                      color: Colors.red,
                                                      shape: BoxShape.circle
                                                  ),
                                                  child: InkWell(
                                                    child: Center(child: Icon(Icons.mic, color: Colors.white)),
                                                    onTap: () async {
                                                      await ActivityManager().sendDirectPostDialog(context, conversationId: conversation.id);
                                                    },
                                                  ),
                                                )
                                              ],
                                            ),
                                          ]
                                        ),
                                        onTap: () {
                                          //print('go to conversation: ${convoItem.targetUsername} (${convoItem.conversationId})');
                                          DBService().markConversationRead(conversation.id, firebaseUser.uid);
                                          Navigator.push(context, MaterialPageRoute(
                                            builder: (context) => ConversationPageMobile(conversationId: conversation.id, pageTitle: conversation.getTitle(currentUser)),
                                          ));
                                        },
                                   ),
                                  )
                              );
                            }).toList(),
                          )
                        ],
                      )
                    );
                  }).toList(),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      backgroundColor: Colors.deepPurple,
                    ),
                    child: Text('New Conversation', style: TextStyle(color: Colors.white)),
                    onPressed: () async {
                      //Record new post and show list to send to users
                      await showDialog(
                        context: context,
                        builder: (context) {
                          return AddPostDialog();
                        }
                      );
                    },
                  ),
                )
              ],
            ),
          );
        },
      ),
    );
  }
}