import 'package:Perkl/MainPageTemplate.dart';
import 'package:audio_service/audio_service.dart';
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
import 'PodcastPage.dart';

class EpisodePage extends StatelessWidget {
  Episode _episode;
  Podcast _podcast;

  EpisodePage(this._episode, this._podcast);

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PlaybackState playbackState = Provider.of<PlaybackState>(context);
    MediaItem currentMediaItem = Provider.of<MediaItem>(context);
    List<MediaItem> mediaQueue = Provider.of<List<MediaItem>>(context);
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
          Card(
            elevation: 5,
            margin: EdgeInsets.all(5),
            child: Padding(
              padding: EdgeInsets.all(0),
              child: Row(
                  children: <Widget>[
                    Padding(
                        padding: EdgeInsets.all(10),
                        child: Column(
                          children: <Widget>[
                            InkWell(
                              child: Container(
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
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) => PodcastPage(_podcast),
                                ));
                              },
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
                                        color: currentMediaItem != null && currentMediaItem.id == _episode.contentUrl ? Colors.red : Colors.deepPurple//mp.queue.where((p) => p.id == post.id).length > 0 ? Colors.grey : Colors.deepPurple
                                    ),
                                    child: Center(child: FaIcon(playbackState.playing && currentMediaItem.id == _episode.contentUrl ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                                  ),
                                  onTap: () {
                                    if(playbackState != null && currentMediaItem != null && playbackState.playing && currentMediaItem.id == _episode.contentUrl)
                                      mp.pausePost();
                                    else
                                      mp.playPost(PostPodItem.fromEpisode(_episode, _podcast));
                                  },
                                ),
                                SizedBox(width: 5),
                                InkWell(
                                  child: Container(
                                    height: 35,
                                    width: 35,
                                    decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: mediaQueue != null && mediaQueue.where((p) => p.id == _episode.contentUrl).length > 0 ? Colors.grey : Colors.deepPurple
                                    ),
                                    child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16)),
                                  ),
                                  onTap: () {
                                    if(mediaQueue == null || mediaQueue.where((MediaItem p) => p.id == _episode.contentUrl).length <= 0)
                                      mp.addPostToQueue(PostPodItem.fromEpisode(_episode, _podcast));
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
                          width: MediaQuery.of(context).size.width - 160,
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
            )
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
                    return Card(
                      elevation: 5,
                      color: Colors.deepPurple[50],
                      margin: EdgeInsets.all(5),
                      child: Padding(
                        padding: EdgeInsets.all(5),
                        child: ListTile(
                          leading: StreamBuilder<PerklUser>(
                            stream: UserManagement().streamUserDoc(reply.posterUid),
                            builder: (context, AsyncSnapshot<PerklUser> userSnap) {
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
                          title: Text(reply.replyTitle != null ? reply.replyTitle : DateFormat("MMMM dd, yyyy @ hh:mm a").format(reply.replyDate).toString()),
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
                                            color: currentMediaItem.id == reply.audioFileLocation ? Colors.red : Colors.deepPurple
                                        ),
                                        child: Center(child: FaIcon(currentMediaItem.id == reply.audioFileLocation && playbackState.playing != null && playbackState.playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                                      ),
                                      onTap: () {
                                        playbackState.playing != null && playbackState.playing && currentMediaItem.id == reply.audioFileLocation ? mp.pausePost() : mp.playPost(PostPodItem.fromEpisodeReply(reply, _episode, _podcast));
                                      },
                                    ),
                                    SizedBox(width: 5,),
                                    InkWell(
                                      child: Container(
                                        height: 35,
                                        width: 35,
                                        decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AudioServiceBackground.queue != null && AudioServiceBackground.queue.where((p) => p.id == reply.audioFileLocation).length > 0 ? Colors.grey : Colors.deepPurple
                                        ),
                                        child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16)),
                                      ),
                                      onTap: () {
                                        if(AudioServiceBackground.queue != null && AudioServiceBackground.queue.where((p) => p.id == reply.audioFileLocation).length <= 0)
                                          mp.addPostToQueue(PostPodItem.fromEpisodeReply(reply, _episode, _podcast));
                                      },
                                    )
                                  ],
                                ),
                                Text(getDurationString(reply.replyDuration))
                              ],
                            ),
                          ),
                        )
                      )
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