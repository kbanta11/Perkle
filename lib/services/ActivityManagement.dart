import 'dart:async';
import 'dart:io';
import 'package:Perkl/MainPageTemplate.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:provider/provider.dart';
//import 'package:flutter_sound/flutter_sound.dart';
import 'package:sounds/sounds.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'package:permission_handler/permission_handler.dart';
//import 'package:file_picker/file_picker.dart';

import '../main.dart';
import 'UserManagement.dart';
import '../PageComponents.dart';

/*
class PostAudioPlayer {
  String postAudioUrl;
  bool hasPlayed = false;
  bool isPlaying = false;
  AudioPlayer postPlayer;

  PostAudioPlayer(String audioUrl, AudioPlayer postPlayer) {
    this.postAudioUrl = audioUrl;
    this.postPlayer = postPlayer;
  }

  play() {
    this.isPlaying = true;
    this.postPlayer.play(postAudioUrl);
  }

  stop() {
    this.isPlaying = false;
    this.postPlayer.stop();
  }
}
*/

class ActivityManager {
  //FlutterSound soundManager = new FlutterSound();
  //FlutterSoundRecorder fsRecorder = new FlutterSoundRecorder();
  SoundRecorder recorder = new SoundRecorder(playInBackground: true);
  //PostAudioPlayer currentPost;
  //AudioPlayer currentlyPlayingPlayer;
  //List<PostAudioPlayer> timelinePlaylist = new List();
  StreamController playlistStreamController = new StreamController<bool>.broadcast();
  Stream get playlistPlaying => playlistStreamController.stream.asBroadcastStream();
  //StreamSubscription<RecordStatus> recordingSubscription;

  bool isLoggedIn() {
    if (FirebaseAuth.instance.currentUser() != null) {
      return true;
    } else {
      return false;
    }
  }
/*
  setCurrentPost(PostAudioPlayer player) {
    if(this.currentPost != null) {
      this.currentPost.stop();
      this.currentPost.isPlaying = false;
    }
    this.currentPost = player;
    this.currentlyPlayingPlayer = player.postPlayer;
  }
*/
  addPost(BuildContext context, Map<String, dynamic> postData, bool addToTimeline, bool sendAsGroup, Map<String, dynamic> sendToUsers, Map<String, dynamic> addToConversations) async {
    if (isLoggedIn()) {
      print('Starting post add');
      await Firestore.instance.runTransaction((Transaction transaction) async {
        String userId = await FirebaseAuth.instance.currentUser().then((user) {
          return user.uid;
        });
        String username = await UserManagement().getUserData().then((DocumentReference ref) async {
          return await ref.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['username'];
          });
        });

        //Upload file to firebase storage -- need to serialize date into filename
        File audioFile = new File(postData['localRecordingLocation']);
        String filename = postData['dateString'].toString().replaceAll(new RegExp(r' '), '_');
        print(filename);
        final StorageReference fsRef = FirebaseStorage.instance.ref().child(userId).child('$filename');
        print('Post storage ref: ${fsRef}');
        print('File (${audioFile}) exists: ${audioFile.existsSync()}');
        final StorageUploadTask uploadTask = fsRef.putFile(audioFile);
        print('$uploadTask');
        String fileUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
        String fileUrlString = fileUrl.toString();

        if(addToTimeline) {
          print('awaiting post add...');
          DocumentReference ref = Firestore.instance.collection('/posts').document();
          print('Doc Ref add post: $ref');
          String docId = ref.documentID;
          print(docId);
          DateTime date = postData['date'];

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
            'username': username,
            'postTitle': postData['postTitle'],
            'datePosted': postData['date'],
            'dateString': postData['dateString'],
            'audioFileLocation': fileUrlString,
            'listenCount': 0,
            'secondsLength': postData['secondsLength'],
            'streamList': postData['streamList'],
            'timelines': userTimelines.keys.toList(),
          }).then((doc) async {
            print('adding post to user');
            await UserManagement().addPost(docId);
          }).catchError((e) {
            print(e);
          });
        }

        if(sendToUsers != null){
          if(sendToUsers.length > 0) {
            if(sendAsGroup) {
              //Create memberMap {uid: username} for all users in group
              Map<String, dynamic> _memberMap = new Map<String, dynamic>();
              _memberMap.addAll({userId: username});
              sendToUsers.forEach((key, value) async {
                String _username = await Firestore.instance.collection('users').document(key).get().then((doc) {
                  return doc.data['username'];
                });
                _memberMap.addAll({key: _username});
              });
              print('Member Map (Send as group): $_memberMap');
              await sendDirectPost(postData['postTitle'], null, postData['secondsLength'], memberMap: _memberMap, fileUrl: fileUrlString);
            } else {
              //Iterate over users to send to and send direct post for each w/
              // memberMap of currentUser and send to user
              sendToUsers.forEach((key, value) async {
                Map<String, dynamic> _memberMap = new Map<String, dynamic>();
                _memberMap.addAll({userId: username});
                String _thisUsername = await Firestore.instance.collection('users').document(key).get().then((doc) {
                  return doc.data['username'];
                });
                _memberMap.addAll({key: _thisUsername});
                //send direct post to this user
                await sendDirectPost(postData['postTitle'], null, postData['secondsLength'], memberMap: _memberMap, fileUrl: fileUrlString);
              });
            }
          }
        }

        if(addToConversations != null) {
          if(addToConversations.length > 0) {
            addToConversations.forEach((key, value) async {
              print('adding to conversation: $key');
              await sendDirectPost(postData['postTitle'], null, postData['secondsLength'], fileUrl: fileUrlString, conversationId: key);
            });
          }
        }
      });
      print('add finished');
      Navigator.of(context).pop();
    }
  }

  Future<void> sendDirectPostDialog(BuildContext context, {String conversationId, Map<String,dynamic> memberMap}) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return DirectMessageDialog(conversationId: conversationId, memberMap: memberMap);
      }
    );
  }

  Future<void> sendDirectPost(String messageTitle, String audioPath, int secondsLength, {String conversationId, Map<String, dynamic> memberMap, String fileUrl}) async {
    String _conversationId = conversationId;
    if(isLoggedIn()) {
        WriteBatch batch = Firestore.instance.batch();
        DateTime date = DateTime.now();

        //Create document for new direct post message
        DocumentReference directPostRef = Firestore.instance.collection('/directposts').document();
        String directPostDocId = directPostRef.documentID;


        //Get posting user id and username
        DocumentReference postingUserDoc = await UserManagement().getUserData();
        String postingUserID = postingUserDoc.documentID;
        String postingUsername = await postingUserDoc.get().then((DocumentSnapshot snapshot) async {
          return snapshot.data['username'].toString();
        });

        //Get recipient user doc
        /*
        DocumentReference recipientDocRef = Firestore.instance.collection('/users').document(recipientUserId);
        print('Recipient User Doc: $recipientDocRef');
        String recipientUsername = await recipientDocRef.get().then((DocumentSnapshot snapshot) {
          return snapshot.data['username'].toString();
        });
        */

        //Upload audio file
        String fileUrlString;
        if(fileUrl == null) {
          //Get audio file
          File audioFile = File(audioPath);
          String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(date).toString();
          final StorageReference storageRef = FirebaseStorage.instance.ref().child(postingUserID).child('direct-posts').child(dateString);
          final StorageUploadTask uploadTask = storageRef.putFile(audioFile);
          String _fileUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
          fileUrlString = _fileUrl.toString();
        } else {
          fileUrlString = fileUrl.toString();
        }


        //Check if conversation exists
        List<String> _memberList = new List<String>();
        if(memberMap != null)
          _memberList.addAll(memberMap.keys);
        _memberList.sort();
        if(_conversationId == null){
          await Firestore.instance.collection('conversations').where('memberList', isEqualTo: _memberList).getDocuments().then((snapshot) {
            if(snapshot.documents.isNotEmpty) {
              DocumentSnapshot conversation = snapshot.documents.first;
              if(conversation != null)
                _conversationId = conversation.reference.documentID;
            }
          });
        }
        bool conversationExists = _conversationId != null;

        /*
        Map<String, dynamic> conversationMap = await postingUserDoc.get().then((DocumentSnapshot snapshot) {
          return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
        });
         */

        if(conversationExists) {
          print('Conversation exists: $_conversationId');
          DocumentReference conversationRef = Firestore.instance.collection('/conversations').document(_conversationId);
          Map<String, dynamic> postMap;
          Map<String, dynamic> conversationMembers;
          await conversationRef.get().then((DocumentSnapshot snapshot) {
            postMap = Map<String, dynamic>.from(snapshot.data['postMap']);
            conversationMembers = Map<String, dynamic>.from(snapshot.data['conversationMembers']);
          });

          //To-Do --increment unread posts for all users other than posting user
          //-------------------------------------------------------------------
          print('Members: $conversationMembers');
          Map<String, dynamic> newMemberMap = new Map<String, dynamic>();
          conversationMembers.forEach((uid, details) {
            Map<dynamic, dynamic> newDetails = details;
            if(uid != postingUserID) {
              int unheardCnt = details['unreadPosts'];
              if(unheardCnt != null)
                unheardCnt = unheardCnt + 1;
              newDetails['unreadPosts'] = unheardCnt;
            }
            newMemberMap[uid] = newDetails;
          });

          postMap.addAll({directPostDocId: postingUserID});
          batch.updateData(conversationRef, {'postMap': postMap, 'lastDate': date, 'lastPostUsername': postingUsername, 'lastPostUserId': postingUserID, 'conversationMembers': newMemberMap});
        } else {
          //Create new conversation document and update data
          DocumentReference newConversationRef = Firestore.instance.collection('/conversations').document();
          conversationId = newConversationRef.documentID;
          print('creating new conversation: $conversationId');
          Map<String, dynamic> conversationMembers = new Map<String, dynamic>();
          memberMap.forEach((uid, username) {
            if(uid == postingUserID)
              conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 0}});
            else
              conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 1}});
          });
          Map<String, dynamic> postMap = {directPostDocId: postingUserID};

          batch.setData(newConversationRef, {'conversationMembers': conversationMembers, 'postMap': postMap, 'memberList': _memberList, 'lastDate': date, 'lastPostUsername': postingUsername, 'lastPostUserId': postingUserID});

          /*
          //Add a new conversation to the sending user doc conversationMap
          Map<String, dynamic> senderConversationMap = await postingUserDoc.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
          });

          Map<String, dynamic> sendConvoData = {_conversationId: true};

          if(senderConversationMap != null)
            senderConversationMap.addAll(sendConvoData);
          else
            senderConversationMap = sendConvoData;

          WriteBatch testBatch3 = Firestore.instance.batch();
          testBatch3.updateData(postingUserDoc, {'directConversationMap': senderConversationMap});
          print('');
          print('committing testBatch3');
          await testBatch3.commit();

          //Add a new conversation to the recieving user doc conversationMap - store number of unread posts and other user name
          Map<String, dynamic> recipientConversationMap = await recipientDocRef.get().then((DocumentSnapshot snapshot) {
            return snapshot.data['directConversationMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['directConversationMap']);
          });

          Map<String, dynamic> recConvoData = {'conversationId': conversationId, 'targetUsername': currentUsername, 'unreadPosts': 1};

          if(recipientConversationMap != null)
            recipientConversationMap.addAll({currentUserUID: recConvoData});
          else
            recipientConversationMap = {currentUserUID: recConvoData};

          batch.updateData(recipientDocRef, {'directConversationMap': recipientConversationMap});
          */
        }


        //Add data to new direct post document (message title, file url, length, date, sender, recipient, conversationId)
        Map<String, dynamic> newPostData = {'senderUID': postingUserID, 'senderUsername': postingUsername, 'messageTitle': messageTitle,
          'secondsLength': secondsLength, 'audioFileLocation': fileUrlString, 'conversationId': _conversationId != null ? _conversationId : conversationId,
          'datePosted': date
        };

        batch.setData(directPostRef, newPostData);

        await batch.commit().catchError(((error) {
          print('Error committing testBatch4: $error');
        }));
        print('batch committed');
    }
  }

  Future<List<dynamic>> startRecordNewPost(MainAppProvider mp) async {
    print('start recording');
    try {
      //await fsRecorder.openAudioSession(focus: AudioFocus.requestFocusAndStopOthers);
      recorder.initialize();
      //final appDataDir = await getApplicationDocumentsDirectory();
      //String localPath = appDataDir.path;
      //String extension = '.aac';
      //String filePath = '$localPath/tempAudio$extension';
      //print('File Path: $filePath');

      //Check if have permissions for microphone or ask
      if(await Permission.microphone.isUndetermined) {
        print('asking for mic permissions');
        await Permission.microphone.request();
      }
      // String length
      //await fsRecorder.startRecorder(toFile: filePath, bitRate: 100000, codec: Codec.aacMP4);
      String tempFilePath = Track.tempFile(WellKnownMediaFormats.adtsAac);
      print('TempFilePath: $tempFilePath');
      /*
      recorder.onRequestPermissions = (Track track) async {
        print('requesting permissions');
        return true;
      };
       */
      await recorder.record(Track.fromFile(tempFilePath, mediaFormat: WellKnownMediaFormats.adtsAac));
      recorder.dispositionStream().listen((disposition) {
        mp.setRecordingTime(disposition.duration);
      });
      DateTime startRecordDateTime = DateTime.now();
      print('Recording started at: $startRecordDateTime');
      return [Platform.isIOS ? tempFilePath.replaceAll('file://', '') : tempFilePath, startRecordDateTime];

      return null;
    } catch (e) {
      print('Start recorder error: $e');
      return null;
    }
  }

  Future<List<dynamic>> stopRecordNewPost(String postPath, DateTime startDateTime) async {
    try {
      //await fsRecorder.stopRecorder();
      await recorder.stop();
      recorder.release();
      recorder = new SoundRecorder();
      DateTime endRecordDateTime = DateTime.now();
      Duration recordingTime = endRecordDateTime.difference(startDateTime);

      int secondsLength = recordingTime.inSeconds;
      print('$startDateTime - $endRecordDateTime');
      print(secondsLength);
      return [postPath, secondsLength];
    } catch (e) {
      print('error stopping recorder: $e');
    }
    return null;
  }

  /*
  pausePlaying() async {
    int result = await this.currentPost.postPlayer.pause();
    this.playlistStreamController.add(false);
    print('pausing player');
  }

  resumePlaying() async {
    int result = await this.currentPost.postPlayer.resume();
    print('resume playing');
  }

  PostAudioPlayer addPostToPlaylist(String postAudioUrl, AudioPlayer postPlayer) {
    PostAudioPlayer postObject = new PostAudioPlayer(postAudioUrl, postPlayer);
    this.timelinePlaylist.add(postObject);
    print('Post added to timeline playlist');
    return postObject;
  }

  playPlaylist() async {
    List<PostAudioPlayer> unheardPosts = this.timelinePlaylist.where((player) {
      return player.hasPlayed == false;
    }).toList();
    PostAudioPlayer currentPost = unheardPosts[0];
    print('Current Playlist Post: $currentPost');
    if(currentPost != null) {
      print('Has Played: ${currentPost.hasPlayed}; Is Currently Playing ${currentPost.isPlaying}');
      if (!currentPost.hasPlayed && !currentPost.isPlaying) {
        print('Starting next post player');
        this.setCurrentPost(currentPost);
        this.playlistStreamController.add(true);
        currentPost.play();
      }
      if(this.currentlyPlayingPlayer != null) {
        this.playlistStreamController.add(true);
        this.currentlyPlayingPlayer.resume();
      }
    }
  }

  pausePlaylist() async {
    this.pausePlaying();
    this.playlistStreamController.add(false);
  }
*/

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
         List<dynamic> newPostTimelines = new List<dynamic>();
         if(postSnapshot.data['timelines'] != null && postSnapshot.data['timelines'].length > 0) {
           print('post has timeline field');
           List<dynamic> currentPostTimelines = postSnapshot.data['timelines'];
           newPostTimelines.addAll(currentPostTimelines);
           newPostTimelines.add(currentUserMainFeedTimelineId);
           print('set list to current timeline list');
         }
         else {
           newPostTimelines = [currentUserMainFeedTimelineId];
         }

         batch.updateData(postSnapshot.reference, {'timelines': newPostTimelines});
        });
      }
    }).catchError((e) {
      print('Error adding timeline to posts: $e');
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

List<String> processTagString(String postTags) {
  if(postTags != null) {
    String strippedSpaces = postTags.replaceAll(new RegExp(r' '), '');
    List<String> tagList = strippedSpaces.split("#");
    tagList.removeWhere((item) => item == '');
    return tagList;
  }
  return null;
}

// Add Post dialog

class AddPostDialog extends StatefulWidget {
  DateTime date;
  String recordingLocation;
  int secondsLength;

  AddPostDialog({Key key, @required this.date, @required this.recordingLocation, @required this.secondsLength}) : super(key: key);

  @override
  _AddPostDialogState createState() => new _AddPostDialogState();
}

class _AddPostDialogState extends State<AddPostDialog> {
  String _postTitle;
  String _postTags;
  bool _isLoading = false;
  int page = 0;
  bool _addToTimeline = true;
  bool _sendAsGroup = false;
  bool _isPlayingRecorder = false;
  AudioPlayer player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
  Map<String, dynamic> _sendToUsers = new Map<String, dynamic>();
  Map<String, dynamic> _addToConversations = new Map<String, dynamic>();

  @override
  build(BuildContext context) {
    String dateString = new DateFormat('yyyy-mm-dd hh:mm:ss').format(widget.date);

    Widget page0 = Column(
        children: <Widget>[
          //Add place to play back last recording
          Center(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.deepPurple,
              ),
              height: 50,
              width: 50,
              child: InkWell(
                borderRadius: BorderRadius.all(Radius.circular(25)),
                child: Icon(_isPlayingRecorder ? Icons.pause : Icons.play_arrow, color: Colors.white,),
                onTap: () {
                  if(_isPlayingRecorder) {
                    player.pause();
                    setState(() {
                      _isPlayingRecorder = false;
                    });
                  } else {
                    player.play(widget.recordingLocation, isLocal: true);
                    player.onPlayerCompletion.listen((event) {
                      setState(() {
                        _isPlayingRecorder = false;
                      });
                    });
                    setState(() {
                      _isPlayingRecorder = true;
                    });
                  }
                },
              ),
            ),
          ),
          SizedBox(height: 10),
          Text('Post Title (optional)'),
          Container(
              width: 700.0,
              child: TextField(
                  decoration: InputDecoration(
                    hintText: _postTitle == null ? dateString : _postTitle,
                  ),
                  onChanged: (value) {
                    //print(_postTitle);
                    _postTitle = value;
                  }
              )
          ),
          SizedBox(height: 20.0),
          Text('Stream Tags (separated by \'#\')'),
          Container(
            width: 700.0,
            child: TextField(
              decoration: InputDecoration(
                hintText: _postTags == null ? '#TagYourTopics' : _postTags,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              onChanged: (value) {
                _postTags = value;
              },
            ),
          ),
          /*
              Placeholder for adding field for capturing streams/tags for the post as well as public/private
               */
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
                child: Text('Send To...'),
                textColor: Colors.deepPurple,
                onPressed: () {
                  String postError;
                  String postErrorTitle;
                  if(_postTags != null){
                    int numTags = '#'.allMatches(_postTags).length;
                    if(numTags > 15) {
                      postError = 'The limit for the number of stream tags on a post is 15.';
                      postErrorTitle = 'Too Many Stream Tags!';
                    }
                  }
                  if(postError != null){
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(postErrorTitle),
                          content: Text(postError),
                          actions: <Widget>[
                            FlatButton(
                              child: Text('Ok'),
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    setState(() {
                      page = 1;
                    });
                  }
                }
              )
            ],
          )
        ]
    );

    Widget page1 = Column(
      children: <Widget>[
        CheckboxListTile(
          title: Text('My Timeline'),
          value: _addToTimeline,
          onChanged: (value) {
            setState(() {
              _addToTimeline = !_addToTimeline;
            });
          }
        ),
        Divider(height: 2.5),
        FutureBuilder(
            future: FirebaseAuth.instance.currentUser(),
            builder: (context, AsyncSnapshot<FirebaseUser> userSnap) {
              if(!userSnap.hasData)
                return Container(height: 180.0, width: 500.0);
              String userId = userSnap.data.uid;
              return StreamBuilder(
                  stream: Firestore.instance.collection('conversations').where('memberList', arrayContains: userSnap.data.uid.toString()).snapshots(),
                  builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                    if(!snapshot.hasData)
                      return Container(height: 180.0, width: 500.0);

                    if(snapshot.data.documents.length == 0)
                      return Center(child: Text('You have no conversations!'));
                    else
                      return Container(
                          height: 180.0,
                          width: 500.0,
                          child: ListView(
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            children: snapshot.data.documents.map((convo) {
                              String titleText = '';
                              Map<dynamic, dynamic> memberDetails = convo.data['conversationMembers'];
                              if(memberDetails != null){
                                memberDetails.forEach((key, value) {
                                  if(key != userSnap.data.uid) {
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
                              if(!_addToConversations.containsKey(convo.documentID))
                                _addToConversations.addAll({convo.documentID: false});
                              bool _val = _addToConversations[convo.documentID];
                              return CheckboxListTile(
                                  title: Text(titleText),
                                  value: _val,
                                  onChanged: (value) {
                                    print(_addToConversations);
                                    setState(() {
                                      _addToConversations[convo.documentID] = value;
                                    });
                                  }
                              );
                            }).toList(),
                          )
                      );
                  }
              );
            }
        ),
        Divider(height: 2.5),
        Container(
          child: SwitchListTile(
            title: Text('Send as Group'),
            activeColor: Colors.deepPurple,
            value: _sendAsGroup,
            onChanged: (value) {
              setState(() {
                _sendAsGroup = !_sendAsGroup;
              });
            },
          )
        ),
        Divider(height: 2.5),
        FutureBuilder(
          future: FirebaseAuth.instance.currentUser(),
          builder: (context, AsyncSnapshot<FirebaseUser> userSnap) {
            if(!userSnap.hasData)
              return Container(height: 180.0, width: 500.0);
            String userId = userSnap.data.uid;
            return StreamBuilder(
              stream: Firestore.instance.collection('users').document(userId).snapshots(),
              builder: (context, AsyncSnapshot<DocumentSnapshot> snapshot) {
                if(!snapshot.hasData)
                  return Container(height: 180.0, width: 500.0);
                Map<dynamic, dynamic> followers = snapshot.data['followers'];
                if(followers == null)
                  return Container(height: 180.0, width: 500.0);
                else
                  return Container(
                    height: 180.0,
                    width: 500.0,
                    child: ListView(
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      children: followers.entries.map((item) {
                        if(!_sendToUsers.containsKey(item.key))
                          _sendToUsers.addAll({item.key: false});
                        bool _val = _sendToUsers[item.key];
                        return CheckboxListTile(
                            title: FutureBuilder(
                              future: Firestore.instance.collection('users').document(item.key).get(),
                              builder: (context, AsyncSnapshot<DocumentSnapshot> itemDoc) {
                                if(!itemDoc.hasData)
                                  return Container();
                                return Text(itemDoc.data['username']);
                              }
                            ),
                            value: _val,
                            onChanged: (value) {
                              print(_sendToUsers);
                              setState(() {
                                _sendToUsers[item.key] = value;
                              });
                            }
                        );
                      }).toList(),
                    )
                  );
              }
            );
          }
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FlatButton(
              child: Text('Back'),
              textColor: Colors.deepPurple,
              onPressed: () {
                setState(() {
                  page = 0;
                });
              }
            ),
            FlatButton(
                child: Text('Add Post'),
                textColor: Colors.deepPurple,
                onPressed: () async {
                    List<String> tagList = processTagString(_postTags);
                    print({"postTitle": _postTitle,
                      "localRecordingLocation": widget.recordingLocation,
                      "date": widget.date,
                      "dateString": dateString,
                      "listens": 0,
                      "secondsLength": widget.secondsLength,
                      "streamList": tagList,
                      "test": "tester",
                    });
                    setState(() {
                      _isLoading = true;
                    });
                    _sendToUsers.removeWhere((key, value) => value == false);
                    _addToConversations.removeWhere((key, value) => value == false);
                    //print('Sending to: $_sendToUsers / As Group: $_sendAsGroup / Add to Timeline: $_addToTimeline');
                    await ActivityManager().addPost(context, {"postTitle": _postTitle,
                      "localRecordingLocation": widget.recordingLocation,
                      "date": widget.date,
                      "dateString": dateString,
                      "listens": 0,
                      "secondsLength": widget.secondsLength,
                      "streamList": tagList,
                    }, _addToTimeline, _sendAsGroup, _sendToUsers, _addToConversations);
                    print('Post added');
                }
            )
          ]
        )
      ]
    );

    return SimpleDialog(
      contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
      title: Center(child: Text(page == 0 ? 'Add New Post' : 'Send To',
          style: TextStyle(color: Colors.deepPurple)
      )),
      children: <Widget>[
        _isLoading ? Center(
            child: Container(
                height: 75.0,
                width: 75.0,
                child: CircularProgressIndicator()
            )
        ) : page == 0 ? page0 : page1,
      ],
    );
  }
}

class UploadPostDialog extends StatefulWidget {
  @override
  _UploadPostDialogState createState() => new _UploadPostDialogState();
}

class _UploadPostDialogState extends State<UploadPostDialog> {
  DateTime date = DateTime.now();
  String dateString = new DateFormat('yyyy-mm-dd hh:mm:ss').format(DateTime.now());
  String fileName;
  String filepath;
  Duration duration;
  String postTitle;
  String postTags;
  String noFileError;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      contentPadding: EdgeInsets.fromLTRB(10.0, 5.0, 10.0, 5.0),
      title: Center(child: Text('Upload Post', style: TextStyle(color: Colors.deepPurple),)),
      children: <Widget>[
        Text('Post Title',
          style: TextStyle(
            fontSize: 16.0
          )
        ),
        TextField(
          decoration: InputDecoration(
            hintText: dateString,
          ),
          onChanged: (value) {
            postTitle = value;
          }
        ),
        SizedBox(height: 15.0),
        Text('Stream Tags (separated by "#")',
          style: TextStyle(
            fontSize: 16.0
          )
        ),
        SizedBox(height: 5.0),
        TextField(
          decoration: InputDecoration(
            hintText: '#TagYourTopics',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.multiline,
          maxLines: 5,
          onChanged: (value) {
            postTags = value;
          },
        ),
        SizedBox(height: 10.0),
        FlatButton(
          color: Colors.deepPurple,
          textColor: Colors.white,
          child: Center(child: fileName == null ? Text('Choose a file...') : Text(fileName)),
          onPressed: () async {
            /*
            String path = await FilePicker.getFilePath(type: FileType.audio, allowedExtensions: ['mp3', 'aac', 'm4a']);
            File uploadFile = File(path);
            print('Selected File Path: $path');
            print('File: ${uploadFile}: ${await uploadFile.exists()}');
            AudioPlayer tempPlayer = new AudioPlayer();
            await tempPlayer.setUrl(path);
            int audioDuration = await Future.delayed(Duration(seconds: 2), () => tempPlayer.getDuration());
            Duration postDuration = Duration(milliseconds: audioDuration);
            print('Duration: $audioDuration/Seconds: ${postDuration.inSeconds}');
            setState(() {
              filepath = path;
              fileName = path.split('/').last;
              duration = postDuration;
            });
             */
          },
        ),
        Center(child: noFileError == null ? Container() : Text(noFileError, style: TextStyle(color: Colors.red),)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FlatButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            OutlineButton(
              borderSide: BorderSide(
                color: Colors.deepPurple
              ),
              child: Text('Upload Post', style: TextStyle(color: Colors.deepPurple),),
              onPressed: () async {
                if(filepath == null) {
                  setState(() {
                    noFileError = 'Please select an audio file!';
                  });
                } else {
                  noFileError = null;
                  List<String> tagList = processTagString(postTags);
                  await ActivityManager().addPost(context, {"postTitle": postTitle,
                    "localRecordingLocation": filepath,
                    "date": date,
                    "dateString": dateString,
                    "listens": 0,
                    "secondsLength": duration.inSeconds,
                    "streamList": tagList,
                  }, true, false, null, null);
                  //print('Post added');
                }
              },
            ),
          ]
        ),
      ],

    );
  }
}

class DirectMessageDialog extends StatefulWidget {
  final String conversationId;
  final Map<String, dynamic> memberMap;

  DirectMessageDialog({Key key, @required this.conversationId, this.memberMap}) : super(key: key);

  @override
  _DirectMessageDialogState createState() => new _DirectMessageDialogState();
}

class _DirectMessageDialogState extends State<DirectMessageDialog> {
  String _messageTitle;
  bool _isRecording = false;
  bool _isPlaybackRecording = false;
  String _postAudioPath;
  DateTime _startRecordDate;
  int _secondsLength;
  ActivityManager activityManager = new ActivityManager();
  AudioPlayer audioPlayer = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
  bool _isLoading = false;

  @override
  dispose() {
    activityManager.recorder.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return SimpleDialog(
      contentPadding: EdgeInsets.fromLTRB(15.0, 8.0, 15.0, 10.0),
      title: Center(child: Text('New Message',
          style: TextStyle(color: Colors.deepPurple),
        textAlign: TextAlign.center,
      )),
      children: <Widget>[
        _isLoading ? Center(child: Container(height: 75.0, width: 75.0, child: CircularProgressIndicator())) : Column(
          children: <Widget>[
            Text('Message Title', style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
            Container(
                width: 700.0,
                child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Message Title (Optional)',
                    ),
                    onChanged: (value) {
                      _messageTitle = value;
                    }
                )
            ),
            SizedBox(height: 20.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    _isRecording ? RecordingPulse(maxSize: 56.0,) : Container(),
                    FloatingActionButton(
                        backgroundColor: _isRecording ? Colors.transparent : Colors.deepPurple,
                        child: Icon(Icons.mic, color: _isRecording ? Colors.red : Colors.white,),
                        shape: CircleBorder(side: BorderSide(color: _isRecording ? Colors.red : Colors.deepPurple)),
                        heroTag: null,
                        elevation: _isRecording ? 0.0 : 5.0,
                        onPressed: () async {
                          if(_isRecording) {
                            List<dynamic> stopRecordVals = await activityManager.stopRecordNewPost(_postAudioPath, _startRecordDate);
                            String recordingLocation = stopRecordVals[0];
                            int secondsLength = stopRecordVals[1];

                            print('$recordingLocation -/- Length: $secondsLength');
                            setState(() {
                              _isRecording = !_isRecording;
                              _secondsLength = secondsLength;
                            });
                            print('getting date');
                            DateTime date = new DateTime.now();
                            print('date before dialog: $date');
                            //await addPostDialog(context, date, recordingLocation, secondsLength);
                          } else {
                            List<dynamic> startRecordVals = await activityManager.startRecordNewPost(mp);
                            String postPath = startRecordVals[0];
                            DateTime startDate = startRecordVals[1];
                            setState(() {
                              _isRecording = !_isRecording;
                              _postAudioPath = postPath;
                              _startRecordDate = startDate;
                            });
                          }
                        }
                    )
                  ],
                ),
                SizedBox(width: 50),
                FloatingActionButton(
                  heroTag: 2,
                  backgroundColor: _postAudioPath == null || _isRecording ? Colors.grey : _isPlaybackRecording ? Colors.red : Colors.deepPurple,
                  child: Icon(_isPlaybackRecording ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  onPressed: () {
                    if(_postAudioPath == null || _isRecording)
                      return;
                    if(_isPlaybackRecording) {
                      audioPlayer.pause();
                      setState(() {
                        _isPlaybackRecording = false;
                      });
                    } else {
                      audioPlayer.play(_postAudioPath, isLocal: true);
                      audioPlayer.onPlayerCompletion.listen((event) {
                        setState(() {
                          _isPlaybackRecording = false;
                        });
                      });
                      setState(() {
                        _isPlaybackRecording = true;
                      });
                    }
                  },
                )
              ]
            ),
            SizedBox(height: 10.0),
            Center(
              child: _postAudioPath == null ? Text('Audio Recording Missing',
                style: TextStyle(color: Colors.red),
              ) : null,
            ),
            SizedBox(height: 10.0),
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FlatButton(
                      child: Text('Cancel'),
                      onPressed: () {
                        Navigator.of(context).pop();
                      }
                  ),
                  _isLoading ? Container() : FlatButton(
                    child: Text('Send', style: TextStyle(color: _postAudioPath != null && _secondsLength != null ? Colors.white : Colors.grey)),
                    color: _postAudioPath != null && _secondsLength != null ? Colors.deepPurple : Colors.transparent,
                    onPressed: () async {
                      if(_postAudioPath != null && _secondsLength != null){
                        setState(() {
                          _isLoading = true;
                        });
                        if(widget.conversationId != null) {
                          await activityManager.sendDirectPost(_messageTitle, _postAudioPath, _secondsLength, conversationId: widget.conversationId);
                          Navigator.of(context).pop();
                        } else {
                          await activityManager.sendDirectPost(_messageTitle, _postAudioPath, _secondsLength, memberMap: widget.memberMap);
                          Navigator.of(context).pop();
                        }
                      }
                    },
                  ),
                ]
            )
          ]
        ),
      ],
    );
  }
}