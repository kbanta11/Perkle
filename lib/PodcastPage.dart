import 'package:Perkl/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:podcast_search/podcast_search.dart';
import 'package:flutter_html/flutter_html.dart';

import 'MainPageTemplate.dart';
import 'EpisodePage.dart';
import 'services/models.dart';

class PodcastPage extends StatelessWidget {
  Podcast podcast;

  PodcastPage(this.podcast);

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
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
                                              color: mp.currentPostPodId == (ep.guid == null ? ep.link : ep.guid) ? Colors.red : Colors.deepPurple,
                                            ),
                                            child: Center(child: FaIcon(mp.currentPostPodId == (ep.guid == null ? ep.link : ep.guid) && mp.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16,)),
                                          ),
                                          onTap: () {
                                            if(mp.currentPostPodId == (ep.guid == null ? ep.link : ep.guid) && mp.isPlaying) {
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
                                              color: mp.queue.where((item) => item.id == (ep.guid == null ? ep.link : ep.guid)).length > 0  ? Colors.grey : Colors.deepPurple,
                                            ),
                                            child: Center(child: FaIcon(FontAwesomeIcons.plus, color: Colors.white, size: 16,)),
                                          ),
                                          onTap: () {
                                            if(mp.queue.where((item) => item.id == (ep.guid == null ? ep.link : ep.guid)).length == 0)
                                              mp.addPostToQueue(PostPodItem.fromEpisode(ep, podcast));
                                          }
                                      )
                                    ],
                                  ),
                                  ep.duration == null ? Text('') : Text(Duration(seconds: ep.duration).inSeconds.toString()),
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

class EpisodeDialog extends StatelessWidget {
  Episode ep;
  Podcast podcast;

  EpisodeDialog({this.ep, this.podcast});
  @override
  build(BuildContext context) {
    return SimpleDialog(
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
              onPressed: () {
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