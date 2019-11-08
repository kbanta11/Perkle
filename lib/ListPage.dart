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
        title: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              FutureBuilder(
                  future: FirebaseAuth.instance.currentUser(),
                  builder: (context, snapshot) {
                    if(snapshot.hasData){
                      String _userId = snapshot.data.uid;
                      return StreamBuilder(
                          stream: Firestore.instance.collection('users').document(_userId).snapshots(),
                          builder: (context, snapshot) {
                            if(snapshot.hasData) {
                              String profilePicUrl = snapshot.data['profilePicUrl'];
                              if(profilePicUrl != null)
                                return Container(
                                  height: 40.0,
                                  width: 40.0,
                                  decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white,
                                      image: DecorationImage(
                                        fit: BoxFit.cover,
                                        image: NetworkImage(profilePicUrl.toString()),
                                      )
                                  ),
                                );
                            }
                            return Container(
                              height: 40.0,
                              width: 40.0,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                // image: DecorationImage()
                              ),
                            );
                          }
                      );
                    }
                    return Container(
                      height: 40.0,
                      width: 40.0,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        // image: DecorationImage()
                      ),
                    );
                  }
              ),
              IconButton(
                icon: Icon(Icons.search),
                iconSize: 40.0,
                onPressed: () {
                  Navigator.of(context).pushNamed('/searchpage');
                },
              ),
              Expanded(
                child: Center(child: new Text('Perkle')),
              ),
            ]
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        titleSpacing: 5.0,
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.white),
            iconSize: 40.0,
          ),
          RecordButton(),
          /*new FlatButton(
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
          ),*/
        ],
      ),
      body: Container(
        child: FutureBuilder(
          future: UserManagement().getUserData(),
          builder: (BuildContext context, AsyncSnapshot<DocumentReference> futureSnap) {
            if(futureSnap.hasData) {
              return StreamBuilder(
                  stream: futureSnap.data.snapshots(),
                  builder: (BuildContext context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                    if(snapshot.hasData) {
                      Map<String, dynamic> conversationMap = Map<String, dynamic>.from(snapshot.data['directConversationMap']);
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
                                Padding(
                                    padding: EdgeInsets.fromLTRB(0.0, 5.0, 0.0, 5.0),
                                    child: ListTile(
                                        leading: StreamBuilder(
                                            stream: Firestore.instance.collection('users').document(convoItem.targetUid).snapshots(),
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
                                        title: Text(convoItem.targetUsername),
                                        trailing: Text('Unheard Posts: ${convoItem.unreadPosts}'),
                                        onTap: () {
                                          print('go to conversation: ${convoItem.targetUsername} (${convoItem.conversationId})');
                                          Navigator.push(context, MaterialPageRoute(
                                            builder: (context) => ConversationPage(conversationId: convoItem.conversationId, targetUsername: convoItem.targetUsername, targetUID: convoItem.targetUid),
                                          ));
                                        }
                                    )
                                ),
                                Divider(height: 5.0),
                              ],
                            );
                          }
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
      ),
      bottomNavigationBar: bottomNavBar(_onItemTapped, _selectedIndex),
    );
  }
}