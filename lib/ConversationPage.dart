import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:Perkl/services/models.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:podcast_search/podcast_search.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import 'EpisodePage.dart';
import 'ListTileBubble.dart';
import 'main.dart';
import 'services/UserManagement.dart';
import 'services/ActivityManagement.dart';

import 'ProfilePage.dart';

//New Version
class ConversationPageMobile extends StatelessWidget {
  String conversationId;
  String pageTitle;

  ConversationPageMobile({this.conversationId, this.pageTitle});

  @override
  build(BuildContext context) {
    User firebaseUser = Provider.of<User>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PlaybackState playbackState = Provider.of<PlaybackState>(context);
    MediaItem currentMediaItem = Provider.of<MediaItem>(context);
    return MultiProvider(
      providers: [
        StreamProvider<List<DirectPost>>(create: (_) => DBService().streamDirectPosts(conversationId)),
        StreamProvider<PerklUser>(create: (_) => UserManagement().streamCurrentUser(firebaseUser))
      ],
      child: Consumer<List<DirectPost>>(
        builder: (context, postList, _) {
          PerklUser user = Provider.of<PerklUser>(context);
          List<DayPosts> days = <DayPosts>[];
          if(postList != null) {
            postList.forEach((post) {
              if(days.where((day) => day.date.year == post.datePosted.year && day.date.month == post.datePosted.month && day.date.day == post.datePosted.day).length > 0) {
                days.where((day) => day.date.year == post.datePosted.year && day.date.month == post.datePosted.month && day.date.day == post.datePosted.day).first.list.add(post);
              } else {
                List posts = [];
                posts.add(post);
                days.add(DayPosts(date: DateTime(post.datePosted.year, post.datePosted.month, post.datePosted.day), list: posts));
              }
            });
          }
          return MainPageTemplate(
            isConversation: true,
            conversationId: conversationId,
            bottomNavIndex: 2,
            pageTitle: pageTitle,
            body: postList == null ? Center(child: CircularProgressIndicator()) : Stack(
              children: <Widget>[
                ListView(
                    children: days.map((day) {
                      return Container(
                        padding: EdgeInsets.only(bottom: 10),
                        child: Row(
                            children: <Widget>[
                              Expanded(
                                  child: Container(
                                    margin: EdgeInsets.only(left: 10),
                                    padding: EdgeInsets.only(left: 5),
                                    decoration: BoxDecoration(
                                        border: Border(
                                            left: BorderSide(color: Colors.deepPurple[500], width: 2)
                                        )
                                    ),
                                    child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: <Widget>[
                                          Text(day.date.year == DateTime.now().year && day.date.month == DateTime.now().month && day.date.day == DateTime.now().day ? 'Today' : DateFormat('MMMM dd, yyyy').format(day.date).toString(), style: TextStyle(fontSize: 16, color: Colors.deepPurple[500]), textAlign: TextAlign.left,),
                                          Column(
                                            children: day.list.map((post) {
                                              DirectPost directPost = post;
                                              return StreamBuilder<PerklUser>(
                                                stream: UserManagement().streamUserDoc(directPost.senderUID),
                                                builder: (context, AsyncSnapshot<PerklUser> userSnap) {
                                                  PerklUser sender = userSnap.data;
                                                  if(sender == null) {
                                                    return Container();
                                                  }

                                                  //Return list tile for this direct message
                                                  //Create picUrl widget
                                                  Widget picButton = InkWell(
                                                      onTap: () async {
                                                        Episode episode;
                                                        Podcast pod;
                                                        if(directPost.podcastUrl != null) {
                                                          showDialog(
                                                            context: context,
                                                            builder: (context) {
                                                              return Center(child: CircularProgressIndicator());
                                                            },
                                                          );
                                                          pod = await Podcast.loadFeed(url: directPost.podcastUrl);
                                                          Navigator.of(context).pop();
                                                          episode = pod.episodes.firstWhere((element) => element.contentUrl == directPost.audioFileLocation);
                                                        }
                                                        Navigator.push(context, MaterialPageRoute(
                                                          builder: (context) =>
                                                          episode != null ? EpisodePage(episode, pod) : ProfilePageMobile(userId: sender.uid),
                                                        ));
                                                      },
                                                      child: Container(
                                                          height: 50.0,
                                                          width: 50.0,
                                                          decoration: BoxDecoration(
                                                              shape: directPost.podcastImage != null ? BoxShape.rectangle : BoxShape.circle,
                                                              color: Colors.deepPurple,
                                                              image: DecorationImage(
                                                                  fit: BoxFit.cover,
                                                                  image: NetworkImage(directPost.podcastImage ?? sender.profilePicUrl ?? 'gs://flutter-fire-test-be63e.appspot.com/FCMImages/logo.png')
                                                              )
                                                          )
                                                      )
                                                  );

                                                  //Create play button column
                                                  Widget playColumn = Column(
                                                    crossAxisAlignment: CrossAxisAlignment.center,
                                                    mainAxisAlignment: MainAxisAlignment.center,
                                                    children: <Widget>[
                                                      InkWell(
                                                        child: Container(
                                                          height: 35,
                                                          width: 35,
                                                          decoration: BoxDecoration(
                                                              shape: BoxShape.circle,
                                                              color: currentMediaItem != null && currentMediaItem.id == directPost.audioFileLocation ? Colors.red : Colors.deepPurple
                                                          ),
                                                          child: Center(child: FaIcon(currentMediaItem != null && currentMediaItem.id == directPost.audioFileLocation && playbackState != null && playbackState.playing != null && playbackState.playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                                                        ),
                                                        onTap: () {
                                                          playbackState.playing != null && playbackState.playing && currentMediaItem.id == directPost.audioFileLocation ? mp.pausePost() : mp.playPost(PostPodItem.fromDirectPost(post));
                                                          mp.notifyListeners();
                                                        },
                                                      ),
                                                      Text(post.getLengthString())
                                                    ],
                                                  );

                                                  return ListTileBubble(
                                                    width: MediaQuery.of(context).size.width - 50,
                                                    alignment: user.uid == sender.uid ? MainAxisAlignment.end : MainAxisAlignment.start,
                                                    leading: user.uid == sender.uid ? playColumn : picButton,
                                                    trailing: user.uid == sender.uid ? picButton : playColumn,
                                                    color: directPost.shared != null && directPost.shared ? Colors.pink[50] : user.uid == sender.uid ? Colors.blueGrey[50] : Colors.deepPurple[50],
                                                    title: Text(directPost.messageTitle ?? '@${directPost.senderUsername}', style: TextStyle(fontSize: 14), textAlign: user.uid == sender.uid ? TextAlign.right : TextAlign.left),
                                                    subTitle: directPost.podcastTitle != null ? Column(crossAxisAlignment: user.uid == sender.uid ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: <Widget>[Text('${directPost.podcastTitle}'), Text('shared by @${sender.username}', style: TextStyle(color: Colors.grey),)],) : directPost.messageTitle != null ? Text('@${directPost.senderUsername}', style: TextStyle(fontSize: 14), textAlign: user.uid == sender.uid ? TextAlign.right : TextAlign.left,) : null,
                                                    onTap: () async {
                                                      if(playbackState.playing) {
                                                        mp.stopPost();
                                                      }
                                                      await ActivityManager().sendDirectPostDialog(context, conversationId: conversationId);
                                                    },
                                                  );
                                                } ,
                                              );
                                            }).toList(),
                                          )
                                        ]
                                    ),
                                  )
                              )
                            ]
                        ),
                      );
                    }).toList()
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: <Widget>[
                      TextButton(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          backgroundColor: Colors.deepPurple,
                        ),
                        child: Text('Play Unheard', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          await mp.addUnheardToQueue(conversationId: conversationId, userId: firebaseUser.uid);
                        },
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                          backgroundColor: Colors.deepPurple,
                        ),
                        child: Text('Reply', style: TextStyle(color: Colors.white)),
                        onPressed: () async {
                          if(playbackState.playing) {
                            mp.stopPost();
                          }
                          await mp.activityManager.sendDirectPostDialog(context, conversationId: conversationId);
                        },
                      )
                    ],
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