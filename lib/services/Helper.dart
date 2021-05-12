import 'package:audio_service/audio_service.dart';

class Helper {
  Duration parseItunesDuration(String? s) {
    if(s == null) {
      return Duration.zero;
    }
    int hours = 0;
    int minutes = 0;
    int micros;
    List<String> parts = s.split(':');
    if (parts.length > 2) {
      hours = int.parse(parts[parts.length - 3]);
    }
    if (parts.length > 1) {
      minutes = int.parse(parts[parts.length - 2]);
    }
    micros = (double.parse(parts[parts.length - 1]) * 1000000).round();
    return Duration(hours: hours, minutes: minutes, microseconds: micros);
  }

  MediaItem getMediaItemFromJson(dynamic item) {
    return MediaItem(
      id: item['id'],
      album: item['album'],
      title: item['title'],
      artist: item['artist'],
      genre: item['genre'],
      duration: Duration(milliseconds: item['duration']),
      artUri: item['artUri'],
      playable: item['playable'],
      displayTitle: item['displayTitle'],
      displaySubtitle: item['displaySubtitle'],
      displayDescription: item['displayDescription'],
      rating: item['rating'],
      extras: item['extras'],
    );
  }

  Map<String, dynamic> mediaItemToJson(MediaItem? item) {
    return {
      'id': item?.id,
      'album': item?.album,
      'title': item?.title,
      'artist': item?.artist,
      'genre': item?.genre,
      'duration': item?.duration?.inMilliseconds,
      'artUri': item?.artUri,
      'playable': item?.playable,
      'displayTitle': item?.displayTitle,
      'displaySubtitle': item?.displaySubtitle,
      'displayDescription': item?.displayDescription,
      'rating': item?.rating,
      'extras': item?.extras,
    };
  }
}