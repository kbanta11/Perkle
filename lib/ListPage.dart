import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ConversationPage.dart';
import 'PageComponents.dart';
import 'HomePage.dart';
import 'ProfilePage.dart';

import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

class ListPage extends StatefulWidget {
  final String type;

  ListPage({Key key, @required this.type}) : super(key: key);

  @override
  _ListPageState createState() => _ListPageState();
}

class _ListPageState extends State<ListPage> {
  int _selectedIndex = 2;

  void _onItemTapped(int index) async {
    if(index == 0) {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => HomePage(),
      ));
    }
    if(index == 3) {
      String uid = await UserManagement().getUserData().then((DocumentReference docRef) {
        return docRef.documentID;
      });
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => ProfilePage(userId: uid),
      ));
    }
    setState(() {
      _selectedIndex = index;
    });

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: new AppBar(
          title: widget.type != 'conversation' ? Text('Streams') : Text('Conversations'),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back),
            color: Colors.white,
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
          actions: <Widget>[
            FlatButton(
                child: Text('Logout'),
                textColor: Colors.white,
                onPressed: () {
                  FirebaseAuth.instance.signOut().then((value) {
                    Navigator.of(context).pushReplacementNamed('/landingpage');
                  })
                      .catchError((e) {
                    print(e);
                  });
                }
            ),
          ]
      ),
      body: Container(
        child: FutureBuilder(
          future: UserManagement().getUserData(),
          builder: (BuildContext context, AsyncSnapshot<DocumentReference> futureSnap) {
            if(futureSnap.hasData) {
              return StreamBuilder(
                  stream: futureSnap.data.snapshots(),
                  builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                    Map<String, dynamic> conversationMap = Map<String, dynamic>.from(snapshot.data.data['directConversationMap']);
                    if(conversationMap == null)
                      return Center(child: Text('You have no conversations!'));

                    List<ConversationListObject> conversationList;
                    conversationMap.forEach((key, value) {
                      String _targetUid = key;
                      String _targetUsername = value['targetUsername'];
                      String _conversationId = value['conversationId'];
                      int _unreadPosts = value['unreadPosts'];

                      conversationList == null ? conversationList = [ConversationListObject(_targetUid, _targetUsername, _conversationId, _unreadPosts)] : conversationList.add(ConversationListObject(_targetUid, _targetUsername, _conversationId, _unreadPosts));
                    });
                    return ListView.builder(
                        itemCount: conversationMap.length,
                        itemBuilder: (context, index) {
                          ConversationListObject convoItem = conversationList[index];
                          print('Conversation Item TargetUID: ${convoItem.targetUid}');
                          return Column(
                            children: <Widget>[
                              ListTile(
                                  title: Text(convoItem.targetUsername),
                                  trailing: Text('Unread Posts: ${convoItem.unreadPosts}'),
                                  onTap: () {
                                    print('go to conversation: ${convoItem.targetUsername} (${convoItem.conversationId})');
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (context) => ConversationPage(conversationId: convoItem.conversationId, targetUsername: convoItem.targetUsername, targetUID: convoItem.targetUid),
                                    ));
                                  }
                              ),
                              Divider(height: 5.0),
                            ],
                          );
                        }
                    );
                  }
              );
            } else {
              return Container();
            }
          },
        ),
      ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
    );
  }
}