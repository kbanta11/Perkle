import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'services/local_services.dart';

class TutorialDialog extends StatefulWidget {
  List<Map<String, dynamic>> currentTutorials;

  TutorialDialog({Key key, this.currentTutorials}) : super(key: key);

  @override
  _TutorialDialogState createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<TutorialDialog> {
  VideoPlayerController _vidController;
  int index = 0;
  LocalService _localService = LocalService();

  @override
  initState() {
    super.initState();
    _vidController = VideoPlayerController.network(widget.currentTutorials.first['file'])..initialize().then((_) {
      setState(() {});
    });
  }

  @override
  dispose() {
    super.dispose();
    _vidController?.dispose();
  }

  @override
  build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Stack(
        children: <Widget>[
          Center(
              child: _vidController != null && _vidController.value.initialized
                  ? AspectRatio(
                aspectRatio: _vidController.value.aspectRatio,
                child: GestureDetector(
                    child: VideoPlayer(_vidController),
                  onTap: () async {
                      if(_vidController.value.isPlaying) {
                        await _vidController.pause();
                        setState(() {});
                      }
                  },
                ),
              )
                  : Container()
          ),
          _vidController != null && !(_vidController.value.isPlaying) ? Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(5),
                  color: Colors.deepPurple,
                  child: Text(widget.currentTutorials[index]['text'], style: TextStyle(fontSize: 36, color: Colors.white), textAlign: TextAlign.center, ),
                ),
                IconButton(
                  icon: Icon(Icons.play_arrow_rounded, size: 88, color: Colors.deepPurple,),
                  iconSize: 88,
                  onPressed: () async {
                    await _vidController.play();
                    _vidController.addListener(() {
                      if(_vidController.value.position == _vidController.value.duration) {
                        setState(() {});
                      }
                    });
                    setState(() {});
                  },
                )
              ],
            ),
          ) : Container(),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  FlatButton(
                    child: Text('SKIP', style: TextStyle(color: Colors.white, fontSize: 24)),
                    onPressed: () async {
                      //Mark all tutorials in the index as watched
                      List<dynamic>tutorialsCompleted = await _localService.getData('tutorial_index_complete');
                      if(tutorialsCompleted == null) {
                        tutorialsCompleted = List<Map>();
                      }
                      tutorialsCompleted.addAll(widget.currentTutorials);
                      await _localService.setData('tutorial_index_complete', tutorialsCompleted);
                      //Close dialog
                      Navigator.of(context).pop();
                    },
                  ),
                  FlatButton(
                      child: Text(index == widget.currentTutorials.length - 1 ? 'CLOSE' : 'NEXT', style: TextStyle(color: Colors.white, fontSize: 24)),
                      onPressed: () async {
                        if(_vidController.value.isPlaying) {
                          _vidController.pause();
                        }
                        //Mark current item as watched and move to next item
                        List<dynamic> tutorialsCompleted = await _localService.getData('tutorial_index_complete');
                        if(tutorialsCompleted == null) {
                          tutorialsCompleted = List<Map>();
                        }
                        tutorialsCompleted.add(widget.currentTutorials[index]);
                        await _localService.setData('tutorial_index_complete', tutorialsCompleted);
                        print('Setting tutorial Complete: ${_localService.data}');

                        //Close if no more items
                        if(index == widget.currentTutorials.length - 1) {
                          Navigator.of(context).pop();
                          return;
                        }

                        setState(() {
                          index = index + 1;
                          _vidController = VideoPlayerController.network(widget.currentTutorials[index]['file'])..initialize().then((_) {
                            setState(() {});
                          });
                        });

                      }
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}