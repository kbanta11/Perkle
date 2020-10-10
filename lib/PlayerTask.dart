//import 'package:Perkl/services/models.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class PlayerTask extends BackgroundAudioTask {
  AudioPlayer player = new AudioPlayer(mode: PlayerMode.MEDIA_PLAYER);

  @override
  Future<void> onStart(Map<String, dynamic> params) async {
    AudioServiceBackground.setState(
      controls: [MediaControl.play],
      playing: false,
      processingState: AudioProcessingState.connecting
    );
    //await player.play(item.audioUrl);
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
  Future<void> onPause() {
    AudioServiceBackground.setState(
        controls: [MediaControl.play],
        processingState: AudioProcessingState.ready,
        playing: false);
    player.pause();
  }

  @override
  Future<void> onPlay() {
    AudioServiceBackground.setState(
      controls: [MediaControl.pause],
      playing: true,
      processingState: AudioProcessingState.ready,
    );
    player.resume();
  }

  @override
  Future<void> onPlayMediaItem(MediaItem item) async {
    print('Playing Media Item: $item');
    AudioServiceBackground.setMediaItem(item);
    await player.play(item.id);
    AudioServiceBackground.setState(controls: [MediaControl.pause], processingState: AudioProcessingState.ready, playing: true);
  }
}