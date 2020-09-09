import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'models.dart';

class DBService {
  Firestore _db = Firestore.instance;

  Future<int> getConfigMinBuildNumber() async {
    int buildNumber = await _db.collection('config').document('config').get().then((snap) {
      return snap.data[Platform.isAndroid ? 'minimum_android_version' : 'minimum_ios_version'];
    }).catchError((e) {
      print('error: $e');
    });
    return buildNumber;
  }

  Future<List<DiscoverTag>> getDiscoverTags() async {
    return await _db.collection('discover').where('type', isEqualTo: 'StreamTag').orderBy('rank').getDocuments().then((QuerySnapshot qs) {
      return qs.documents.map((doc) => DiscoverTag.fromFirestore(doc)).toList();
    });
  }

  Stream<List<String>> streamDiscoverPods() {
    return _db.collection('requests').document('discover').snapshots().map((doc) {
      return doc.data['results'].map<String>((value) => value.toString()).toList();
    });
  }

  Stream<List<Conversation>> streamConversations(String userId) {
    return _db.collection('conversations').where('memberList', arrayContains: userId).orderBy('lastDate', descending: true).snapshots().map((qs) {
      return qs.documents.map((doc) => Conversation.fromFirestore(doc)).toList();
    });
  }
  
  Stream<List<DirectPost>> streamDirectPosts(String conversationId) {
    return _db.collection('directposts').where('conversationId', isEqualTo: conversationId).orderBy('datePosted', descending: true).snapshots().map((qs) {
      return qs.documents.map((doc) => DirectPost.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Post>> streamTagPosts(String streamTag) {
    return _db.collection('posts').where('streamList', arrayContains: streamTag).orderBy('datePosted', descending: true).snapshots().map((qs) {
      return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  Stream<List<Post>> streamTimelinePosts(FirebaseUser currentUser, {String timelineId, String streamTag, String userId}) {
    print('TimelineId: $timelineId ---- StreamTag: $streamTag ---- UserId: $userId');
    if(streamTag != null) {
      return _db.collection('posts').where('streamList', arrayContains: streamTag).orderBy('datePosted', descending: true).snapshots().map((qs) {
        return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
      });
    }
    if(timelineId != null) {
      return _db.collection('posts').where('timelines', arrayContains: timelineId).orderBy("datePosted", descending: true).snapshots().map((qs) {
        return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
      });
    }
    if(userId != null) {
      return _db.collection('posts').where('userUID', isEqualTo: userId).orderBy("datePosted", descending: true).snapshots().map((qs) {
        return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
      });
    }
    return _db.collection('posts').where('userUID', isEqualTo: currentUser.uid).orderBy("datePosted", descending: true).snapshots().map((qs) {
      return qs.documents.map((doc) => Post.fromFirestore(doc)).toList();
    });
  }

  Stream<List<EpisodeReply>> streamEpisodeReplies(String uniqueId) {
    print('Unique ID: $uniqueId');
    return _db.collection('episode-replies').where("unique_id", isEqualTo: uniqueId).orderBy("reply_date", descending: true).snapshots().map((qs) {
      print('Number of Replies: ${qs.documents.length}');
      return qs.documents.map((doc) => EpisodeReply.fromFirestore(doc)).toList();
    });
  }

  Future<void> updateDeviceToken(String userToken, String uid) async {
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

  void markConversationRead(String conversationId, String userId) async {
    DocumentReference conversationRef = _db.collection('conversations').document(conversationId);
    Conversation convo = await conversationRef.get().then((doc) => Conversation.fromFirestore(doc));
    print('Members before: ${convo.conversationMembers}');
    if(convo.conversationMembers != null && convo.conversationMembers.containsKey(userId)) {
      print('setting user unread to 0');
      Map userMap = convo.conversationMembers[userId];
      userMap['unreadPosts'] = 0;
      convo.conversationMembers[userId] = userMap;
    }
    print('Members after: ${convo.conversationMembers}');
    await _db.runTransaction((transaction) => transaction.update(conversationRef, {'conversationMembers': convo.conversationMembers}));
  }

  Future<void> sendFeedback(int rating, String positive, String negative, User user) async {
    DocumentReference feedbackRef = _db.collection('feedback').document('initial-testing').collection('responses').document(user.uid);
    await _db.runTransaction((trans) => trans.set(feedbackRef, {
      'userId': user.uid,
      'rating': rating,
      'positive': positive,
      'negative': negative,
      'datesent': DateTime.now(),
    }));
    return;
  }

  Future<void> postEpisodeReply({Episode episode, Podcast podcast, String filePath, Duration replyLength, DateTime replyDate, User user, String replyTitle}) async {
    String episodeId = episode.guid != null ? episode.guid : episode.link;
    String fileUrlString;

    //upload file to firebase storage
    if(filePath != null) {
      //Get audio file
      File audioFile = File(filePath);
      String dateString = DateFormat("yyyy-MM-dd_HH_mm_ss").format(replyDate).toString();
      final StorageReference storageRef = FirebaseStorage.instance.ref().child(user.uid).child('episode-replies').child('$episodeId-$dateString');
      final StorageUploadTask uploadTask = storageRef.putFile(audioFile);
      String _fileUrl = await (await uploadTask.onComplete).ref.getDownloadURL();
      fileUrlString = _fileUrl.toString();
    }

    //add document to "episode-replies" collection, key on episode ID (guid/link)
    DocumentReference replyRef = _db.collection('episode-replies').document();

    await _db.runTransaction((transaction) async {
      await transaction.set(replyRef, {
        'id': replyRef.documentID,
        'unique_id': episodeId,
        'podcast_name': podcast.title,
        'episode_name': episode.title,
        'episode_date': episode.publicationDate,
        'posting_username': user.username,
        'posting_uid': user.uid,
        'reply_title': replyTitle,
        'reply_date': replyDate,
        'reply_ms': replyLength.inMilliseconds,
        'audioFileLocation': fileUrlString,
      });
    });

    //Make sure to update username change function to also update replies
  }

  Future<List<String>> getHeardPostIds({String conversationId, String userId}) async {
    return await _db.collection('conversations').document(conversationId).collection('heard-posts').document(userId).get().then((DocumentSnapshot docSnap) {
      if(!docSnap.exists) {
        return null;
      }
      List<String> idList = List<String>();
      idList.addAll(docSnap.data['id_list'].cast<String>());
      return idList;
    });
  }

  markDirectPostHeard({String conversationId, String userId, String postId}) async {
    DocumentReference docRef = _db.collection('conversations').document(conversationId).collection('heard-posts').document(userId);
    List<String> idList = List<String>();
    bool docExists = false;

    await docRef.get().then((docSnap) {
      if(docSnap.exists) {
        docExists = true;
        idList.addAll(docSnap.data['id_list'].cast<String>());
      }
    });
    idList.add(postId);

    await _db.runTransaction((transaction) {
      if(docExists) {
        return transaction.update(docRef, {
          'id_list': idList,
        });
      } else {
        return transaction.set(docRef, {'id_list': idList});
      }
    });
  }

  Future<List<DirectPost>> getDirectPosts(String conversationId) {
    return _db.collection('directposts').where('conversationId', isEqualTo: conversationId).orderBy('datePosted', descending: true).getDocuments().then((QuerySnapshot qs) {
      if(qs.documents.length > 0) {
        return qs.documents.map((docSnap) => DirectPost.fromFirestore(docSnap)).toList();
      }
      return null;
    });
  }

  //Share podcast episodes in conversations
  Future<void> shareEpisodeToDiscussion({Episode episode, Podcast podcast, User sender, bool sendAsGroup, Map<String, dynamic> sendToUsers, Map<String, dynamic> addToConversations}) async {
    if(sendToUsers != null){
      if(sendToUsers.length > 0) {
        if(sendAsGroup) {
          //Create memberMap {uid: username} for all users in group
          Map<String, dynamic> _memberMap = new Map<String, dynamic>();
          _memberMap.addAll({sender.uid: sender.username});
          sendToUsers.forEach((key, value) async {
            String _username = await Firestore.instance.collection('users').document(key).get().then((doc) {
              return doc.data['username'];
            });
            _memberMap.addAll({key: _username});
          });
          print('Member Map (Send as group): $_memberMap');
          await shareDirectPost(episode, podcast, sender, memberMap: _memberMap);
        } else {
          //Iterate over users to send to and send direct post for each w/
          // memberMap of currentUser and send to user
          sendToUsers.forEach((key, value) async {
            Map<String, dynamic> _memberMap = new Map<String, dynamic>();
            _memberMap.addAll({sender.uid: sender.username});
            String _thisUsername = await Firestore.instance.collection('users').document(key).get().then((doc) {
              return doc.data['username'];
            });
            _memberMap.addAll({key: _thisUsername});
            //send direct post to this user
            await shareDirectPost(episode, podcast, sender, memberMap: _memberMap);
          });
        }
      }
    }

    if(addToConversations != null) {
      if(addToConversations.length > 0) {
        addToConversations.forEach((key, value) async {
          print('adding to conversation: $key');
          await shareDirectPost(episode, podcast, sender, conversationId: key);
        });
      }
    }
  }

  Future<void> shareDirectPost(Episode episode, Podcast podcast, User sender, {String conversationId, Map<dynamic, dynamic> memberMap}) async {
    DocumentReference conversationRef;
    DocumentReference postRef = _db.collection('directposts').document();
    String convoId = conversationId;
    WriteBatch batch = _db.batch();

    //Check if conversation with these members exists
    List<String> _memberList = new List<String>();
    if(memberMap != null) {
      _memberList.addAll(memberMap.keys);
    }
    _memberList.sort();
    if(convoId == null){
      await Firestore.instance.collection('conversations').where('memberList', isEqualTo: _memberList).getDocuments().then((snapshot) {
        if(snapshot.documents.isNotEmpty) {
          DocumentSnapshot conversation = snapshot.documents.first;
          if(conversation != null)
            conversationRef = conversation.reference;
            convoId = conversation.reference.documentID;
        }
      });
    }

    //If conversation exists, add post to conversation, otherwise create new conversation and add post
    if(convoId != null) {
      print('Conversation exists: $convoId');
      conversationRef = _db.collection('conversations').document(convoId);
      //Get post map and conversationMembers
      Map<String, dynamic> postMap;
      Map<String, dynamic> conversationMembers;
      await conversationRef.get().then((DocumentSnapshot snapshot) {
        postMap = Map<String, dynamic>.from(snapshot.data['postMap']);
        conversationMembers = Map<String, dynamic>.from(snapshot.data['conversationMembers']);
      });

      //-increment unread posts for all users other than posting user
      print('Members: $conversationMembers');
      Map<String, dynamic> newMemberMap = new Map<String, dynamic>();
      conversationMembers.forEach((uid, details) {
        Map<dynamic, dynamic> newDetails = details;
        if(uid != sender.uid) {
          int unheardCnt = details['unreadPosts'];
          if(unheardCnt != null)
            unheardCnt = unheardCnt + 1;
          newDetails['unreadPosts'] = unheardCnt;
        }
        newMemberMap[uid] = newDetails;
      });

      postMap.addAll({postRef.documentID: sender.uid});
      //update conversation document
      batch.updateData(conversationRef, {'postMap': postMap, 'lastDate': DateTime.now(), 'lastPostUsername': sender.username, 'lastPostUserId': sender.uid, 'conversationMembers': newMemberMap});
    } else {
      //Create new conversation document and update data
      conversationRef = Firestore.instance.collection('/conversations').document();
      convoId = conversationRef.documentID;
      print('creating new conversation: $conversationId');
      Map<String, dynamic> conversationMembers = new Map<String, dynamic>();
      memberMap.forEach((uid, username) {
        if(uid == sender.uid)
          conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 0}});
        else
          conversationMembers.addAll({uid: {'username': username, 'unreadPosts': 1}});
      });
      Map<String, dynamic> postMap = {postRef.documentID: sender.uid};

      batch.setData(conversationRef, {'conversationMembers': conversationMembers, 'postMap': postMap, 'memberList': _memberList, 'lastDate': DateTime.now(), 'lastPostUsername': sender.username, 'lastPostUserId': sender.uid});
    }

    //Add data to new direct post document (message title, contentUrl, length (ms), date, sender, conversationId, shared, podcast and episode info)
    Map<String, dynamic> newPostData = {
      'senderUID': sender.uid,
      'senderUsername': sender.username,
      'author': podcast.title,
      'podcast-link': podcast.link,
      'podcast-url': podcast.url,
      'podcast-title': podcast.title,
      'podcast-image': podcast.image,
      'episode-guid': episode.guid,
      'episode-description': episode.description,
      'episode-link': episode.link,
      'messageTitle': episode.title,
      'ms-length': episode.duration.inMilliseconds,
      'audioFileLocation': episode.contentUrl,
      'conversationId': convoId,
      'datePosted': DateTime.now(),
      'shared': true,
    };

    batch.setData(postRef, newPostData);

    await batch.commit().catchError(((error) {
      print('Error committing batch: $error');
    }));
    print('batch committed');
  }
}