import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'UserManagement.dart';

class ActivityManager {
  bool isLoggedIn() {
    if (FirebaseAuth.instance.currentUser() != null) {
      return true;
    } else {
      return false;
    }
  }

  addPost(BuildContext context, Map<String, dynamic> postData) async {
    if (isLoggedIn()) {

      await Firestore.instance.runTransaction((Transaction transaction) async {
        DocumentReference ref = Firestore.instance.collection('/posts').document();
        print('Doc Ref add post: $ref');
        String docId = ref.documentID;
        print(docId);
        String userId = await FirebaseAuth.instance.currentUser().then((user) {
          return user.uid;
        });
        print(userId);
        Map<String, dynamic> userTimelines = new Map<String, dynamic>.from(await UserManagement().getUserData().then((DocumentReference userDoc) async {
          print('user doc in add post: $userDoc');
          return await userDoc.get().then((DocumentSnapshot userSnap){
            print('got user snap: $userSnap // ${userSnap.data.toString()}');
            print(userSnap.data['timelinesIncluded']);
            if(userSnap.data['timelinesIncluded'] != null) {
              print('user is included on timelines');
              return new Map<String, dynamic>.from(
                  userSnap.data['timelinesIncluded']);
            } else {
              return new Map<String, dynamic>();
            }
          });
        }));
        print('checking user timelines == null');
        if(userTimelines == null) {
          print('user is not on any timelines');
          userTimelines = new Map<String, dynamic>();
        }

        await transaction.set(ref, {
          'userUID':  userId,
          'postTitle': postData['postTitle'],
          'postValue': postData['postValue'],
          'datePosted': DateTime.now(),
          'listenCount': 0,
          'timelines': userTimelines.keys.toList(),
        }).then((doc) async {
          print('adding post to user');
          await UserManagement().addPost(docId).then((val) {
            Navigator.of(context).pop();
          });
        }).catchError((e) {
          print(e);
        });
      });
    } else {
      Navigator.of(context).pushReplacementNamed('/landingpage');
    }
  }

  Future<void> followUser(String newFollowUID) async {
    WriteBatch batch = Firestore.instance.batch();

    //add newly followed user Id to current user's list of following
    DocumentReference currentUserDoc = await UserManagement().getUserData();
    String currentUserId = await currentUserDoc.get().then((snapshot) {
      return snapshot.data['uid'].toString();
    });


    Map<String, dynamic> currentFollowing = await currentUserDoc.get().then((snapshot) {
      print('setting currentFollowing');
      if(snapshot.data['following'] != null)
        return new Map<String, dynamic>.from(snapshot.data['following']);
      return null;
    });

    print('setting new following');
    Map<String, dynamic> newFollowing;
    if(currentFollowing == null) {
      newFollowing = {newFollowUID: true};
    } else {
      currentFollowing.addAll({newFollowUID: true});
      newFollowing = currentFollowing;
    }

    batch.updateData(currentUserDoc, {'following': newFollowing});
      //add current users Id to newly followed user's list of followers and add current users mainFeedTimelineId to followed users list of including timelines
    DocumentReference followedUserDoc = Firestore.instance.collection('/users').document(newFollowUID);

    Map<String, dynamic> currentFollowers = await followedUserDoc.get().then((snapshot) {
      if(snapshot.data['followers'] != null)
        return Map<String, dynamic>.from(snapshot.data['followers']);
      return null;
    });
    Map<String, dynamic> currentTimelinesIncluded = await followedUserDoc.get().then((snapshot) {
      if(snapshot.data['timelinesIncluded'] != null)
        return Map<String, dynamic>.from(snapshot.data['timelinesIncluded']);
      return null;
    });
    String currentUserMainFeedTimelineId = await currentUserDoc.get().then((snapshot) {
      return snapshot.data['mainFeedTimelineId'];
    });

    Map<String, dynamic> newFollowers;
    Map<String, dynamic> newTimelinesIncluded;

    if(currentUserMainFeedTimelineId == null) {
      print('current user does not have a main timeline id');
    } else {
      if(currentFollowers == null){
        newFollowers = {currentUserId: true};
      } else {
        currentFollowers.addAll({currentUserId: true});
        newFollowers = currentFollowers;
      }

      if(currentTimelinesIncluded == null){
        newTimelinesIncluded = {currentUserMainFeedTimelineId: true};
      } else {
        currentTimelinesIncluded.addAll({currentUserMainFeedTimelineId: true});
        newTimelinesIncluded = currentTimelinesIncluded;
      }

      batch.updateData(followedUserDoc, {'followers': newFollowers, 'timelinesIncluded': newTimelinesIncluded});
    }

      //add current user's main feed timeline to list of timelines for all posts from the newly followed
    await Firestore.instance.collection('/posts').where('userUID', isEqualTo: newFollowUID).getDocuments().then((QuerySnapshot snapshot) {
      print('post list snapshot data: ${snapshot.documents}');
      if(snapshot.documents.isEmpty) {
        print('user has no posts');
      } else {
        snapshot.documents.forEach((DocumentSnapshot postSnapshot) {
         List<String> newPostTimelines;
         if(postSnapshot.data['timelines'] != null && postSnapshot.data['timelines'].length > 0) {
           print('post has timeline field');
           List<String> currentPostTimelines = postSnapshot.data['timelines'];
           newPostTimelines = currentPostTimelines;
           print('set list to current timeline list');
         }
         else {
           newPostTimelines = [currentUserMainFeedTimelineId];
         }

         batch.updateData(postSnapshot.reference, {'timelines': newPostTimelines});
        });
      }
    }).catchError((e) {
      print('Error adding timeline to posts');
    });

    batch.commit();
  }

  Future<void> unfollowUser(String unfollowUID) async {
    WriteBatch batch = Firestore.instance.batch();

    DocumentReference loggedInUserDoc = await UserManagement().getUserData().then((doc) => doc);
    DocumentReference unfollowedUserDoc = await Firestore.instance.collection('/users').where('uid', isEqualTo: unfollowUID).getDocuments().then((snapshot) async {
      return snapshot.documents.first.reference;
    });
    String loggedInUID = await loggedInUserDoc.get().then((snapshot) {
      return snapshot.data['uid'];
    });
    String loggedInMainFeedTimelineId = await loggedInUserDoc.get().then((snapshot) {
      return snapshot.data['mainFeedTimelineId'];
    });

    //Remove userId from logged in user's list of following
    Map<String, dynamic> currentFollowing = await loggedInUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data['following']);
    });
    print('wint');
    currentFollowing.remove(unfollowUID);

    batch.updateData(loggedInUserDoc, {'following': currentFollowing});
    //remove logged in user's userId from unfollowed user's list of followers
    Map<String, dynamic> unfollowedUserFollowers = await unfollowedUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data['followers']);
    });
    Map<String, dynamic> unfollowedTimelinesIncluded = await unfollowedUserDoc.get().then((snapshot) {
      return new Map<String, dynamic>.from(snapshot.data['timelinesIncluded']);
    });
    unfollowedUserFollowers.remove(loggedInUID);
    unfollowedTimelinesIncluded.remove(loggedInMainFeedTimelineId);

    batch.updateData(unfollowedUserDoc, {'followers': unfollowedUserFollowers, 'timelinesIncluded': unfollowedTimelinesIncluded});
    //remove logged in user's mainFeedTimelinesId from all posts of unfollowed user
    await Firestore.instance.collection('/posts').where('userUID', isEqualTo: unfollowUID).getDocuments().then((snapshot) {
      if(snapshot.documents.isEmpty){
        print('unfollowed user has no posts');
      } else {
        snapshot.documents.forEach((DocumentSnapshot docSnap) {
          List<String> postTimelines = new List<String>.from(docSnap.data['timelines']);
          postTimelines.remove(loggedInMainFeedTimelineId);

          batch.updateData(docSnap.reference, {'timelines': postTimelines});
        });
      }
    });

    batch.commit();
  }
}

// Add Post dialog
Future<void> addPostDialog(BuildContext context) async {
  showDialog(
      context: context,
      builder: (BuildContext context) {
        String _postVal;
        String _postTitle;

        return SimpleDialog(
            contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
            title: Center(child: Text('Add Post',
              style: TextStyle(color: Colors.deepPurple)
            )),
            children: <Widget>[
              Container(
                width: 700.0,
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Post Title'
                  ),
                  onChanged: (value) {
                    _postTitle = value;
                  }
                )
              ),
              SizedBox(height: 20.0),
              Container(
                width: 700.0,
                child: TextField(
                  decoration: InputDecoration(
                      hintText: 'Add New Post',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.multiline,
                  maxLines: 5,
                  onChanged: (value) {
                    _postVal = value;
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FlatButton(
                    child: Text('Cancel'),
                    textColor: Colors.deepPurple,
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                  FlatButton(
                      child: Text('Add Post'),
                      textColor: Colors.deepPurple,
                      onPressed: () async {
                        if(_postVal == null || _postVal == ''){
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return AlertDialog(
                                title: Text('Your Post is Empty!'),
                                content: const Text('You haven\'t entered anything in your post! Tell the world what\'s on your mind!'),
                                actions: <Widget>[
                                  FlatButton(
                                    child: Text('Ok'),
                                    onPressed: () {
                                      Navigator.of(context).pop();
                                    }
                                  ),
                                ]
                              );
                            }
                          );
                        } else {
                          print({"postTitle": _postTitle,
                            "postValue": _postVal,
                          });
                          ActivityManager().addPost(context, {"postTitle": _postTitle,
                            "postValue": _postVal,
                          });
                        }
                      }
                  )
                ],
              ),
            ],
        );
      }
  );
}