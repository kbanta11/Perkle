import 'package:Perkl/ConversationPage.dart';
import 'package:Perkl/MainPageTemplate.dart';
import 'package:Perkl/PodcastPage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'main.dart';
import 'services/models.dart';
import 'StreamTagPage.dart';

class QueuePage extends StatelessWidget {

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    List<Widget> queueWidgets = new List<Widget>();

    tapItemTile(PostPodItem item) {
      if(item.type == PostType.PODCAST_EPISODE) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return EpisodeDialog(ep: item.episode, podcast: item.podcast,);
            }
        );
      }
      if(item.type == PostType.EPISODE_REPLY){
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return EpisodeDialog(ep: item.episode, podcast: item.podcast);
            }
        );
      }
      if(item.type == PostType.POST) {
        showDialog(
            context: context,
            builder: (BuildContext context) {
              return SimpleDialog(
                title: Center(child: Text(item.post.postTitle ?? DateFormat("MMMM dd, yyyy @ hh:mm").format(item.post.datePosted).toString())),
                contentPadding: EdgeInsets.all(10),
                children: <Widget>[
                  Text('Posted By:\n@${item.post.username}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),),
                  item.post.postValue != null ? Text('${item.post.postValue ?? ''}') : Container(),
                  SizedBox(height: 10),
                  Text('Date Posted:\n${DateFormat("MMMM dd, yyyy @ hh:mm").format(item.post.datePosted).toString()}', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),),
                  SizedBox(height: 10),
                  item.post.streamList != null && item.post.streamList.length > 0 ? Wrap(
                    spacing: 8,
                    children: item.post.streamList.map((tag) => InkWell(
                        child: Text('#$tag', style: TextStyle(color: Colors.lightBlue)),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(
                              builder: (context) => StreamTagPageMobile(tag: tag,)
                          ));
                        }
                    )).toList(),
                  ) : Container(),
                  Row(
                    children: <Widget>[
                      FlatButton(
                        child: Text('Cancel'),
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                      )
                    ],
                  )
                ],
              );
            }
        );
      }
      if(item.type == PostType.DIRECT_POST) {
        Navigator.push(context, MaterialPageRoute(
            builder: (context) => ConversationPageMobile(conversationId: item.directPost.conversationId,)
        ));
      }
    }

    if(mp.currentPostPodItem != null)
      queueWidgets.add(Card(
        color: Colors.greenAccent[100],
        margin: EdgeInsets.all(5),
        child: Padding(
          padding: EdgeInsets.all(5),
          child: ListTile(
            title: mp.currentPostPodItem.titleText(),
            subtitle: mp.currentPostPodItem.subtitleText(),
            onTap: () {
              tapItemTile(mp.currentPostPodItem);
            },
          ),
        )
      ));
    queueWidgets.addAll(mp.queue.map((PostPodItem item) {
      return Card(
          color: Colors.deepPurple[50],
          margin: EdgeInsets.all(5),
          elevation: 5,
          child: Padding(
              padding: EdgeInsets.all(5),
              child: ListTile(
                title: item.titleText(),
                subtitle: item.subtitleText(),
                trailing: Container(
                  width: 85,
                  child: Column(
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
                                  color: mp.currentPostPodId == item.id ? Colors.red : Colors.deepPurple
                              ),
                              child: Center(child: FaIcon(mp.currentPostPodId == item.id && mp.isPlaying != null && mp.isPlaying ? FontAwesomeIcons.pause : FontAwesomeIcons.play, color: Colors.white, size: 16)),
                            ),
                            onTap: () {
                              mp.isPlaying != null && mp.isPlaying && mp.currentPostPodId == item.id ? mp.pausePost() : mp.playPost(item);
                            },
                          ),
                          SizedBox(width: 5,),
                          InkWell(
                            child: Container(
                              height: 35,
                              width: 35,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.redAccent,
                              ),
                              child: Center(child: FaIcon(FontAwesomeIcons.minus, color: Colors.white, size: 16)),
                            ),
                            onTap: () {
                              if(mp.queue.where((p) => p.id == item.id).length > 0)
                                mp.removeFromQueue(item);
                            },
                          )
                        ],
                      )
                    ],
                  ),
                ),
                onTap: () {
                  tapItemTile(item);
                },
              )
          )
      );
    }).toList());
    return MainPageTemplate(
      bottomNavIndex: 1,
      noBottomNavSelected: true,
      body: queueWidgets.length == 0 ? Center(child: Text('Your queue is empty...')) : ListView(
        children: queueWidgets,
      ),
    );
  }
}