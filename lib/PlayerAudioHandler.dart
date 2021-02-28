import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart' as AP;
import 'services/local_services.dart';
import 'services/db_services.dart';
import 'package:audio_session/audio_session.dart';

class PlayerAudioHandler extends BaseAudioHandler
    with QueueHandler { // mix in default implementations of queue functionality
  AP.AudioPlayer player = new AP.AudioPlayer(mode: AP.PlayerMode.MEDIA_PLAYER);
  Duration currentPosition = Duration();
  LocalService _localService = new LocalService();
  DBService _dbService = new DBService();

  PlayerAudioHandler() {
    _init();
  }

  Future<void> _init() async {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.speech());

    List<dynamic> localQueue = await _localService.getData('queue');
    if(localQueue != null && localQueue.length > 0) {
      queue.add(localQueue.map((item) => MediaItem.fromJson(item)).toList());
    }
    print('Queue set: ${queue.value}');
  }


  updateTimeListened(Duration time, String url) async {
    Map<String, dynamic> postsInProgress = await _localService.getData('posts_in_progress');
    if(time.inMilliseconds % 1000 == 0) {
      print('Updating Time Listened: ${time.inMilliseconds}');
      if(postsInProgress != null) {
        postsInProgress[url] = time.inMilliseconds;
      } else {
        postsInProgress = new Map<String, dynamic>();
        postsInProgress[url] = time.inMilliseconds;
      }
      await _localService.setData('posts_in_progress', postsInProgress);
    }
  }

  updateLocalQueue(List<MediaItem> queue) async {
    List<Map> queueList = queue.map((MediaItem item) {
      print('Item in Queue JSON: ${item.toJson()}');
      return item.toJson();
    }).toList();
    print('queue list: $queueList');
    await _localService.setData('queue', queueList);
  }

  _playCurrentItem({MediaItem item}) async {
    if(player.state == AP.AudioPlayerState.PLAYING) {
      print('player currently playing, stopping...');
      await player.stop();
    }
    player.dispose();
    player = new AP.AudioPlayer(mode: AP.PlayerMode.MEDIA_PLAYER);
    Duration startDuration = new Duration(milliseconds: 0);
    Map<String, dynamic> postsInProgress = await _localService.getData('posts_in_progress');
    if(postsInProgress != null && postsInProgress[item.id] != null) {
      int currentMs = postsInProgress[item.id];
      if(currentMs >= 15000) {
        startDuration = new Duration(milliseconds: currentMs - 10000);
      }
    }
    Map<String, dynamic> extraData = item.extras;
    if(extraData != null && extraData['isDirect'] != null && extraData['isDirect']) {
      //Mark down whether direct post has been listened
      print('marking direct post heard: ${extraData['conversationId']}/${extraData['userId']}/${extraData['postId']}');
      LocalService conversationService = LocalService(filename: 'conversations.json');
      Map<String, dynamic> heardPostMap = await conversationService.getData('conversation-heard-posts');
      if(heardPostMap == null) {
        //create heard post map and add this conversation, user and post heard list with this post
        heardPostMap = new Map<String, dynamic>();
        heardPostMap[extraData['conversationId']] = {extraData['userId']: [extraData['postId']]};
      } else if (heardPostMap.containsKey(extraData['conversationId'])) {
        //add this user or add post to this user
        Map<String, dynamic> conversationMap = heardPostMap[extraData['conversationId']];
        if(conversationMap.containsKey(extraData['userId'])) {
          //add this post id to this users post list
          List<String> postList = conversationMap[extraData['userId']].cast<String>();
          if(!postList.contains(extraData['postId'])) {
            postList.add(extraData['postId']);
            conversationMap[extraData['userId']] = postList;
          }
        } else {
          //add user and this post in post list
          conversationMap[extraData['userId']] = [extraData['postId']];
        }
        heardPostMap[extraData['conversationId']] = conversationMap;
      } else {
        heardPostMap[extraData['conversationId']] = {extraData['userId']: [extraData['postId']]};
      }
      //Save heardPostMap to local storage for sync when app is open
      await conversationService.setData('conversation-heard-posts', heardPostMap);
      await _dbService.syncConversationPostsHeard();
    }
    print('*** playing Item...: ${item.id}');
    await player.play(item.id, stayAwake: true, position: startDuration).catchError((e) {
      print('error playing item: $e');
    });
    //Set Duration once it's available
    player.onDurationChanged.listen((Duration d) {
      print('Setting duration for: ${item.title}');
      MediaItem newItem = item.copyWith(duration: d);
      mediaItem.add(newItem);
      //AudioServiceBackground.setMediaItem(newItem);
    });
    //Update time listened to
    player.onAudioPositionChanged.listen((Duration d) async {
      if(currentPosition.inMilliseconds == 0) {
        currentPosition = d;
      }
      print('old Position: ${currentPosition.inMilliseconds} (Seconds: ${currentPosition.inSeconds})\nNew position: ${d.inMilliseconds} (Seconds: ${d.inSeconds})');
      if(d.inSeconds > currentPosition.inSeconds) {
        print('audio position changed ###: ${d.inMilliseconds}');
        updateTimeListened(d, item.id);
        playbackState.add(playbackState.value.copyWith(
          controls: [MediaControl.rewind,
            MediaControl.pause,
            MediaControl.fastForward,
            queue != null && !(await queue.isEmpty) ? MediaControl.skipToNext : null].where((element) => element != null).toList(),
          playing: true,
          updatePosition: d,
          processingState: AudioProcessingState.ready
        ));
        /*
        AudioServiceBackground.setState(
          controls: [MediaControl.rewind, MediaControl.pause, MediaControl.fastForward, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList(),
          playing: true,
          processingState: AudioProcessingState.ready,
          position: d,
        ).then((_) {
          print('Audio Position Changed: ${AudioServiceBackground.state.playing}');
        });
         */
      }
      currentPosition = d;
    });
    //Stop on completion and play next
    player.onPlayerCompletion.listen((_) async {
      //print('Stopping player after completion');
      player.stop();
      if(queue != null && queue.value != null && queue.value.length > 0) {
        //Play next item in queue
        print('skipping to next: ${queue.value}');
        this.skipToNext();
      } else {
        //Stop player and update status
        print('setting state after player completion');
        playbackState.add(playbackState.value.copyWith(
          controls: [MediaControl.stop],
          processingState: AudioProcessingState.completed,
          playing: false
        ));
        /*
        AudioServiceBackground.setState(
            controls: [MediaControl.stop,],
            processingState: AudioProcessingState.completed,
            playing: false);
         */
      }
    });
    print('playing item now under way');
  }

  /*
  @override
  Future<void> start(Map<String, dynamic> params) async {
    print('Audio Service Starting up...');
    AudioServiceBackground.setState(
        controls: [MediaControl.play, MediaControl.stop],
        playing: false,
        processingState: AudioProcessingState.connecting
    );
    MediaItem item = MediaItem.fromJson(params['mediaItem']);
    if(item != null) {
      print('Playing item: ${item.title}');
      await _playCurrentItem(item: item);
      AudioServiceBackground.setMediaItem(item);
      AudioServiceBackground.setState(
        controls: [
          MediaControl.rewind,
          MediaControl.pause,
          MediaControl.fastForward,
          AudioServiceBackground.queue != null &&
              AudioServiceBackground.queue.length > 0
              ? MediaControl.skipToNext
              : null
        ].where((element) => element != null).toList(),
        playing: true,
        processingState: AudioProcessingState.ready,
      );
    } else {
      AudioServiceBackground.setState(controls: [MediaControl.stop], processingState: AudioProcessingState.none, playing: false);
    }
    return;
  }
  */

  @override
  Future<void> fastForward([Duration interval]) async {
    Duration duration = Duration(milliseconds: await player.getDuration());
    Duration position = Duration(
        milliseconds: await player.getCurrentPosition());
    //print('Duration ms: ${duration.inSeconds}/Position ms: ${position.inSeconds}');
    if (position.inSeconds + interval.inSeconds >= duration.inSeconds) {
      player.seek(Duration(seconds: duration.inSeconds - 15));
    } else {
      player.seek(Duration(seconds: position.inSeconds + interval.inSeconds));
    }
    return;
  }

  @override
  Future<void> rewind([Duration interval]) async {
    //Duration duration = Duration(milliseconds: await player.getDuration());
    Duration position = Duration(milliseconds: await player.getCurrentPosition());
    //print('Duration ms: ${duration.inSeconds}/Position ms: ${position.inSeconds}');
    if(position.inSeconds - interval.inSeconds <= 0)
      player.seek(Duration(seconds: 0));
    else
      player.seek(Duration(seconds: position.inSeconds - interval.inSeconds));
    return;
  }

  @override
  Future<void> stop() async {
    await player.stop();
    await super.stop();
  }

  @override
  Future<void> pause() async {
    print('pausing file');
    await player.pause();
    print('file paused');
    playbackState.add(playbackState.value.copyWith(
      controls: [MediaControl.play,
        MediaControl.stop,
        queue != null && !(await queue.isEmpty) ? MediaControl.skipToNext : null
      ].where((element) => element != null).toList(),
      processingState: AudioProcessingState.ready,
      playing: false,
      updatePosition: currentPosition,
    ));
    /*
    await AudioServiceBackground.setState(
      controls: [MediaControl.play, MediaControl.stop, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList(),
      processingState: AudioProcessingState.ready,
      playing: false,
      position: currentPosition,
    ).then((_) {
      print('State Updated after Pause: ${AudioServiceBackground.state.playing}');
    }).catchError((e) {
      print('error setting state: $e');
    });
     */
    return;
  }

  @override
  Future<void> play() async {
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        MediaControl.pause,
        MediaControl.fastForward,
        queue != null && !(await queue.isEmpty) ? MediaControl.skipToNext : null
      ].where((element) => element != null).toList(),
      playing: true,
      processingState: AudioProcessingState.ready
    ));
    /*
    AudioServiceBackground.setState(
      controls: [MediaControl.rewind, MediaControl.pause, MediaControl.fastForward, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList(),
      playing: true,
      processingState: AudioProcessingState.ready,
    );
     */
    player.resume();
    return null;
  }

  @override
  Future<void> playMediaItem(MediaItem item) async {
    print('Playing Media Item: $item');
    //AudioServiceBackground.setMediaItem(item);
    mediaItem.add(item);
    await _playCurrentItem(item: item);
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.rewind,
        MediaControl.pause,
        MediaControl.fastForward,
        queue != null && !(await queue.isEmpty) ? MediaControl.skipToNext : null
      ].where((element) => element != null).toList(),
      processingState: AudioProcessingState.ready,
      playing: true
    ));
    /*
    AudioServiceBackground.setState(controls: [MediaControl.rewind, MediaControl.pause, MediaControl.fastForward, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList()
        , processingState: AudioProcessingState.ready
        , playing: true);
     */
  }

  @override
  Future<void> addQueueItem(MediaItem item) async {
    List<MediaItem> tempQueue = queue.value;
    if(tempQueue == null) {
      tempQueue = new List<MediaItem>();
      tempQueue.add(item);
    } else {
      tempQueue.add(item);
    }
    queue.add(tempQueue);
    //AudioServiceBackground.setQueue(tempQueue);
    await updateLocalQueue(tempQueue);
    return null;
  }

  @override
  Future<void> insertQueueItem(int position, MediaItem item) async {
    List<MediaItem> tempQueue = queue.value;
    if(tempQueue == null) {
      tempQueue = new List<MediaItem>();
      tempQueue.add(item);
    } else {
      tempQueue.insert(0, item);
    }
    queue.add(tempQueue);
    //AudioServiceBackground.setQueue(tempQueue);
    await updateLocalQueue(tempQueue);
    return null;
  }

  @override
  Future<void> skipToNext() async {
    List<MediaItem> tempQueue = queue.value;
    if(tempQueue != null && tempQueue.length > 0) {
      MediaItem mediaItem = tempQueue.first;
      String mediaId = mediaItem.id;
      print('Media Id to skip to: $mediaId');
      queue.add(tempQueue);
      //AudioServiceBackground.setQueue(tempQueue);
      await updateLocalQueue(tempQueue);
      this.skipToQueueItem(mediaId);
    }
    return null;
  }

  @override
  Future<void> skipToQueueItem(String mediaId) async {
    List<MediaItem> tempQueue = queue.value;
    print('Queue: $tempQueue');
    MediaItem newItem = tempQueue.where((item) => item.id == mediaId).first;
    tempQueue.remove(newItem);
    queue.add(tempQueue);
    //AudioServiceBackground.setQueue(tempQueue);
    await updateLocalQueue(tempQueue);
    print('Skipping to new item: $newItem');
    if(newItem != null) {
      await playMediaItem(newItem);
    }
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    print('removing item: $mediaItem');
    List<MediaItem> tempQueue = queue?.value;
    if(tempQueue != null) {
      tempQueue.removeWhere((item) => mediaItem.id == item.id);
      queue.add(tempQueue);
      //AudioServiceBackground.setQueue(AudioServiceBackground.queue);
      await updateLocalQueue(tempQueue);
      //print(AudioServiceBackground.queue);
    }
    return null;
  }

  @override
  Future<void> updateQueue(List<MediaItem> newQueue) {
    queue.add(newQueue);
    return null;
  }
}