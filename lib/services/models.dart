import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
//import 'package:html_unescape/html_unescape.dart';
import 'UserManagement.dart';
import 'ActivityManagement.dart';

class User {
  String uid;
  String email;
  String bio;
  String username;
  List<String> followers;
  List<String> following;
  String profilePicUrl;
  String mainFeedTimelineId;
  List<String> timelinesIncluded;
  Map<String, dynamic> directConversationMap;
  List<String> posts;

  User({
    this.uid,
    this.email,
    this.bio,
    this.username,
    this.followers,
    this.following,
    this.profilePicUrl,
    this.mainFeedTimelineId,
    this.timelinesIncluded,
    this.directConversationMap,
    this.posts
  });

  factory User.fromFirestore(DocumentSnapshot snapshot) {
    return User(
      uid: snapshot.documentID,
      email: snapshot.data['email'],
      bio: snapshot.data['bio'],
      username: snapshot.data['username'],
      followers: snapshot.data['followers'] == null ? null : snapshot.data['followers'].entries.map<String>((entry) {
        print('follower');
        String userId = entry.key;
        return userId;
      }).toList(),
      following: snapshot.data['following'] == null ? null : snapshot.data['following'].entries.map<String>((entry) {
        print('following');
        String userId = entry.key;
        return userId;
      }).toList(),
      profilePicUrl: snapshot.data['profilePicUrl'],
      mainFeedTimelineId: snapshot.data['mainFeedTimelineId'],
      timelinesIncluded: snapshot.data['timelinesIncluded'] == null ? null : snapshot.data['timelinesIncluded'].entries.map<String>((entry) {
        print('timelines');
        String timelineId = entry.key;
        return timelineId;
      }).toList(),
      directConversationMap: snapshot.data['directConversationMap'] == null ? null : Map.from(snapshot.data['directConversationMap']),
      posts: snapshot.data['posts'] == null ? null : snapshot.data['posts'].entries.map<String>((entry) {
        String postId = entry.key;
        return postId;
      }).toList(),
    );
  }
}

class DiscoverTag {
  String value;
  int rank;
  String type;

  DiscoverTag({this.value, this.rank, this.type});

  factory DiscoverTag.fromFirestore(DocumentSnapshot snap) {
    return DiscoverTag(
      value: snap.data['value'],
      rank: snap.data['rank'],
      type: snap.data['type'],
    );
  }
}

class Conversation {
  String id;
  List<String> memberList;
  DateTime lastDate;
  String lastPostUsername;
  String lastPostUserId;
  Map<String, dynamic> conversationMembers;
  Map<String, dynamic> postMap;

  Conversation({
    this.id,
    this.memberList,
    this.lastDate,
    this.lastPostUsername,
    this.lastPostUserId,
    this.conversationMembers,
    this.postMap,
  });

  factory Conversation.fromFirestore(DocumentSnapshot snapshot) {
    return Conversation(
      id: snapshot.documentID,
      memberList: snapshot.data['memberList'] == null ? null : snapshot.data['memberList'].map<String>((value) => value.toString()).toList(),
      lastDate: snapshot.data['lastDate'] == null ? null : DateTime.fromMillisecondsSinceEpoch(snapshot.data['lastDate'].millisecondsSinceEpoch),
      lastPostUsername: snapshot.data['lastPostUsername'],
      lastPostUserId: snapshot.data['lastPostUserId'],
      conversationMembers: snapshot.data['conversationMembers'] == null ? null : Map<String, dynamic>.from(snapshot.data['conversationMembers']),
      postMap: snapshot.data['postMap'] == null ? null : Map<String, dynamic>.from(snapshot.data['postMap']),
    );
  }
}

class DirectPost {
  String id;
  String conversationId;
  String senderUID;
  String senderUsername;
  String audioFileLocation;
  DateTime datePosted;
  String messageTitle;
  int secondsLength;

  DirectPost({
    this.id,
    this.conversationId,
    this.senderUID,
    this.senderUsername,
    this.audioFileLocation,
    this.datePosted,
    this.messageTitle,
    this.secondsLength,
  });

  factory DirectPost.fromFirestore(DocumentSnapshot snap) {
    return DirectPost(
      id: snap.documentID,
      conversationId: snap.data['conversationId'],
      senderUID: snap.data['senderUID'],
      senderUsername: snap.data['senderUsername'],
      audioFileLocation: snap.data['audioFileLocation'],
      datePosted: DateTime.fromMillisecondsSinceEpoch(snap.data['datePosted'].millisecondsSinceEpoch),
      messageTitle: snap.data['messageTitle'],
      secondsLength: snap.data['secondsLength']
    );
  }

  String getLengthString() {
    String postLength = '--:--';
    if(secondsLength != null) {
      Duration postDuration = Duration(seconds: secondsLength);
      if(postDuration.inHours > 0){
        postLength = '${postDuration.inHours}:${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      } else {
        postLength = '${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      }
    }
    return postLength;
  }
}

class Post {
  String id;
  String userUID;
  String username;
  String postTitle;
  DateTime datePosted;
  String postValue;
  String audioFileLocation;
  int listenCount;
  int secondsLength;
  List<String> streamList;
  List<String> timelines;

  Post({
    this.id,
    this.userUID,
    this.username,
    this.postTitle,
    this.datePosted,
    this.postValue,
    this.audioFileLocation,
    this.listenCount,
    this.secondsLength,
    this.streamList,
    this.timelines,
  });

  factory Post.fromFirestore(DocumentSnapshot snap) {
    return Post(
      id: snap.documentID,
      userUID: snap.data['userUID'],
      username: snap.data['username'],
      postTitle: snap.data['postTitle'],
      datePosted: DateTime.fromMillisecondsSinceEpoch(snap.data['datePosted'].millisecondsSinceEpoch),
      postValue: snap.data['postValue'],
      audioFileLocation: snap.data['audioFileLocation'],
      listenCount: snap.data['listenCount'],
      secondsLength: snap.data['secondsLength'],
      streamList: snap.data['streamList'] == null ? null : snap.data['streamList'].map<String>((item) => item.toString()).toList(),
      timelines: snap.data['timelines'] == null ? null : snap.data['timelines'].map<String>((item) => item.toString()).toList(),
    );
  }

  String getLengthString() {
    String postLength = '--:--';
    if(secondsLength != null) {
      Duration postDuration = Duration(seconds: secondsLength);
      if(postDuration.inHours > 0){
        postLength = '${postDuration.inHours}:${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      } else {
        postLength = '${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      }
    }
    return postLength;
  }
}

class PostPosition {
  Duration duration;

  PostPosition({this.duration});

  String getPostPosition() {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    String minutesString = minutes >= 10 ? '$minutes' : '0$minutes';
    String secondsString = seconds >= 10 ? '$seconds' : '0$seconds';
    if(hours > 0)
      return '$hours:$minutesString:$secondsString';
    return '$minutesString:$secondsString';
  }
}

class PostDuration {
  Duration duration;

  PostDuration({this.duration});

  String getPostDuration() {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    String minutesString = minutes >= 10 ? '$minutes' : '0$minutes';
    String secondsString = seconds >= 10 ? '$seconds' : '0$seconds';
    if(hours > 0)
      return '$hours:$minutesString:$secondsString';
    return '$minutesString:$secondsString';
  }
}