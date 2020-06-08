import 'package:Perkl/services/UserManagement.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'ProfilePage.dart';
import 'StreamTagPage.dart';
import 'services/models.dart';
import 'services/db_services.dart';
import 'main.dart';

enum TimelineType {
  STREAMTAG,
  MAINFEED,
  USER,
}

class Timeline extends StatelessWidget {
  String timelineId;
  Stream tagStream;
  String userId;
  TimelineType type;

  Timeline({this.timelineId, this.tagStream, this.userId, this.type});

  @override
  build(BuildContext context) {
    FirebaseUser firebaseUser = Provider.of<FirebaseUser>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    //print('TimelineId: $timelineId/StreamTag: $tagStream/UserId: $userId');
    Stream postStream;
    if(tagStream != null) {
      postStream = tagStream;
      //print('Grabbed stream for tag: $tagStream');
    } else {
      postStream = DBService().streamTimelinePosts(firebaseUser, timelineId: timelineId, userId: userId);
    }
    return MultiProvider(
      providers: [
        StreamProvider<List<Post>>(create: (_) => postStream),
        StreamProvider<User>(create: (_) => UserManagement().streamCurrentUser(firebaseUser))
      ],
      child: StreamBuilder<List<Post>>(
        stream: postStream,
        builder: (context, AsyncSnapshot<List<Post>> postListSnap) {
          User currentUser = Provider.of<User>(context);
          List<Post> postList = postListSnap.data;
          if(postList != null) {
            //print('setting page posts');
            mp.setPagePosts(postList);
          }
          //print('Post List: ${postList != null ? postList.length : ''}');
          String emptyText = 'Looks like there are\'nt any posts to show here!';
          if(type == TimelineType.MAINFEED)
            emptyText = 'Your Timeline is Empty! Try following some users!';
          if(type == TimelineType.USER && currentUser != null && userId == currentUser.uid)
            emptyText = 'You have no posts! Try recording and say hello!';
          if(type == TimelineType.USER && currentUser != null && userId != currentUser.uid)
            emptyText = 'This user hasn\'t posted yet!';
          if(type == TimelineType.STREAMTAG)
            emptyText = 'There aren\'t any posts for this tag yet!';
          return ListView(
            children: postList == null ? [Center(child: CircularProgressIndicator())] : postList.length == 0 ? [Center(child: Text(emptyText))] : postList.map((post) {
              return StreamProvider<User>(
                create: (context) => UserManagement().streamUserDoc(post.userUID),
                child: Consumer<User>(
                  builder: (context, poster, _) {
                    return Column(
                      children: <Widget>[
                        ExpansionTile(
                          leading: poster == null || poster.profilePicUrl == null ? Container(
                            height: 60.0,
                            width: 60.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.deepPurple,
                            ),
                            child: InkWell(
                              child: Container(),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) =>
                                      ProfilePageMobile(userId: post.userUID,),
                                ));
                              },
                            ),
                          ) : Container(
                            height: 60.0,
                            width: 60.0,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.deepPurple,
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: NetworkImage(poster.profilePicUrl),
                              ),
                            ),
                            child: InkWell(
                              child: Container(),
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) =>
                                      ProfilePageMobile(userId: post.userUID,),
                                ));
                              },
                            )
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text('@${post.username}'),
                              Text('${post.postTitle != null ? post.postTitle : DateFormat('MMMM dd, yyyy hh:mm').format(post.datePosted)}'),
                              post.postTitle != null ? Text(DateFormat('MMMM dd, yyyy hh:mm').format(post.datePosted))  : Container(),
                            ],
                          ),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: <Widget>[
                              Container(
                                width: 80,
                                child: Row(
                                  children: <Widget>[
                                    InkWell(
                                      child: Container(
                                        height: 35,
                                        width: 35,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: mp.currentPostId == post.id ? Colors.red : Colors.deepPurple
                                        ),
                                        child: Center(child: FaIcon(mp.currentPostId == post.id && mp.isPlaying != null && mp.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                                      ),
                                      onTap: () {
                                        mp.isPlaying != null && mp.isPlaying && mp.currentPostId == post.id ? mp.pausePost() : mp.playPost(post: post);
                                      },
                                    ),
                                    SizedBox(width: 5,),
                                    InkWell(
                                      child: Container(
                                        height: 35,
                                        width: 35,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: mp.queue.where((p) => p.id == post.id).length > 0 ? Colors.grey : Colors.deepPurple
                                        ),
                                        child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16)),
                                      ),
                                      onTap: () {
                                        if(mp.queue.where((p) => p.id == post.id).length <= 0)
                                          mp.addPostToQueue(post);
                                      },
                                    )
                                  ],
                                ),
                              ),
                              Text(post.getLengthString())
                            ],
                          ),
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                SizedBox(width: 90),
                                Expanded(
                                  child: post.streamList != null && post.streamList.length > 0 ? Wrap(
                                    spacing: 8,
                                    children: post.streamList.map((tag) => InkWell(
                                      child: Text('#$tag', style: TextStyle(color: Colors.lightBlue)),
                                      onTap: () {
                                        Navigator.push(context, MaterialPageRoute(
                                            builder: (context) => StreamTagPageMobile(tag: tag,)
                                        ));
                                      }
                                    )).toList(),
                                  ) : Container(),
                                ),
                                currentUser != null && post.userUID == currentUser.uid ? Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: <Widget>[
                                    IconButton(icon: Icon(Icons.delete_forever)),
                                    IconButton(icon: Icon(Icons.file_download))
                                  ],
                                ) : IconButton(icon: Icon(Icons.file_download),)
                              ],
                            )
                          ],
                        ),
                        Divider(height: 10, thickness: 1,)
                      ],
                    );
                  },
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}