import 'dart:developer';

/// 检查是否为Spotify URL
/// 检查URL是否为Spotify的歌曲、播放列表或专辑链接
/// @param url 要检查的URL
/// @return 返回包含检查结果和类型的Map
Map<String, dynamic> isSpotifyUrl(String url) {
  Uri uri;
  try {
    uri = Uri.parse(url);
  } on FormatException catch (_) {
    return {'isSpotify': false, 'type': ''};
  }
  if (uri.host != 'open.spotify.com') {
    return {'isSpotify': false, 'type': ''};
  }
  final pathParts = uri.pathSegments;
  if (pathParts.length < 2) {
    return {'isSpotify': false, 'type': ''};
  }
  final type = pathParts[0];
  return {
    'isSpotify': true,
    'type': type == 'track'
        ? 'track'
        : (type == 'playlist')
            ? 'playlist'
            : 'album'
  };
}

/// 检查是否为YouTube链接
/// @param link 要检查的链接
/// @return 如果是YouTube链接返回true
bool isYoutubeLink(String link) {
  if (link.contains("youtube.com") || link.contains("youtu.be")) {
    return true;
  } else {
    return false;
  }
}

/// 提取YouTube视频ID
/// 从YouTube URL中提取视频ID
/// @param url YouTube视频URL
/// @return 返回视频ID，如果提取失败返回null
String? extractVideoId(String url) {
  try {
    Uri uri = Uri.parse(url);
    if (uri.host == 'youtube.com') {
      return uri.queryParameters['v']; // Retrieve video ID from query parameter
    }
    if (uri.host == 'youtu.be') {
      return uri.pathSegments.first; // Retrieve video ID from path
    }
    if (uri.host == 'www.youtube.com' && uri.pathSegments.contains('watch')) {
      return uri.queryParameters['v'];
    }
  } catch (e) {
    log(e.toString());
  }

  return null;
}

/// 提取YouTube Music视频ID
/// 从YouTube Music URL中提取视频ID
/// @param url YouTube Music URL
/// @return 返回视频ID，如果提取失败返回null
String? extractYTMusicId(String url) {
  try {
    Uri uri = Uri.parse(url);
    if (uri.host == 'music.youtube.com') {
      return uri.queryParameters['v']; // Retrieve video ID from query parameter
    }
  } catch (e) {
    log(e.toString());
  }

  return null;
}

/// 提取Spotify播放列表ID
/// 从Spotify播放列表URL中提取列表ID
/// @param url Spotify播放列表URL
/// @return 返回播放列表ID，如果提取失败返回null
String? extractSpotifyPlaylistId(String url) {
  try {
    Uri uri = Uri.parse(url);
    if (uri.host == 'open.spotify.com') {
      final pathParts = uri.pathSegments;
      if (pathParts.length < 2) {
        return null;
      }
      if (pathParts[0] == 'playlist') {
        return pathParts[1];
      }
    }
  } catch (e) {
    log(e.toString());
  }
  return null;
}

/// 提取Spotify专辑ID
/// 从Spotify专辑URL中提取专辑ID
/// @param url Spotify专辑URL
/// @return 返回专辑ID，如果提取失败返回null
String? extractSpotifyAlbumId(String url) {
  try {
    Uri uri = Uri.parse(url);
    if (uri.host == 'open.spotify.com') {
      final pathParts = uri.pathSegments;
      if (pathParts.length < 2) {
        return null;
      }
      if (pathParts[0] == 'album') {
        return pathParts[1];
      }
    }
  } catch (e) {
    log(e.toString());
  }
  return null;
}

/// 提取Spotify音轨ID
/// 从Spotify音轨URL中提取音轨ID
/// @param url Spotify音轨URL
/// @return 返回音轨ID，如果提取失败返回null
String? extractSpotifyTrackId(String url) {
  try {
    Uri uri = Uri.parse(url);
    if (uri.host == 'open.spotify.com') {
      final pathParts = uri.pathSegments;
      if (pathParts.length < 2) {
        return null;
      }
      if (pathParts[0] == 'track') {
        return pathParts[1];
      }
    }
  } catch (e) {
    log(e.toString(), name: 'extractSpotifyTrackId');
  }
  return null;
}

/// 检查是否为URL
/// @param url 要检查的字符串
/// @return 如果是有效的URL返回true
bool isUrl(String url) {
  try {
    Uri.parse(url);
    return true;
  } catch (e) {
    return false;
  }
}

enum UrlType {
  youtubeVideo,
  youtubePlaylist,
  spotifyTrack,
  spotifyPlaylist,
  spotifyAlbum,
  other
}

/// 获取URL类型
/// 检查URL的类型（播放列表、专辑或音轨）
/// @param url 要检查的URL
/// @return 返回URL类型字符串
UrlType getUrlType(String url) {
  if (isUrl(url)) {
    if (isYoutubeLink(url)) {
      if (url.contains("playlist")) {
        return UrlType.youtubePlaylist;
      } else {
        return UrlType.youtubeVideo;
      }
    } else {
      final spotifyUrl = isSpotifyUrl(url);
      if (spotifyUrl['isSpotify']) {
        if (spotifyUrl['type'] == 'playlist') {
          return UrlType.spotifyPlaylist;
        } else if (spotifyUrl['type'] == 'track') {
          return UrlType.spotifyTrack;
        } else if (spotifyUrl['type'] == 'album') {
          return UrlType.spotifyAlbum;
        }
      }
    }
  }
  return UrlType.other;
}
