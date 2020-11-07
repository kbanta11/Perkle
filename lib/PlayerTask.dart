//import 'package:Perkl/services/models.dart';
import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/local_services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class PlayerTask extends BackgroundAudioTask {
  AudioPlayer player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
  Duration currentPosition = Duration();
  LocalService _localService = new LocalService();

  _playCurrentItem({MediaItem item}) async {
    if(player.state == AudioPlayerState.PLAYING) {
      print('player currently playing, stopping...');
      await player.stop();
    }
    player.dispose();
    player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
    Duration startDuration = new Duration(milliseconds: 0);
    Map<String, dynamic> postsInProgress = await LocalService().getData('posts_in_progress');
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
      Map<String, dynamic> heardPostMap = await _localService.getData('conversation-heard-posts');
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
      await _localService.setData('conversation-heard-posts', heardPostMap);
    }
    await player.play(item.id, stayAwake: true, position: startDuration);
    //Set Duration once it's available
    player.onDurationChanged.listen((Duration d) {
      print('Setting duration for: ${item.title}');
      MediaItem newItem = item.copyWith(duration: d);
      AudioServiceBackground.setMediaItem(newItem);
    });
    //Update time listened to
    player.onAudioPositionChanged.listen((Duration d) {
      currentPosition = d;
      ActivityManager().updateTimeListened(d, item.id);
      AudioServiceBackground.setState(
        controls: [MediaControl.rewind, MediaControl.pause, MediaControl.fastForward, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList(),
        playing: true,
        processingState: AudioProcessingState.ready,
        position: d,
      );
    });
    //Stop on completion and play next
    player.onPlayerCompletion.listen((_) {
      player.stop();
      if(AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0) {
        //Play next item in queue
        this.onSkipToNext();
      } else {
        //Stop player and update status
        AudioServiceBackground.setState(controls: [MediaControl.stop,], processingState: AudioProcessingState.completed, playing: false);
      }
    });
  }

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    print('Audio Service Starting up...');
    AudioServiceBackground.setState(
      controls: [MediaControl.pause, MediaControl.stop],
      playing: true,
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

  @override
  Future<void> onFastForward() async {
    Duration duration = Duration(milliseconds: await player.getDuration());
    Duration position = Duration(
        milliseconds: await player.getCurrentPosition());
    //print('Duration ms: ${duration.inSeconds}/Position ms: ${position.inSeconds}');
    if (position.inSeconds + 30 >= duration.inSeconds) {
      player.seek(Duration(seconds: duration.inSeconds - 15));
    } else {
      player.seek(Duration(seconds: position.inSeconds + 30));
    }
  }

  @override
  Future<void> onRewind() async {
    //Duration duration = Duration(milliseconds: await player.getDuration());
    Duration position = Duration(milliseconds: await player.getCurrentPosition());
    //print('Duration ms: ${duration.inSeconds}/Position ms: ${position.inSeconds}');
    if(position.inSeconds - 30 <= 0)
      player.seek(Duration(seconds: 0));
    else
      player.seek(Duration(seconds: position.inSeconds - 30));
  }

  @override
  Future<void> onStop() async {
    player.stop();
    await AudioServiceBackground.setState(
        controls: [],
        processingState: AudioProcessingState.stopped,
        playing: false);
    await super.onStop();
  }

  @override
  Future<void> onPause() async {
    print('pausing file');
    await player.pause();
    await AudioServiceBackground.setState(
        controls: [MediaControl.play, MediaControl.stop, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList(),
        processingState: AudioProcessingState.stopped,
        playing: false,
        position: currentPosition,
    );
  }

  @override
  Future<void> onPlay() {
    AudioServiceBackground.setState(
      controls: [MediaControl.rewind, MediaControl.pause, MediaControl.fastForward, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList(),
      playing: true,
      processingState: AudioProcessingState.ready,
    );
    player.resume();
  }

  @override
  Future<void> onPlayMediaItem(MediaItem item) async {
    print('Playing Media Item: $item');
    AudioServiceBackground.setMediaItem(item);
    await _playCurrentItem(item: item);
    AudioServiceBackground.setState(controls: [MediaControl.rewind, MediaControl.pause, MediaControl.fastForward, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList(), processingState: AudioProcessingState.ready, playing: true);
  }

  @override
  Future<void> onAddQueueItem(MediaItem item) {
    List<MediaItem> tempQueue = AudioServiceBackground.queue;
    if(tempQueue == null) {
      tempQueue = new List<MediaItem>();
      tempQueue.add(item);
    } else {
      tempQueue.add(item);
    }
    AudioServiceBackground.setQueue(tempQueue);
  }

  @override
  Future<void> onAddQueueItemAt(MediaItem item, int position) {
    List<MediaItem> tempQueue = AudioServiceBackground.queue;
    if(tempQueue == null) {
      tempQueue = new List<MediaItem>();
      tempQueue.add(item);
    } else {
      tempQueue.insert(0, item);
    }
    AudioServiceBackground.setQueue(tempQueue);
  }

  @override
  Future<void> onSkipToNext() {
    List<MediaItem> tempQueue = AudioServiceBackground.queue;
    if(tempQueue != null && tempQueue.length > 0) {
      MediaItem mediaItem = tempQueue.first;
      String mediaId = mediaItem.id;
      print('Media Id to skip to: $mediaId');
      AudioServiceBackground.setQueue(tempQueue);
      this.onSkipToQueueItem(mediaId);
    }
  }

  @override
  Future<void> onSkipToQueueItem(String mediaId) async {
    List<MediaItem> tempQueue = AudioServiceBackground.queue;
    print('Queue: $tempQueue');
    MediaItem newItem = tempQueue.where((item) => item.id == mediaId).first;
    tempQueue.remove(newItem);
    AudioServiceBackground.setQueue(tempQueue);
    print('Skipping to new item: $newItem');
    if(newItem != null) {
      await onPlayMediaItem(newItem);
    }
  }

  @override
  Future<void> onRemoveQueueItem(MediaItem mediaItem) {
    print('removing item: $mediaItem');
    if(AudioServiceBackground.queue != null) {
      AudioServiceBackground.queue.removeWhere((item) => mediaItem.id == item.id);
      AudioServiceBackground.setQueue(AudioServiceBackground.queue);
      print(AudioServiceBackground.queue);
    }
  }
}