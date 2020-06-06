import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'models.dart';

class DBService {
  Firestore _db = Firestore.instance;

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
}