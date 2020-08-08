import 'package:Perkl/MainPageTemplate.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'main.dart';
import 'services/models.dart';

class QueuePage extends StatelessWidget {

  @override
  build(BuildContext context) {
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return MainPageTemplate(
      bottomNavIndex: 1,
      noBottomNavSelected: true,
      body: mp.queue.length == 0 ? Center(child: Text('Your queue is empty...')) : ListView(
        children: mp.queue.map((PostPodItem item) {
          return ListTile(
            title: Text(item.displayText, style: TextStyle(fontSize: 16)),
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
          );
        }).toList(),
      ),
    );
  }
}