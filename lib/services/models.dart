import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:audio_service/audio_service.dart';

class PerklUser {
  String uid;
  String email;
  String bio;
  String username;
  List<String> followers;
  List<String> following;
  String profilePicUrl;
  String mainFeedTimelineId;
  List<String> followedPodcasts;
  List<String> timelinesIncluded;
  Map<String, dynamic> directConversationMap;
  List<String> posts;
  List<Podcast> podcastList;

  PerklUser({
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
    this.posts,
    this.followedPodcasts,
  });

  factory PerklUser.fromFirestore(DocumentSnapshot snapshot) {
    PerklUser newUser = new PerklUser(
      uid: snapshot.reference.id,
      email: snapshot.data()['email'],
      bio: snapshot.data()['bio'],
      username: snapshot.data()['username'],
      followers: snapshot.data()['followers'] == null ? null : snapshot.data()['followers'].entries.map<String>((entry) {
        String userId = entry.key;
        return userId;
      }).toList(),
      following: snapshot.data()['following'] == null ? null : snapshot.data()['following'].entries.map<String>((entry) {
        String userId = entry.key;
        return userId;
      }).toList(),
      profilePicUrl: snapshot.data()['profilePicUrl'],
      mainFeedTimelineId: snapshot.data()['mainFeedTimelineId'],
      followedPodcasts: snapshot.data()['followedPodcasts'] == null ? null : snapshot.data()['followedPodcasts'].map<String>((entry) {
        String podcastUrl = entry;
        return podcastUrl.replaceFirst('http:', 'https:');
      }).toList(),
      timelinesIncluded: snapshot.data()['timelinesIncluded'] == null ? null : snapshot.data()['timelinesIncluded'].entries.map<String>((entry) {
        //print('timelines');
        String timelineId = entry.key;
        return timelineId;
      }).toList(),
      directConversationMap: snapshot.data()['directConversationMap'] == null ? null : Map.from(snapshot.data()['directConversationMap']),
      posts: snapshot.data()['posts'] == null ? null : snapshot.data()['posts'].entries.map<String>((entry) {
        String postId = entry.key;
        return postId;
      }).toList(),
    );
    return newUser;
  }
}

class CurrentUser {
  PerklUser user;
  bool isLoaded = true;

  CurrentUser({this.user, this.isLoaded});
}

class DiscoverTag {
  String value;
  int rank;
  String type;

  DiscoverTag({this.value, this.rank, this.type});

  factory DiscoverTag.fromFirestore(DocumentSnapshot snap) {
    return DiscoverTag(
      value: snap.data()['value'],
      rank: snap.data()['rank'],
      type: snap.data()['type'],
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
      id: snapshot.reference.id,
      memberList: snapshot.data()['memberList'] == null ? null : snapshot.data()['memberList'].map<String>((value) => value.toString()).toList(),
      lastDate: snapshot.data()['lastDate'] == null ? null : DateTime.fromMillisecondsSinceEpoch(snapshot.data()['lastDate'].millisecondsSinceEpoch),
      lastPostUsername: snapshot.data()['lastPostUsername'],
      lastPostUserId: snapshot.data()['lastPostUserId'],
      conversationMembers: snapshot.data()['conversationMembers'] == null ? null : Map<String, dynamic>.from(snapshot.data()['conversationMembers']),
      postMap: snapshot.data()['postMap'] == null ? null : Map<String, dynamic>.from(snapshot.data()['postMap']),
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
  int msLength;
  String author;
  String podcastLink;
  String podcastUrl;
  String podcastTitle;
  String podcastImage;
  String episodeGuid;
  String episodeDescription;
  String episodeLink;
  bool shared;


  DirectPost({
    this.id,
    this.conversationId,
    this.senderUID,
    this.senderUsername,
    this.audioFileLocation,
    this.datePosted,
    this.messageTitle,
    this.secondsLength,
    this.author,
    this.podcastLink,
    this.podcastUrl,
    this.podcastTitle,
    this.episodeDescription,
    this.episodeGuid,
    this.episodeLink,
    this.msLength,
    this.shared,
    this.podcastImage,
  });

  factory DirectPost.fromFirestore(DocumentSnapshot snap) {
    return DirectPost(
      id: snap.reference.id,
      conversationId: snap.data()['conversationId'],
      senderUID: snap.data()['senderUID'],
      senderUsername: snap.data()['senderUsername'],
      audioFileLocation: snap.data()['audioFileLocation'],
      datePosted: DateTime.fromMillisecondsSinceEpoch(snap.data()['datePosted'].millisecondsSinceEpoch),
      messageTitle: snap.data()['messageTitle'],
      secondsLength: snap.data()['secondsLength'],
      author: snap.data()['author'],
      podcastLink: snap.data()['podcast-link'],
      podcastUrl: snap.data()['podcast-url'],
      podcastTitle: snap.data()['podcast-title'],
      podcastImage: snap.data()['podcast-image'],
      episodeGuid: snap.data()['episode-guid'],
      episodeLink: snap.data()['episode-link'],
      episodeDescription: snap.data()['episode-description'],
      msLength: snap.data()['ms-length'],
      shared: snap.data()['shared']
    );
  }

  String getLengthString() {
    String postLength = '--:--';
    if(msLength != null) {
      Duration postDuration = Duration(milliseconds: msLength);
      if(postDuration.inHours > 0){
        postLength = '${postDuration.inHours}:${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      } else {
        postLength = '${postDuration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${postDuration.inSeconds.remainder(60).toString().padLeft(2, '0')}';
      }
    } else if(secondsLength != null) {
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

  Map<String, dynamic> toJson() {
    return {
      'id': this.id,
      'userUID': this.userUID,
      'username': this.username,
      'postTitle': this.postTitle,
      'datePosted': this.datePosted,
      'postValue': this.postValue,
      'audioFileLocation': this.audioFileLocation,
      'listenCount': this.listenCount,
      'secondsLength': this.secondsLength,
      'streamList': this.streamList,
      'timelines': this.timelines,
    };
  }

  factory Post.fromFirestore(DocumentSnapshot snap) {
    return Post(
      id: snap.reference.id,
      userUID: snap.data()['userUID'],
      username: snap.data()['username'],
      postTitle: snap.data()['postTitle'],
      datePosted: DateTime.fromMillisecondsSinceEpoch(snap.data()['datePosted'].millisecondsSinceEpoch),
      postValue: snap.data()['postValue'],
      audioFileLocation: snap.data()['audioFileLocation'],
      listenCount: snap.data()['listenCount'],
      secondsLength: snap.data()['secondsLength'],
      streamList: snap.data()['streamList'] == null ? null : snap.data()['streamList'].map<String>((item) => item.toString()).toList(),
      timelines: snap.data()['timelines'] == null ? null : snap.data()['timelines'].map<String>((item) => item.toString()).toList(),
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

enum PostType {
  POST,
  DIRECT_POST,
  PODCAST_EPISODE,
  EPISODE_REPLY,
}

class PostPodItem {
  String id;
  PostType type;
  Post post;
  DirectPost directPost;
  Episode episode;
  Podcast podcast;
  EpisodeReply episodeReply;
  String audioUrl;
  String displayText;

  PostPodItem({this.id, this.type, this.post, this.directPost, this.episode, this.audioUrl, this.displayText, this.episodeReply, this.podcast});

  Widget titleText() {
    if(type == PostType.POST) {
      return Text(post.postTitle ?? DateFormat("MMMM dd, yyyy").format(post.datePosted).toString());
    }
    if(type == PostType.DIRECT_POST) {
      return directPost.podcastTitle != null ? Text('${directPost.podcastTitle} | ${directPost.messageTitle}') : directPost.messageTitle != null ? Text('${directPost.messageTitle}') : directPost.datePosted != null ? Text(DateFormat('MMMM dd, yyyy h:mm a').format(directPost.datePosted)) : Container();
    }
    if(type == PostType.PODCAST_EPISODE) {
      return Text(episode.title);
    }
    if(type == PostType.EPISODE_REPLY) {
      return Text(episodeReply.replyTitle ?? DateFormat("MMMM dd, yyyy").format(episodeReply.replyDate).toString());
    }
    return Text('Error Finding Title!');
  }

  Widget subtitleText() {
    if(type == PostType.POST) {
      return Text('@${post.username}');
    }
    if(type == PostType.DIRECT_POST) {
      return Text('@${directPost.senderUsername}');
    }
    if(type == PostType.PODCAST_EPISODE) {
      return Text(episode.author);
    }
    if(type == PostType.EPISODE_REPLY) {
      return Text(episodeReply.posterUsername);
    }
    return Text('Error getting username!');
  }

  String titleTextString() {
    if(type == PostType.POST) {
      return post.postTitle ?? DateFormat("MMMM dd, yyyy").format(post.datePosted).toString();
    }
    if(type == PostType.DIRECT_POST) {
      return directPost.messageTitle != null ? '${directPost.messageTitle}' : DateFormat('MMMM dd, yyyy h:mm a').format(directPost.datePosted);
    }
    if(type == PostType.PODCAST_EPISODE) {
      return episode.title;
    }
    if(type == PostType.EPISODE_REPLY) {
      return episodeReply.replyTitle ?? DateFormat("MMMM dd, yyyy").format(episodeReply.replyDate).toString();
    }
    return 'untitled';
  }

  String subtitleTextString() {
    if(type == PostType.POST) {
      return '@${post.username}';
    }
    if(type == PostType.DIRECT_POST) {
      return '@${directPost.senderUsername}';
    }
    if(type == PostType.PODCAST_EPISODE) {
      return episode.author;
    }
    if(type == PostType.EPISODE_REPLY) {
      return episodeReply.posterUsername;
    }
    return '';
  }

  Duration getDuration() {
    if(post != null && post.secondsLength != null) {
      return Duration(seconds: post.secondsLength);
    }
    if(directPost != null && (directPost.secondsLength != null || directPost.msLength != null)) {
      return directPost.msLength != null ? Duration(milliseconds: directPost.msLength) : Duration(seconds: directPost.secondsLength);
    }
    if(episode != null && episode.duration != null) {
      return episode.duration;
    }
    if(episodeReply != null && episodeReply.replyDuration != null) {
      return episodeReply.replyDuration;
    }
    return Duration(seconds: 0);
  }

  factory PostPodItem.fromPost(Post post) {
    return PostPodItem(
      id: post.id,
      type: PostType.POST,
      post: post,
      audioUrl: post.audioFileLocation,
      displayText: '@${post.username} | ${post.postTitle != null ? post.postTitle : DateFormat('MMMM dd, yyyy hh:mm').format(post.datePosted)}'
    );
  }

  factory PostPodItem.fromDirectPost(DirectPost post) {
    return PostPodItem(
      id: post.id,
      type: PostType.DIRECT_POST,
      directPost: post,
      audioUrl: post.audioFileLocation,
      displayText: '@${post.senderUsername} | ${post.messageTitle != null ? post.messageTitle : DateFormat('MMMM dd, yyyy hh:mm').format(post.datePosted)}'
    );
  }

  factory PostPodItem.fromEpisode(Episode episode, Podcast podcast) {
    return PostPodItem(
      id: episode.guid != null ? episode.guid : episode.link,
      type: PostType.PODCAST_EPISODE,
      episode: episode,
      audioUrl: episode.contentUrl,
      displayText: '${episode.author} | ${episode.title}',
      podcast: podcast,
    );
  }

  factory PostPodItem.fromEpisodeReply(EpisodeReply reply, Episode ep, Podcast podcast) {
    return PostPodItem(
      id: reply.id,
      type: PostType.EPISODE_REPLY,
      episodeReply: reply,
      episode: ep,
      podcast: podcast,
      audioUrl: reply.audioFileLocation,
      displayText: '${reply.posterUsername} | ${reply.replyTitle != null ? reply.replyTitle : DateFormat("MMMM dd, yyyy @HH:mm").format(reply.replyDate).toString()}'
    );
  }

  MediaItem toMediaItem(String currentUserId) {
    return MediaItem(
      id: this.audioUrl,
      title: this.titleTextString(),
      artist: this.subtitleTextString(),
      album: '',
      extras: {
        'type': this.type.toString(),
        'episode': this.episode != null ? this.episode.toJson() : null,
        'podcast_url': this.podcast!= null ? this.podcast.url : null,
        'isDirect': this.type == PostType.DIRECT_POST ? true : false,
        'conversationId': this.directPost != null ? this.directPost.conversationId : null,
        'userId': this.type == PostType.DIRECT_POST ? currentUserId : null,
        'postId': this.directPost != null ? this.directPost.id : null,
        'post': this.post != null ? this.post.toJson() : null,
      },
    );
  }
}

class EpisodeReply {
  String id;
  String uniqueId;
  String episodeName;
  DateTime episodeDate;
  String podcastName;
  String audioFileLocation;
  String posterUid;
  String posterUsername;
  DateTime replyDate;
  Duration replyDuration;
  String replyTitle;

  EpisodeReply({
    this.id,
    this.uniqueId,
    this.episodeName,
    this.episodeDate,
    this.podcastName,
    this.audioFileLocation,
    this.posterUid,
    this.posterUsername,
    this.replyDate,
    this.replyDuration,
    this.replyTitle
  });

  factory EpisodeReply.fromFirestore(DocumentSnapshot snap) {
    return EpisodeReply(
      id: snap.reference.id,
      uniqueId: snap.data()['unique_id'],
      episodeName: snap.data()['episode_name'],
      episodeDate: DateTime.fromMillisecondsSinceEpoch(snap.data()['episode_date'].millisecondsSinceEpoch),
      podcastName: snap.data()['podcast_name'],
      audioFileLocation: snap.data()['audioFileLocation'],
      posterUid: snap.data()['posting_uid'],
      posterUsername: snap.data()['posting_username'],
      replyDate: DateTime.fromMillisecondsSinceEpoch(snap.data()['reply_date'].millisecondsSinceEpoch),
      replyDuration: Duration(milliseconds: snap.data()['reply_ms']),
      replyTitle: snap.data()['reply_title'],
    );
  }
}

enum UserListType {
  FOLLOWERS,
  FOLLOWING
}

class DayPosts {
  DateTime date;
  List list;

  DayPosts({this.date, this.list});
}