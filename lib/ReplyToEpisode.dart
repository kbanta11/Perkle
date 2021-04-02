import 'package:Perkl/services/ActivityManagement.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:audio_service/audio_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:podcast_search/podcast_search.dart';
//import 'package:audioplayers/audioplayers.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock/wakelock.dart';
import 'package:sounds/sounds.dart';
import 'services/models.dart';
import 'services/db_services.dart';
import 'services/UserManagement.dart';
import 'main.dart';
import 'PageComponents.dart';

class ReplyToEpisodeDialog extends StatelessWidget {
  Episode _episode;
  Podcast _podcast;

  ReplyToEpisodeDialog(this._episode, this._podcast);

  @override
  build(BuildContext context) {
    User firebaseUser = Provider.of<User>(context);
    PlaybackState playbackState = Provider.of<PlaybackState>(context);
    MainAppProvider mp = Provider.of<MainAppProvider>(context);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ReplyToEpisodeProvider>(create: (_) => ReplyToEpisodeProvider(),),
        StreamProvider<PerklUser>(create: (_) => UserManagement().streamCurrentUser(firebaseUser))
      ],
      child: Consumer<ReplyToEpisodeProvider>(
        builder: (context, rep, _) {
          PerklUser user = Provider.of<PerklUser>(context);
          return rep.isUploading ? Center(child: CircularProgressIndicator()) : SimpleDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
            title: Center(child: Text(_episode.title, textAlign: TextAlign.center)),
            contentPadding: EdgeInsets.all(10),
            children: <Widget>[
              Center(child: Text(_podcast.title, style: TextStyle(fontSize: 16), textAlign: TextAlign.center,)),
              SizedBox(height: 20),
              Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        rep._isRecording ? RecordingPulse(maxSize: 56.0) : Container(),
                        FloatingActionButton(
                            backgroundColor: rep._isRecording ? Colors.transparent : Colors.deepPurple,
                            child: Icon(Icons.mic, color: rep._isRecording ? Colors.red : Colors.white),
                            elevation: rep._isRecording ? 0.0 : 5.0,
                            shape: CircleBorder(side: BorderSide(color: rep._isRecording ? Colors.red : Colors.deepPurple)),
                            heroTag: null,
                            onPressed: () async {
                              if(playbackState != null && playbackState.playing) {
                                mp.pausePost();
                              }
                              if(rep._isRecording) {
                                rep.stopRecording();
                                //await addPostDialog(context, date, recordingLocation, secondsLength);
                              } else {
                                rep.startRecording();
                              }
                            }
                        )
                      ]
                    ),
                    SizedBox(width: 50),
                    FloatingActionButton(
                      heroTag: 2,
                      backgroundColor: rep.filePath == null || rep._isRecording ? Colors.grey : rep._isPlaybackRecording ? Colors.red : Colors.deepPurple,
                      child: Icon(rep._isPlaybackRecording ? Icons.pause : Icons.play_arrow, color: Colors.white),
                      onPressed: () {
                        if(rep.filePath == null || rep._isRecording)
                          return;
                        if(rep._isPlaybackRecording) {
                          rep.pausePlayback();
                        } else {
                          rep.playbackRecording();
                        }
                      },
                    )
                  ]
              ),
              SizedBox(height: 5),
              Center(
                child: rep.recordingTime != null ? Text(rep.getDurationString(rep.recordingTime), )  : Text('Record Your Reply!', style: TextStyle(color: Colors.red)),
              ),
              SizedBox(height: 15),
              Center(child: Text('Reply Title', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
              Container(
                  width: MediaQuery.of(context).size.width - 40,
                  child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Title (Optional)',
                      ),
                      onChanged: (value) {
                        rep._messageTitle = value;
                      }
                  )
              ),
              SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  TextButton(
                    child: Text('Cancel'),
                    onPressed: () {
                      rep.dispose();
                      Navigator.of(context).pop();
                    },
                  ),
                  TextButton(
                    child: Text('Reply', style: TextStyle(color: rep.filePath != null ? Colors.white : Colors.grey)),
                    style: TextButton.styleFrom(backgroundColor: rep.filePath != null ? Colors.deepPurple : Colors.transparent),
                    onPressed: () async {
                      await rep.sendReply(episode: _episode, podcast: _podcast, user: user);
                      rep.dispose();
                      Navigator.of(context).pop();
                    },
                  )
                ],
              )
            ],
          );
        },
      ),
    );
  }
}

class ReplyToEpisodeProvider extends ChangeNotifier {
  bool _isRecording = false;
  bool _isPlaybackRecording = false;
  DateTime replyDate;
  ActivityManager activityManager = new ActivityManager();
  SoundRecorder recorder = new SoundRecorder(playInBackground: true);
  AudioPlayer audioPlayer = new AudioPlayer();
  String filePath;
  //Duration replyLength;
  Duration recordingTime;
  String _messageTitle;
  bool isUploading = false;

  @override
  dispose() {
    super.dispose();
    audioPlayer.dispose();
  }

  String setMessageTitle(String val) {
    _messageTitle = val;
    notifyListeners();
  }
  
  startRecording() async {
    Wakelock.enable();
    recorder.initialize();
    //final appDataDir = await getApplicationDocumentsDirectory();
    //String localPath = appDataDir.path;
    //String extension = '.aac';
    //String filePath = '$localPath/tempAudio$extension';
    //print('File Path: $filePath');

    //Check if have permissions for microphone or ask
    if(!(await Permission.microphone.isGranted)) {
      print('asking for mic permissions');
      await Permission.microphone.request();
    }

    _isRecording = true;
    String tempFilePath = Track.tempFile(CustomMediaFormat());
    print('TempFilePath: $tempFilePath');
    await recorder.record(Track.fromFile(tempFilePath, mediaFormat: CustomMediaFormat()));
    recorder.dispositionStream().listen((disposition) {
      setRecordingTime(disposition.duration);
    });
    filePath = Platform.isIOS ? tempFilePath.replaceAll('file://', '') : tempFilePath;
    replyDate = DateTime.now();
    notifyListeners();
  }
  
  stopRecording() {
    Wakelock.disable();
    _isRecording = false;
    recorder.stop();
    //replyLength = recorder.duration;
    recorder.release();
    recorder = new SoundRecorder();
    notifyListeners();
  }

  setRecordingTime(Duration disposition) {
    recordingTime = disposition;
    notifyListeners();
  }

  playbackRecording() async {
    await audioPlayer.setFilePath(filePath);
    audioPlayer.play();
    audioPlayer.processingStateStream.listen((ProcessingState processState) {
      if(processState == ProcessingState.completed) {
        _isPlaybackRecording = false;
        notifyListeners();
      }
    });
    _isPlaybackRecording = true;
    notifyListeners();
  }

  pausePlayback() {
    audioPlayer.pause();
    _isPlaybackRecording = false;
    notifyListeners();
  }

  sendReply({Episode episode, Podcast podcast, PerklUser user}) async {
    isUploading = true;
    notifyListeners();
    print('episode: $episode/guid:');
    await DBService().postEpisodeReply(episode: episode, podcast: podcast, filePath: filePath, replyLength: recordingTime, replyDate: replyDate, replyTitle: _messageTitle, user: user);
    isUploading = false;
    notifyListeners();
    return;
  }

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
}