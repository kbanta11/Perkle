import 'dart:convert';

import 'package:Perkl/main.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'ConversationPage.dart';
import 'MainPageTemplate.dart';
import 'PageComponents.dart';
import 'HomePage.dart';
import 'ProfilePage.dart';
import 'DiscoverPage.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

/*------------------------------------
class ListPage extends StatefulWidget {
  final String type;
  ActivityManager activityManager;

  ListPage({Key key, @required this.type, this.activityManager}) : super(key: key);

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  int _selectedIndex = 2;

  void _onItemTapped(int index) async {
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
    if(index == 3) {
      String uid = await UserManagement().getUserData().then((DocumentReference docRef) {
        return docRef.documentID;
      });
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid, activityManager: widget.activityManager),
      ));
    }
    setState(() {
      _selectedIndex = index;
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          topPanel(context, widget.activityManager),
          Expanded(
            child: FutureBuilder(
              future: UserManagement().getUserData().then((snapshot) => snapshot.documentID),
              builder: (BuildContext context, AsyncSnapshot<String> uidSnap) {
                if(uidSnap.hasData) {
                  return StreamBuilder(
                      stream: Firestore.instance.collection('conversations').where('memberList', arrayContains: uidSnap.data.toString()).orderBy('lastDate', descending: true).snapshots(),
                      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                        if(snapshot.hasData) {
                          if(snapshot.data.documents.length == 0)
                            return Center(child: Text('You have no conversations!'));

                          List<ConversationListObject> conversationList;
                          return ListView(
                              scrollDirection: Axis.vertical,
                              children: snapshot.data.documents.map((document) {
                                // print('Conversation Item TargetUID: ${convoItem.targetUid}');
                                List<dynamic> memberList = document.data['memberList'];
                                String firstOtherUID = memberList.where((item) {
                                  return item != uidSnap.data.toString();
                                }).first;

                                String titleText = '';
                                Map<dynamic, dynamic> memberDetails = document.data['conversationMembers'];
                                if(memberDetails != null){
                                  memberDetails.forEach((key, value) {
                                    if(key != uidSnap.data) {
                                      if(titleText.length > 0)
                                        titleText = titleText + ', ' + value['username'];
                                      else
                                        titleText = value['username'];
                                    }
                                  });
                                }

                                if(titleText.length > 50){
                                  titleText = titleText.substring(0,47) + '...';
                                }

                                int unreadPosts = 0;
                                Map<dynamic, dynamic> userDetails = memberDetails[uidSnap.data.toString()];
                                if(userDetails != null) {
                                  unreadPosts = userDetails['unreadPosts'];
                                  print('Unread Posts: $unreadPosts');
                                }

                                Widget unheardIndicator = Container(height: 0.1,width: 0.1,);
                                if(unreadPosts > 0)
                                  unheardIndicator = Container(
                                    height: 20.0,
                                    width: 20.0,
                                    child: Center(child: Text('$unreadPosts', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),)),
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.red
                                    ),
                                  );

                                return Column(
                                  children: <Widget>[
                                    Padding(
                                        padding: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 5.0),
                                        child: ListTile(
                                            leading: StreamBuilder(
                                                stream: Firestore.instance.collection('users').document(firstOtherUID).snapshots(),
                                                builder: (context, snapshot) {
                                                  if(snapshot.hasData) {
                                                    String picUrl = snapshot.data['profilePicUrl'];
                                                    if(picUrl != null)
                                                      return Container(
                                                          height: 60.0,
                                                          width: 60.0,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Colors.deepPurple,
                                                            image: DecorationImage(
                                                              fit: BoxFit.cover,
                                                              image: NetworkImage(picUrl.toString()),
                                                            ),
                                                          )
                                                      );
                                                  }
                                                  return Container(
                                                      height: 60.0,
                                                      width: 60.0,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: Colors.deepPurple,
                                                      )
                                                  );
                                                }
                                            ),
                                            title: Text(titleText),
                                            trailing: Stack(
                                              children: <Widget>[
                                                Container(
                                                  height: 60.0,
                                                  width: 60.0,
                                                  child: Icon(Icons.speaker_group, color: Colors.deepPurple, size: 50.0,)
                                                ),
                                                unheardIndicator,
                                              ],
                                            ),
                                            onTap: () {
                                              //print('go to conversation: ${convoItem.targetUsername} (${convoItem.conversationId})');
                                              Navigator.push(context, MaterialPageRoute(
                                                builder: (context) => ConversationPage(conversationId: document.reference.documentID, activityManager: widget.activityManager),
                                              ));
                                            }
                                        )
                                    ),
                                    Divider(height: 5.0),
                                  ],
                                );
                             }).toList(),
                          );
                        }
                        return Center(
                            child: Container(
                              height: 50.0,
                              width: 50.0,
                              child: CircularProgressIndicator(),
                            )
                        );
                      }
                  );
                } else {
                  return Container();
                }
              },
            ),
          )
        ]
      ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
    );
  }
}
------------------------------------------------------*/

//New Version
class ConversationListPageMobile extends StatelessWidget {
  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return MultiProvider(
      providers: [
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser)),
        StreamProvider<List<Conversation>>(create: (_) => DBService().streamConversations(firebaseUser.uid)),
      ],
      child: Consumer<List<Conversation>>(
        builder: (context, conversations, _) {
          User user = Provider.of<User>(context);
          return MainPageTemplate(
            bottomNavIndex: 2,
            body: conversations == null ? Center(child: Text('You haven\'t started any conversations yet!'))
              : ListView(
              children: conversations.map((conversation) {
                String firstOtherUid = conversation.memberList.where((item) => item != user.uid).first;
                String titleText = '';
                int unreadPosts = 0;
                conversation.conversationMembers.forEach((key, userData) {
                  if(key != user.uid) {
                    if(titleText.length > 0) {
                      titleText = '$titleText, ${userData['username']}';
                    } else {
                      titleText = '${userData['username']}';
                    }
                  } else {
                    unreadPosts = userData['unreadPosts'] ?? 0;
                  }
                });

                return Card(
                  elevation: 5,
                  margin: EdgeInsets.all(5),
                  child: Padding(
                    padding: EdgeInsets.all(5),
                    child: ListTile(
                        leading: StreamProvider<User>(
                            create: (context) => UserManagement().streamUserDoc(firstOtherUid),
                            child: Consumer<User>(
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
                        title: Text('$titleText', style: TextStyle(fontSize: 18)),
                        trailing: FaIcon(unreadPosts > 0 ? FontAwesomeIcons.solidComments : FontAwesomeIcons.comments,
                          color: Colors.deepPurple,
                          size: 24,
                        ),
                        onTap: () {
                          //print('go to conversation: ${convoItem.targetUsername} (${convoItem.conversationId})');
                          DBService().markConversationRead(conversation.id, firebaseUser.uid);
                          Navigator.push(context, MaterialPageRoute(
                            builder: (context) => ConversationPageMobile(conversationId: conversation.id),
                          ));
                        }
                    )
                  )
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}