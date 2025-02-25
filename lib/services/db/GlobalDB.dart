// ignore_for_file: public_member_api_docs, sort_constructors_first
// import 'dart:js_util';

import 'dart:convert';

import 'package:isar/isar.dart';

part 'GlobalDB.g.dart';

/// 媒体播放列表数据库模型
/// 用于存储播放列表及其包含的媒体项目信息
@collection
class MediaPlaylistDB {
  /// 使用播放列表名称生成的唯一ID
  Id get isarId => fastHash(playlistName);
  
  /// 播放列表名称
  String playlistName;
  
  /// 媒体项目的排序顺序
  List<int> mediaRanks = List.empty(growable: true);
  
  /// 最后更新时间
  DateTime? lastUpdated;

  MediaPlaylistDB({
    required this.playlistName,
    this.lastUpdated,
  });

  /// 与播放列表关联的媒体项目集合
  @Backlink(to: "mediaInPlaylistsDB")
  IsarLinks<MediaItemDB> mediaItems = IsarLinks<MediaItemDB>();

  @override
  bool operator ==(covariant MediaPlaylistDB other) {
    if (identical(this, other)) return true;
    return other.playlistName == playlistName;
  }

  @override
  int get hashCode => playlistName.hashCode;
}

/// 播放列表信息数据库模型
/// 存储播放列表的元数据信息
@collection
class PlaylistsInfoDB {
  /// 使用播放列表名称生成的唯一ID
  Id get isarId => fastHash(playlistName);
  
  /// 播放列表名称
  String playlistName;
  
  /// 是否为专辑
  bool? isAlbum;
  
  /// 封面图片URL
  String? artURL;
  
  /// 播放列表描述
  String? description;
  
  /// 永久链接
  String? permaURL;
  
  /// 来源平台
  String? source;
  
  /// 艺术家信息
  String? artists;
  
  /// 最后更新时间
  DateTime lastUpdated;

  PlaylistsInfoDB({
    required this.playlistName,
    required this.lastUpdated,
    this.isAlbum,
    this.artURL,
    this.description,
    this.permaURL,
    this.source,
    this.artists,
  });

  @override
  bool operator ==(covariant PlaylistsInfoDB other) {
    if (identical(this, other)) return true;
    return other.playlistName == playlistName;
  }

  @override
  int get hashCode {
    return playlistName.hashCode;
  }

  @override
  String toString() {
    return 'PlaylistsInfoDB(playlistName: $playlistName, isAlbum: $isAlbum, artURL: $artURL, description: $description, permaURL: $permaURL, source: $source, artists: $artists, lastUpdated: $lastUpdated)';
  }

  /// 将对象转换为Map
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'playlistName': playlistName,
      'isAlbum': isAlbum,
      'artURL': artURL,
      'description': description,
      'permaURL': permaURL,
      'source': source,
      'artists': artists,
      'lastUpdated': lastUpdated.millisecondsSinceEpoch,
    };
  }

  /// 从Map创建对象
  factory PlaylistsInfoDB.fromMap(Map<String, dynamic> map) {
    return PlaylistsInfoDB(
      playlistName: map['playlistName'] as String,
      isAlbum: map['isAlbum'] != null ? map['isAlbum'] as bool : null,
      artURL: map['artURL'] != null ? map['artURL'] as String : null,
      description:
          map['description'] != null ? map['description'] as String : null,
      permaURL: map['permaURL'] != null ? map['permaURL'] as String : null,
      source: map['source'] != null ? map['source'] as String : null,
      artists: map['artists'] != null ? map['artists'] as String : null,
      lastUpdated:
          DateTime.fromMillisecondsSinceEpoch(map['lastUpdated'] as int),
    );
  }

  String toJson() => json.encode(toMap());

  factory PlaylistsInfoDB.fromJson(String source) =>
      PlaylistsInfoDB.fromMap(json.decode(source) as Map<String, dynamic>);
}

/// 媒体项目数据库模型
/// 用于存储单个媒体项目（如歌曲）的详细信息
@collection
class MediaItemDB {
  /// 自增主键ID
  Id? id = Isar.autoIncrement;
  
  /// 媒体标题
  @Index()
  String title;
  
  /// 所属专辑
  String album;
  
  /// 艺术家
  String artist;
  
  /// 封面图片URL
  String artURL;
  
  /// 音乐流派
  String genre;
  
  /// 时长（秒）
  int? duration;
  
  /// 媒体唯一标识
  String mediaID;
  
  /// 流媒体URL
  String streamingURL;
  
  /// 来源平台
  String? source;
  
  /// 永久链接
  String permaURL;
  
  /// 语言
  String language;
  
  /// 是否已收藏
  bool isLiked = false;

  /// 媒体项目所属的播放列表集合
  IsarLinks<MediaPlaylistDB> mediaInPlaylistsDB = IsarLinks<MediaPlaylistDB>();

  MediaItemDB({
    this.id,
    required this.title,
    required this.album,
    required this.artist,
    required this.artURL,
    required this.genre,
    required this.mediaID,
    required this.streamingURL,
    this.source,
    this.duration,
    required this.permaURL,
    required this.language,
    required this.isLiked,
  });

  @override
  bool operator ==(covariant MediaItemDB other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.title == title &&
        other.album == album &&
        other.artist == artist &&
        other.artURL == artURL &&
        other.genre == genre &&
        other.mediaID == mediaID &&
        other.streamingURL == streamingURL &&
        other.source == source &&
        other.duration == duration &&
        other.permaURL == permaURL &&
        other.language == language;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        album.hashCode ^
        artist.hashCode ^
        artURL.hashCode ^
        genre.hashCode ^
        mediaID.hashCode ^
        streamingURL.hashCode ^
        source.hashCode ^
        duration.hashCode ^
        permaURL.hashCode ^
        language.hashCode;
  }

  /// 将对象转换为Map
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': null,
      'title': title,
      'album': album,
      'artist': artist,
      'artURL': artURL,
      'genre': genre,
      'duration': duration,
      'mediaID': mediaID,
      'streamingURL': streamingURL,
      'source': source,
      'permaURL': permaURL,
      'language': language,
      'isLiked': isLiked,
    };
  }

  /// 从Map创建对象
  factory MediaItemDB.fromMap(Map<String, dynamic> map) {
    return MediaItemDB(
      id: null,
      title: map['title'] as String,
      album: map['album'] as String,
      artist: map['artist'] as String,
      artURL: map['artURL'] as String,
      genre: map['genre'] as String,
      duration: map['duration'] != null ? map['duration'] as int : null,
      mediaID: map['mediaID'] as String,
      streamingURL: map['streamingURL'] as String,
      source: map['source'] != null ? map['source'] as String : null,
      permaURL: map['permaURL'] as String,
      language: map['language'] as String,
      isLiked: map['isLiked'] as bool,
    );
  }

  /// 将对象转换为JSON字符串
  String toJson() => json.encode(toMap());

  /// 从JSON字符串创建对象
  factory MediaItemDB.fromJson(String source) =>
      MediaItemDB.fromMap(json.decode(source) as Map<String, dynamic>);
}
/// 快速哈希函数
/// 用于生成字符串的唯一哈希值，主要用于数据库ID生成
/// @param string 需要计算哈希值的字符串
/// @return 返回计算得到的哈希值
int fastHash(String string) {
  var hash = 0xcbf29ce484222325;

  var i = 0;
  while (i < string.length) {
    final codeUnit = string.codeUnitAt(i++);
    hash ^= codeUnit >> 8;
    hash *= 0x100000001b3;
    hash ^= codeUnit & 0xFF;
    hash *= 0x100000001b3;
  }

  return hash;
}

/// 应用程序字符串设置数据库模型
/// 用于存储应用程序的字符串类型配置项
@collection
class AppSettingsStrDB {
  /// 使用设置名称生成的唯一ID
  Id get isarId => fastHash(settingName);
  
  /// 设置项名称
  String settingName;
  
  /// 设置项值
  String settingValue;
  
  /// 设置项备用值
  String? settingValue2;
  
  /// 最后更新时间
  DateTime? lastUpdated;
  
  AppSettingsStrDB({
    required this.settingName,
    required this.settingValue,
    this.settingValue2,
    this.lastUpdated,
  });

  @override
  bool operator ==(covariant AppSettingsStrDB other) {
    if (identical(this, other)) return true;

    return other.settingName == settingName &&
        other.settingValue == settingValue;
  }

  @override
  int get hashCode => settingName.hashCode ^ settingValue.hashCode;
}

/// 应用程序布尔值设置数据库模型
/// 用于存储应用程序的布尔类型配置项
@collection
class AppSettingsBoolDB {
  /// 使用设置名称生成的唯一ID
  Id get isarId => fastHash(settingName);
  
  /// 设置项名称
  String settingName;
  
  /// 设置项布尔值
  bool settingValue;
  
  AppSettingsBoolDB({
    required this.settingName,
    required this.settingValue,
  });

  @override
  bool operator ==(covariant AppSettingsBoolDB other) {
    if (identical(this, other)) return true;

    return other.settingName == settingName &&
        other.settingValue == settingValue;
  }

  @override
  int get hashCode => settingName.hashCode ^ settingValue.hashCode;
}

/// 排行榜缓存数据库模型
/// 用于存储音乐排行榜的缓存数据
@collection
class ChartsCacheDB {
  /// 使用排行榜名称生成的唯一ID
  Id get isarId => fastHash(chartName);
  
  /// 排行榜名称
  String chartName;
  
  /// 最后更新时间
  DateTime lastUpdated;
  
  /// 永久链接
  String? permaURL;
  
  /// 排行榜项目列表
  List<ChartItemDB> chartItems;
  
  ChartsCacheDB({
    required this.chartName,
    required this.lastUpdated,
    required this.chartItems,
    this.permaURL,
  });
}

/// 排行榜项目数据库模型
/// 用于存储排行榜中的单个音乐项目信息
@embedded
class ChartItemDB {
  /// 音乐标题
  String? title;
  
  /// 艺术家
  String? artist;
  
  /// 封面图片URL
  String? artURL;
}

/// 最近播放记录数据库模型
/// 用于存储用户最近播放的媒体项目
@collection
class RecentlyPlayedDB {
  /// 自增主键ID
  Id? id;
  
  /// 最后播放时间
  DateTime lastPlayed;
  
  RecentlyPlayedDB({
    this.id,
    required this.lastPlayed,
  });
  
  /// 关联的媒体项目
  IsarLink<MediaItemDB> mediaItem = IsarLink<MediaItemDB>();
}

/// YouTube链接缓存数据库模型
/// 用于存储YouTube视频流URL的缓存信息
@collection
class YtLinkCacheDB {
  /// 使用视频ID生成的唯一ID
  Id get isarId => fastHash(videoId);
  
  /// 视频ID
  String videoId;
  
  /// 低质量视频流URL
  String? lowQURL;
  
  /// 高质量视频流URL
  String highQURL;
  
  /// 过期时间戳
  int expireAt;
  
  YtLinkCacheDB({
    required this.videoId,
    required this.lowQURL,
    required this.highQURL,
    required this.expireAt,
  });
}

/// 下载记录数据库模型
/// 用于存储已下载的媒体文件信息
@collection
class DownloadDB {
  /// 自增主键ID
  Id? id = Isar.autoIncrement;
  /// 文件名
  String fileName;
  /// 文件路径
  String filePath;
  /// 最后下载时间
  DateTime? lastDownloaded;
  /// 媒体ID
  String mediaId;
  DownloadDB({
    this.id,
    required this.fileName,
    required this.filePath,
    required this.lastDownloaded,
    required this.mediaId,
  });
}

/// 收藏集合数据库模型
/// 用于存储用户收藏的音乐集合（如专辑、播放列表等）
@collection
class SavedCollectionsDB {
  /// 使用标题生成的唯一ID
  Id get isarId => fastHash(title);
  /// 集合标题
  String title;
  /// 来源ID
  String sourceId;
  /// 来源平台
  String source;
  /// 集合类型
  String type;
  /// 封面图片URL
  String coverArt;
  /// 来源URL
  String sourceURL;
  /// 副标题
  String? subtitle;
  /// 最后更新时间
  DateTime lastUpdated;
  /// 额外信息
  String? extra;
  SavedCollectionsDB({
    required this.title,
    required this.type,
    required this.coverArt,
    required this.sourceURL,
    required this.sourceId,
    required this.source,
    required this.lastUpdated,
    this.subtitle,
    this.extra,
  });
}

/// 通知数据库模型
/// 用于存储应用程序的通知信息
@collection
class NotificationDB {
  /// 自增主键ID
  Id? id = Isar.autoIncrement;
  /// 通知标题
  String title;
  /// 通知内容
  String body;
  /// 通知类型
  String type;
  /// 相关URL
  String? url;
  /// 通知负载数据
  String? payload;
  /// 通知时间
  DateTime? time;
  NotificationDB({
    this.id,
    required this.title,
    required this.body,
    required this.time,
    required this.type,
    this.url,
    this.payload,
  });
}

/// 歌词数据库模型
/// 用于存储歌曲的歌词信息
@collection
class LyricsDB {
  /// 使用媒体ID生成的唯一ID
  Id get isarId => fastHash(mediaID);
  /// 来源ID
  String sourceId;
  /// 媒体ID
  String mediaID;
  /// 纯文本歌词
  String plainLyrics;
  /// 歌曲标题
  String title;
  /// 艺术家
  String artist;
  /// 来源平台
  String source;
  /// 所属专辑
  String? album;
  /// 时间偏移（毫秒）
  int? offset;
  /// 歌曲时长（毫秒）
  int? duration;
  /// 歌词URL
  String? url;
  /// 同步歌词
  String? syncedLyrics;
  LyricsDB({
    required this.sourceId,
    required this.mediaID,
    required this.plainLyrics,
    required this.title,
    required this.artist,
    required this.source,
    this.album,
    this.offset,
    this.duration,
    this.syncedLyrics,
    this.url,
  });
}
