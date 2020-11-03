import 'package:Perkl/main.dart';
//import 'package:Perkl/services/UserManagement.dart';
import 'package:Perkl/services/db_services.dart';
import 'package:audio_service/audio_service.dart';
//import 'package:firebase_auth/firebase_auth.dart';
//import 'package:flutter/gestures.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:flutter_html/flutter_html.dart';

import 'services/ActivityManagement.dart';
import 'MainPageTemplate.dart';
import 'EpisodePage.dart';
import 'services/models.dart';

class PodcastPage extends StatelessWidget {
  Podcast podcast;

  PodcastPage(this.podcast);

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    PerklUser user = Provider.of<PerklUser>(context);
    PlaybackState playbackState = Provider.of<PlaybackState>(context);
    MediaItem currentMediaItem = Provider.of<MediaItem>(context);
    List<MediaItem> mediaQueue = Provider.of<List<MediaItem>>(context);
    //print('Followed Podcasts: ${user.followedPodcasts}/Podcast URL: ${podcast.url}/${user.followedPodcasts.contains(podcast.url)}');
    bool podcastFollowed = user.followedPodcasts != null && user.followedPodcasts.contains(podcast.url.replaceFirst('http:', 'https:'));
    return podcast == null ? Center(child: CircularProgressIndicator()) : MainPageTemplate(
      bottomNavIndex: 3,
      noBottomNavSelected: true,
      body: Column(
          children: <Widget>[
            Card(
                elevation: 5,
                margin: EdgeInsets.all(5),
                child: Padding(
                    padding: EdgeInsets.all(5),
                    child: Row(
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.all(5),
                              child: Container(
                                height: 75,
                                width: 75,
                                decoration: podcast.image == null ? BoxDecoration(color: Colors.purple) : BoxDecoration(
                                  image: DecorationImage(image: NetworkImage(podcast.image), fit: BoxFit.cover,),
                                ),
                              ),
                            ),
                            ChangeNotifierProvider<FollowButtonProvider>(
                              create: (_) => FollowButtonProvider(),
                              child: Consumer<FollowButtonProvider>(
                                builder: (context, fbp, _) {
                                  return Container(
                                    decoration: BoxDecoration(
                                        borderRadius: BorderRadius.all(Radius.circular(25)),
                                        color: podcastFollowed ? Colors.transparent : Colors.deepPurple,
                                        border: Border.all(color: Colors.deepPurple)
                                    ),
                                    padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
                                    child: fbp != null && fbp.followLoading ? SpinKitThreeBounce(color: podcastFollowed ? Colors.deepPurple : Colors.white, size: 16,) : InkWell(
                                      child: Text(podcastFollowed ? 'Unfollow' : 'Follow', style: TextStyle(color: podcastFollowed ? Colors.deepPurple : Colors.white)),
                                      onTap: () async {
                                        if(fbp != null && fbp.followLoading) {
                                          return;
                                        }
                                        fbp.changeFollowLoading();
                                        if(podcastFollowed) {
                                          //Unfollow podcast
                                          await DBService().unfollowPodcast(user: user, podcastUrl: podcast.url.replaceFirst('http:', 'https:'));
                                        } else {
                                          //Follow Podcast
                                          await DBService().followPodcast(user: user, podcastUrl: podcast.url.replaceFirst('http:', 'https:'));
                                        }
                                        fbp.changeFollowLoading();
                                      },
                                    ),
                                  );
                                }
                              ),
                            )
                          ],
                        ),
                        SizedBox(width: 10),
                        Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: <Widget>[
                                SizedBox(height: 10),
                                Text(podcast.title, style: TextStyle(fontSize: 18, color: Colors.black)),
                                Container(
                                  height: 100,
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.vertical,
                                    child: Html(
                                      data: podcast.description,
                                    ),
                                  ),
                                ),
                              ],
                            )
                        )
                      ],
                    )
                )
            ),
            Expanded(
                child: ListView(
                  children: podcast.episodes.map((Episode ep) {
                    if(ep.author == null)
                      ep.author = podcast.title;
                    return Card(
                        elevation: 5,
                        color: Colors.deepPurple[50],
                        margin: EdgeInsets.all(5),
                        child: Slidable(
                          actionPane: SlidableDrawerActionPane(),
                          actionExtentRatio: 0.2,
                          child: Padding(
                              padding: EdgeInsets.all(5),
                              child: ListTile(
                                title: Text(ep.title),
                                subtitle: Text('${ep.publicationDate != null ? DateFormat().format(ep.publicationDate) : ''}'),
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
                                                      color: currentMediaItem != null && currentMediaItem.id == ep.contentUrl ? Colors.red : Colors.deepPurple,
                                                    ),
                                                    child: Center(child: FaIcon(currentMediaItem != null && currentMediaItem.id == ep.contentUrl && playbackState != null && playbackState.playing ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16,)),
                                                  ),
                                                  onTap: () {
                                                    if(currentMediaItem != null && currentMediaItem.id == ep.contentUrl && playbackState != null && playbackState.playing) {
                                                      mp.pausePost();
                                                      return;
                                                    }
                                                    mp.playPost(PostPodItem.fromEpisode(ep, podcast));
                                                  }
                                              ),
                                              SizedBox(width: 5),
                                              InkWell(
                                                  child: Container(
                                                    height: 35,
                                                    width: 35,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: mediaQueue != null && mediaQueue.where((item) => item.id == ep.contentUrl).length > 0  ? Colors.grey : Colors.deepPurple,
                                                    ),
                                                    child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16,)),
                                                  ),
                                                  onTap: () {
                                                    if(mediaQueue == null || mediaQueue.where((item) => item.id == ep.contentUrl).length == 0)
                                                      mp.addPostToQueue(PostPodItem.fromEpisode(ep, podcast));
                                                  }
                                              )
                                            ],
                                          ),
                                          ep.duration == null ? Text('') : Text(ActivityManager().getDurationString(ep.duration)),
                                        ]
                                    )
                                ),
                                onTap: () {
                                  showDialog(
                                      context: context,
                                      builder: (context) {
                                        return EpisodeDialog(ep: ep, podcast: podcast);
                                      }
                                  );
                                },
                              )
                          ),
                          secondaryActions: <Widget>[
                            new SlideAction(
                              color: Colors.red[300],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  FaIcon(FontAwesomeIcons.reply, color: Colors.white),
                                  Text('Respond', style: TextStyle(color: Colors.white))
                                ],
                              ),
                              onTap: () {
                                mp.replyToEpisode(ep, podcast, context);
                              },
                            ),
                            new SlideAction(
                              color: Colors.deepPurple[300],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  FaIcon(FontAwesomeIcons.comments, color: Colors.white),
                                  Text('Discuss', style: TextStyle(color: Colors.white))
                                ],
                              ),
                              onTap: () {
                                mp.shareToConversation(context, episode: ep, podcast: podcast, user: user);
                              },
                            ),
                          ],
                        )
                    );
                  }).toList(),
                )
            )
          ]
      ),
    );
  }
}

class FollowButtonProvider extends ChangeNotifier {
  bool followLoading = false;

  changeFollowLoading() {
    followLoading = !followLoading;
    notifyListeners();
  }
}

class EpisodeDialog extends StatelessWidget {
  Episode ep;
  Podcast podcast;

  EpisodeDialog({this.ep, this.podcast});
  @override
  build(BuildContext context) {
    return SimpleDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
      title: Center(child: Text(podcast.title)),
      contentPadding: EdgeInsets.all(10),
      children: <Widget>[
        Text(ep.title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        SingleChildScrollView(
            child: Html(
              data: ep.description,
            )
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            FlatButton(
                child: Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                }
            ),
            FlatButton(
              child: Text('Go to episode', style: TextStyle(color: Colors.white)),
              color: Colors.deepPurple,
              onPressed: () async {
                if(podcast.episodes == null){
                  print('Podcast URL: ${podcast.url}/Title: ${podcast.title}');
                  podcast = await Podcast.loadFeed(url: podcast.url, timeout: 50000);
                }
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) => EpisodePage(ep, podcast),
                ));
              },
            )
          ],
        )
      ],
    );
  }
}