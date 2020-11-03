//import 'package:Perkl/services/models.dart';
import 'package:Perkl/services/ActivityManagement.dart';
import 'package:Perkl/services/local_services.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class PlayerTask extends BackgroundAudioTask {
  AudioPlayer player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);
  Duration currentPosition = Duration();

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
    print('Playing item: ${item.title}');
    await _playCurrentItem(item: item);
    AudioServiceBackground.setMediaItem(item);
    AudioServiceBackground.setState(
        controls: [MediaControl.rewind, MediaControl.pause, MediaControl.fastForward, AudioServiceBackground.queue != null && AudioServiceBackground.queue.length > 0 ? MediaControl.skipToNext : null].where((element) => element != null).toList(),
        playing: true,
        processingState: AudioProcessingState.ready,
    );
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
    print('adding item to queue ${AudioServiceBackground.queue}');
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