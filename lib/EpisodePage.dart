import 'package:Perkl/MainPageTemplate.dart';
import 'package:flutter/material.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:provider/provider.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'main.dart';
import 'services/models.dart';
import 'services/db_services.dart';
import 'services/UserManagement.dart';
import 'ProfilePage.dart';

class EpisodePage extends StatelessWidget {
  Episode _episode;
  Podcast _podcast;

  EpisodePage(this._episode, this._podcast);

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    print('Episode Guid: ${_episode.guid}/Episode Link: ${_episode.link}');

    String getDurationString(Duration duration) {
      int hours = duration.inHours;
      int minutes = duration.inMinutes.remainder(60);
      int seconds = duration.inSeconds.remainder(60);
      String minutesString = minutes >= 10 ? '$minutes' : '0$minutes';
      String secondsString = seconds >= 10 ? '$seconds' : '0$seconds';
      if(hours > 0)
        return '$hours:$minutesString:$secondsString';
      return '$minutesString:$secondsString';
    }

    return MainPageTemplate(
      bottomNavIndex: 1,
      noBottomNavSelected: true,
      body: Column(
        children: <Widget>[
          Row(
              children: <Widget>[
                Padding(
                    padding: EdgeInsets.all(10),
                    child: Column(
                      children: <Widget>[
                        Container(
                            height: 120,
                            width: 120,
                            decoration: _podcast.image != null ?  BoxDecoration(
                                image: DecorationImage(
                                    image: NetworkImage(_podcast.image),
                                    fit: BoxFit.cover
                                )
                            ) : BoxDecoration(
                                color: Colors.deepPurple
                            )
                        ),
                        SizedBox(height: 10,),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: <Widget>[
                            InkWell(
                              child: Container(
                                height: 35,
                                width: 35,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.deepPurple// mp.queue.where((p) => p.id == post.id).length > 0 ? Colors.grey : Colors.deepPurple
                                ),
                                child: Center(child: FaIcon(FontAwesomeIcons.reply, color: Colors.white, size: 16)),
                              ),
                              onTap: () {
                                mp.replyToEpisode(_episode, _podcast, context);
                              },
                            ),
                            SizedBox(width: 5),
                            InkWell(
                              child: Container(
                                height: 35,
                                width: 35,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: mp.currentPostPodId == (_episode.guid == null ? _episode.link : _episode.guid) ? Colors.red : Colors.deepPurple//mp.queue.where((p) => p.id == post.id).length > 0 ? Colors.grey : Colors.deepPurple
                                ),
                                child: Center(child: FaIcon(mp.isPlaying && mp.currentPostPodId == (_episode.guid == null ? _episode.link : _episode.guid) ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                              ),
                              onTap: () {
                                if(mp.isPlaying && mp.currentPostPodId == (_episode.guid == null ? _episode.link : _episode.guid))
                                  mp.pausePost();
                                else
                                  mp.playPost(PostPodItem.fromEpisode(_episode));
                              },
                            ),
                            SizedBox(width: 5),
                            InkWell(
                              child: Container(
                                height: 35,
                                width: 35,
                                decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: mp.queue.where((p) => p.id == (_episode.guid != null ? _episode.guid : _episode.link)).length > 0 ? Colors.grey : Colors.deepPurple
                                ),
                                child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16)),
                              ),
                              onTap: () {
                                if(mp.queue.where((PostPodItem p) => p.id == (_episode.guid != null ? _episode.guid : _episode.link)).length <= 0)
                                  mp.addPostToQueue(PostPodItem.fromEpisode(_episode));
                              },
                            ),
                          ],
                        ),
                      ],
                    )
                ),
                Padding(
                    padding: EdgeInsets.fromLTRB(0, 10, 10, 10),
                    child: Container(
                      height: 150,
                      width: MediaQuery.of(context).size.width - 150,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text('${_episode.title}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Text('${_podcast.title}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            Expanded(
                              child: SingleChildScrollView(
                                child: Html(data: _episode.description,),
                              ),
                            )
                          ]
                      ),

                    )
                )
              ]
          ),
          Expanded(
            child: StreamBuilder<List<EpisodeReply>>(
              stream: DBService().streamEpisodeReplies(_episode.guid != null ? _episode.guid : _episode.link),
              builder: (context, AsyncSnapshot<List<EpisodeReply>> listSnap) {
                List<EpisodeReply> replyList = listSnap.data;
                if(replyList == null || replyList.length == 0)
                  return Center(child: Text('Be the first to record a comment!'));
                return ListView(
                  children: replyList.map((reply) {
                    return ListTile(
                      leading: StreamBuilder<User>(
                        stream: UserManagement().streamUserDoc(reply.posterUid),
                        builder: (context, AsyncSnapshot<User> userSnap) {
                          return Container(
                              height: 60.0,
                              width: 60.0,
                              decoration: userSnap.data == null ? BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.deepPurple,
                              ) : BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.deepPurple,
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: NetworkImage(userSnap.data.profilePicUrl),
                                ),
                              ),
                              child: InkWell(
                                child: Container(),
                                onTap: () {
                                  Navigator.push(context, MaterialPageRoute(
                                    builder: (context) =>
                                        ProfilePageMobile(userId: userSnap.data.uid,),
                                  ));
                                },
                              )
                          );
                        },
                      ),
                      title: Text(reply.replyTitle != null ? reply.replyTitle : DateFormat("MMMM dd, yyyy @ HH:MM").format(reply.replyDate).toString()),
                      subtitle: Text('@${reply.posterUsername}', style: TextStyle(fontSize: 16)),
                      trailing: Container(
                        width: 85,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                InkWell(
                                  child: Container(
                                    height: 35,
                                    width: 35,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: mp.currentPostPodId == reply.id ? Colors.red : Colors.deepPurple
                                    ),
                                    child: Center(child: FaIcon(mp.currentPostPodId == reply.id && mp.isPlaying != null && mp.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                                  ),
                                  onTap: () {
                                    mp.isPlaying != null && mp.isPlaying && mp.currentPostPodId == reply.id ? mp.pausePost() : mp.playPost(PostPodItem.fromEpisodeReply(reply));
                                  },
                                ),
                                SizedBox(width: 5,),
                                InkWell(
                                  child: Container(
                                    height: 35,
                                    width: 35,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: mp.queue.where((p) => p.id == reply.id).length > 0 ? Colors.grey : Colors.deepPurple
                                    ),
                                    child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16)),
                                  ),
                                  onTap: () {
                                    if(mp.queue.where((p) => p.id == reply.id).length <= 0)
                                      mp.addPostToQueue(PostPodItem.fromEpisodeReply(reply));
                                  },
                                )
                              ],
                            ),
                            Text(getDurationString(reply.replyDuration))
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            )
          )
        ],
      ),
    );
  }
}