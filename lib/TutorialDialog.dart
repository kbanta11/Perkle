import 'package:flutter/material.dart';
//import 'package:video_player/video_player.dart';
import 'services/local_services.dart';
import 'HomePage.dart';

List tutorialImages = [
  'recording_tutorial.jpeg',
  'discover_tutorial.jpeg',
  'messages_tutorial.jpeg',
  'play_queue_tutorial.jpeg',
  'slide_tutorial.jpeg',
  'queue_clip_tutorial.jpeg',
  'menu_tutorial',
];

class TutorialPage extends StatefulWidget {

  TutorialPage({Key key,}) : super(key: key);

  @override
  _TutorialPageState createState() => _TutorialPageState();
}

class _TutorialPageState extends State<TutorialPage> {
  int index = 0;
  LocalService _localService = LocalService();

  @override
  initState() {
    super.initState();
  }

  @override
  dispose() {
    super.dispose();
  }

  @override
  build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black12,
      body: Stack(
        children: <Widget>[
          Center(
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                child: FittedBox(
                  child: Image.asset('assets/images/tutorial/${tutorialImages[index]}'),
                  fit: BoxFit.fill,
                )
              ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  TextButton(
                    child: Text('SKIP', style: TextStyle(color: Colors.white, fontSize: 24)),
                    onPressed: () async {
                      //Mark all tutorials in the index as watched
                      /*
                      List<dynamic>tutorialsCompleted = await _localService.getData('tutorial_index_complete');
                      if(tutorialsCompleted == null) {
                        tutorialsCompleted = <Map>[];
                      }
                      tutorialsCompleted.addAll(widget.currentTutorials);
                      await _localService.setData('tutorial_index_complete', tutorialsCompleted);
                       */
                      await _localService.setData('tutorial_version', 1);
                      //Go to homepage
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePageMobile()));
                    },
                  ),
                  TextButton(
                      child: Text(index == tutorialImages.length - 1 ? 'CLOSE' : 'NEXT', style: TextStyle(color: Colors.white, fontSize: 24)),
                      onPressed: () async {
                        //Mark current item as watched and move to next item
                        /*
                        List<dynamic> tutorialsCompleted = await _localService.getData('tutorial_index_complete');
                        if(tutorialsCompleted == null) {
                          tutorialsCompleted = <Map>[];
                        }
                        tutorialsCompleted.add(widget.currentTutorials[index]);
                        await _localService.setData('tutorial_index_complete', tutorialsCompleted);
                        print('Setting tutorial Complete: ${_localService.data}');
                         */
                        //Close if no more items
                        if(index == tutorialImages.length - 1) {
                          await _localService.setData('tutorial_version', 1);
                          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomePageMobile()));
                          //Navigator.of(context).pop();
                          return;
                        }

                        setState(() {
                          index = index + 1;
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