/// BloomeeDBService类
/// 负责管理应用程序的数据库服务，包括数据库的初始化、备份恢复、数据操作等功能

import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:Bloomee/model/MediaPlaylistModel.dart';
import 'package:Bloomee/model/album_onl_model.dart';
import 'package:Bloomee/model/artist_onl_model.dart';
import 'package:Bloomee/model/chart_model.dart';
import 'package:Bloomee/model/lyrics_models.dart';
import 'package:Bloomee/model/playlist_onl_model.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:path/path.dart' as p;
import 'package:isar/isar.dart';
import 'package:Bloomee/services/db/GlobalDB.dart';

/// 数据库服务类
/// 使用单例模式实现，确保整个应用程序只有一个数据库实例
class BloomeeDBService {
  /// 数据库实例
  static late Future<Isar> db;
  /// 应用程序支持目录路径
  static late String appSuppDir;
  /// 应用程序文档目录路径
  static late String appDocDir;
  /// 单例实例
  static final BloomeeDBService _instance = BloomeeDBService._internal();

  /// 获取单例实例
  BloomeeDBService get instance => _instance;

  /// 工厂构造函数
  /// @param appSuppPath 应用程序支持目录路径
  /// @param appDocPath 应用程序文档目录路径
  factory BloomeeDBService({String? appSuppPath, String? appDocPath}) {
    if (appSuppPath != null) {
      appSuppDir = appSuppPath;
    }
    if (appDocPath != null) {
      appDocDir = appDocPath;
    }

    return _instance;
  }

  /// 私有构造函数
  /// 初始化数据库并设置定时任务清理无关联的媒体项目
  BloomeeDBService._internal() {
    db = openDB();
    Future.delayed(const Duration(seconds: 30), () async {
      await refreshRecentlyPlayed();
      await purgeUnassociatedMediaItems();
    });
  }

  /// 检查并自动恢复数据库备份
  /// 当数据库文件不存在时，尝试从备份路径恢复
  /// @param dbPath 数据库文件路径
  /// @param bPaths 备份文件路径列表
  static Future<void> checkAndRestoreDB(
      String dbPath, List<String> bPaths) async {
    try {
      final File dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        for (var element in bPaths) {
          final File backUpFile = File(element);
          if (await backUpFile.exists()) {
            await backUpFile.copy(dbFile.path);
            log("DB Restored from $element", name: "BloomeeDBService");
            break;
          }
        }
      }
    } catch (e) {
      log("Failed to restore DB", error: e, name: "BloomeeDBService");
    }
  }

  /// 打开数据库
  /// 初始化并打开Isar数据库实例
  /// 如果数据库文件不存在，会尝试从备份恢复
  /// @return 返回Isar数据库实例
  static Future<Isar> openDB() async {
    if (Isar.instanceNames.isEmpty) {
      //check if DB exists in support directory
      final File dbFile = File(p.join(appSuppDir, 'default.isar'));
      if (!await dbFile.exists()) {
        // check for backup and restore
        await checkAndRestoreDB(dbFile.path, [
          p.join(appDocDir, 'default.isar'),
          p.join(appDocDir, 'bloomee_backup_db.isar'),
          p.join(appSuppDir, 'bloomee_backup_db.isar'),
        ]);
      }

      if (!await dbFile.exists() &&
          await File(p.join(appDocDir, 'default.isar')).exists()) {
        final _db = Isar.openSync(
          [
            MediaPlaylistDBSchema,
            MediaItemDBSchema,
            AppSettingsBoolDBSchema,
            AppSettingsStrDBSchema,
            RecentlyPlayedDBSchema,
            ChartsCacheDBSchema,
            YtLinkCacheDBSchema,
            NotificationDBSchema,
            DownloadDBSchema,
            PlaylistsInfoDBSchema,
            SavedCollectionsDBSchema,
            LyricsDBSchema,
          ],
          directory: appDocDir,
        );
        _db.copyToFile(dbFile.path);
        log("DB Copied to $appSuppDir", name: "BloomeeDBService");
        _db.close();
      }

      log(appSuppDir, name: "DB");
      return Isar.openSync(
        [
          MediaPlaylistDBSchema,
          MediaItemDBSchema,
          AppSettingsBoolDBSchema,
          AppSettingsStrDBSchema,
          RecentlyPlayedDBSchema,
          ChartsCacheDBSchema,
          YtLinkCacheDBSchema,
          NotificationDBSchema,
          DownloadDBSchema,
          PlaylistsInfoDBSchema,
          SavedCollectionsDBSchema,
          LyricsDBSchema,
        ],
        directory: appSuppDir,
      );
    }
    return Future.value(Isar.getInstance());
  }

  /// 创建数据库备份
  /// 将当前数据库文件复制到备份目录
  /// @return 备份是否成功
  static Future<bool> createBackUp() async {
    try {
      final isar = await db;
      String? backUpDir;
      try {
        backUpDir = await getSettingStr(GlobalStrConsts.backupPath);
      } catch (e) {
        log(e.toString(), name: "DB");
        backUpDir = appDocDir;
      }

      final File backUpFile = File('$backUpDir/bloomee_backup_db.isar');
      if (await backUpFile.exists()) {
        await backUpFile.delete();
      }

      await isar.copyToFile('$backUpDir/bloomee_backup_db.isar');

      log("Backup created successfully ${backUpFile.path}",
          name: "BloomeeDBService");
      return true;
    } catch (e) {
      log("Failed to create backup", error: e, name: "BloomeeDBService");
    }
    return false;
  }

  /// 检查数据库备份是否存在
  /// @return 如果备份文件存在返回true，否则返回false
  static Future<bool> backupExists() async {
    try {
      String? backUpDir;
      try {
        backUpDir = await getSettingStr(GlobalStrConsts.backupPath);
      } catch (e) {
        log(e.toString(), name: "DB");
        backUpDir = appDocDir;
      }

      final dbFile = File('$backUpDir/bloomee_backup_db.isar');
      if (dbFile.existsSync()) {
        return true;
      }
    } catch (e) {
      log("No backup exists", error: e, name: "BloomeeDBService");
    }
    return false;
  }

  /// 从备份恢复数据库
  /// 用备份文件替换当前数据库文件
  /// @return 恢复是否成功
  static Future<bool> restoreDB() async {
    try {
      final isar = await db;

      String? backUpDir;
      try {
        backUpDir = await getSettingStr(GlobalStrConsts.backupPath);
      } catch (e) {
        log(e.toString(), name: "DB");
        backUpDir = appDocDir;
      }

      await isar.close();

      final dbFile = File('$backUpDir/bloomee_backup_db.isar');
      final dbPath = File('$appSuppDir/default.isar');

      if (await dbFile.exists()) {
        await dbFile.copy(dbPath.path);
        log("Successfully restored", name: "BloomeeDBService");
        BloomeeDBService();
        return true;
      }
    } catch (e) {
      log("Restoring DB failed", error: e, name: "BloomeeDBService");
    }
    BloomeeDBService();
    return false;
  }

  /// 向播放列表添加媒体项目
  /// @param mediaItemDB 要添加的媒体项目
  /// @param playlistName 目标播放列表名称
  /// @return 返回添加的媒体项目ID
  static Future<int?> addMediaItem(
      MediaItemDB mediaItemDB, String playlistName) async {
    int? id;
    Isar isarDB = await db;
    MediaPlaylistDB mediaPlaylistDB =
        MediaPlaylistDB(playlistName: playlistName);

    // search for media item if already exists
    MediaItemDB? _mediaitem = isarDB.mediaItemDBs
        .filter()
        .permaURLEqualTo(mediaItemDB.permaURL)
        .findFirstSync();

    // search for playlist if already exists
    MediaPlaylistDB? _mediaPlaylistDB = isarDB.mediaPlaylistDBs
        .filter()
        .isarIdEqualTo(mediaPlaylistDB.isarId)
        .findFirstSync();
    log(_mediaPlaylistDB.toString(), name: "DB");

    if (_mediaPlaylistDB == null) {
      // create playlist if not exists
      final tmpId = await createPlaylist(playlistName);
      _mediaPlaylistDB = isarDB.mediaPlaylistDBs
          .filter()
          .isarIdEqualTo(mediaPlaylistDB.isarId)
          .findFirstSync();
      log("${_mediaPlaylistDB.toString()} ID: $tmpId", name: "DB");
    }

    // add playlist to _mediaitem
    if (_mediaitem != null) {
      // update and save existing media item
      _mediaitem.mediaInPlaylistsDB.add(_mediaPlaylistDB!);
      id = _mediaitem.id;
      isarDB.writeTxnSync(() => isarDB.mediaItemDBs.putSync(_mediaitem!));
    } else {
      // save given new media item
      _mediaitem = mediaItemDB;
      log("id: ${_mediaitem.id}", name: "DB");
      _mediaitem.mediaInPlaylistsDB.add(mediaPlaylistDB);
      isarDB.writeTxnSync(() => id = isarDB.mediaItemDBs.putSync(_mediaitem!));
    }

    // add current rank for media item in playlist orderList
    if (!(_mediaPlaylistDB?.mediaRanks.contains(_mediaitem.id) ?? false)) {
      mediaPlaylistDB = _mediaitem.mediaInPlaylistsDB
          .filter()
          .isarIdEqualTo(mediaPlaylistDB.isarId)
          .findFirstSync()!;

      List<int> _list = mediaPlaylistDB.mediaRanks.toList(growable: true);
      _list.add(_mediaitem.id!);
      mediaPlaylistDB.mediaRanks = _list;
      isarDB
          .writeTxnSync(() => isarDB.mediaPlaylistDBs.putSync(mediaPlaylistDB));
      log(mediaPlaylistDB.mediaRanks.toString(), name: "DB");
    }

    return id;
  }

  /// 删除媒体项目
  /// @param mediaItemDB 要删除的媒体项目
  static Future<void> removeMediaItem(MediaItemDB mediaItemDB) async {
    Isar isarDB = await db;
    bool _res = false;
    isarDB.writeTxnSync(
        () => _res = isarDB.mediaItemDBs.deleteSync(mediaItemDB.id!));
    if (_res) {
      log("${mediaItemDB.title} is Deleted!!", name: "DB");
    }
  }

  /// 清理未关联的媒体项目
  /// 删除没有关联到任何播放列表的媒体项目
  /// @param mediaItemDB 要检查的媒体项目
  static Future<void> purgeUnassociatedMediaItem(
      MediaItemDB mediaItemDB) async {
    // Remove media items that are not associated with any playlist
    if (mediaItemDB.mediaInPlaylistsDB.isEmpty) {
      log("Purging ${mediaItemDB.title}", name: "DB");
      await removeMediaItem(mediaItemDB);
    }
  }

  /// 清理所有未关联的媒体项目
  /// 遍历并删除所有没有关联到播放列表的媒体项目
  static Future<void> purgeUnassociatedMediaItems() async {
    // Remove media items that are not associated with any playlist
    Isar isarDB = await db;
    List<MediaItemDB> mediaItems = isarDB.mediaItemDBs.where().findAllSync();
    for (var element in mediaItems) {
      await purgeUnassociatedMediaItem(element);
    }
  }

  /// 从列表中清理未关联的媒体项目
  /// @param mediaItems 要检查的媒体项目列表
  static Future<void> purgeUnassociatedMediaFromList(
      List<MediaItemDB> mediaItems) async {
    // purge media items that are not associated with any playlist from given list
    for (var element in mediaItems) {
      await purgeUnassociatedMediaItem(element);
    }
  }

  /// 从播放列表中移除媒体项目
  /// @param mediaItemDB 要移除的媒体项目
  /// @param mediaPlaylistDB 所在的播放列表
  static Future<void> removeMediaItemFromPlaylist(
      MediaItemDB mediaItemDB, MediaPlaylistDB mediaPlaylistDB) async {
    Isar isarDB = await db;
    MediaItemDB? _mediaitem = isarDB.mediaItemDBs
        .filter()
        .permaURLEqualTo(mediaItemDB.permaURL)
        .findFirstSync();

    MediaPlaylistDB? _mediaPlaylistDB = isarDB.mediaPlaylistDBs
        .filter()
        .isarIdEqualTo(mediaPlaylistDB.isarId)
        .findFirstSync();

    if (_mediaitem != null && _mediaPlaylistDB != null) {
      if (_mediaitem.mediaInPlaylistsDB.contains(mediaPlaylistDB)) {
        _mediaitem.mediaInPlaylistsDB.remove(mediaPlaylistDB);
        log("Removed from playlist", name: "DB");
        isarDB.writeTxnSync(() => isarDB.mediaItemDBs.putSync(_mediaitem));
        if (_mediaitem.mediaInPlaylistsDB.isEmpty) {
          await removeMediaItem(_mediaitem);
        }
        if (_mediaPlaylistDB.mediaRanks.contains(_mediaitem.id)) {
          // _mediaPlaylistDB.mediaRanks.indexOf(_mediaitem.id!)

          List<int> _list = _mediaPlaylistDB.mediaRanks.toList(growable: true);
          _list.remove(_mediaitem.id);
          _mediaPlaylistDB.mediaRanks = _list;
          isarDB.writeTxnSync(
              () => isarDB.mediaPlaylistDBs.putSync(_mediaPlaylistDB));
        }
      }
    } else {
      log("MediaItem or MediaPlaylist is null", name: "DB");
      if (_mediaitem != null) {
        await purgeUnassociatedMediaItem(_mediaitem);
      }
    }
  }

  /// 添加播放列表
  /// @param mediaPlaylistDB 要添加的播放列表
  /// @return 返回添加的播放列表ID
  static Future<int?> addPlaylist(MediaPlaylistDB mediaPlaylistDB) async {
    Isar isarDB = await db;
    int? id;
    if (mediaPlaylistDB.playlistName.isEmpty) {
      return null;
    }
    MediaPlaylistDB? _mediaPlaylist = isarDB.mediaPlaylistDBs
        .filter()
        .isarIdEqualTo(mediaPlaylistDB.isarId)
        .findFirstSync();

    if (_mediaPlaylist == null) {
      id = isarDB
          .writeTxnSync(() => isarDB.mediaPlaylistDBs.putSync(mediaPlaylistDB));
    } else {
      log("Already created", name: "DB");
      id = _mediaPlaylist.isarId;
    }
    return id;
  }

  /// 创建新的播放列表
  /// @param playlistName 播放列表名称
  /// @param artURL 封面图片URL
  /// @param description 播放列表描述
  /// @param permaURL 永久链接
  /// @param source 来源平台
  /// @param artists 艺术家信息
  /// @param isAlbum 是否为专辑
  /// @param mediaItems 初始媒体项目列表
  /// @return 返回创建的播放列表ID
  static Future<int?> createPlaylist(
    String playlistName, {
    String? artURL,
    String? description,
    String? permaURL,
    String? source,
    String? artists,
    bool isAlbum = false,
    List<MediaItemDB> mediaItems = const [],
  }) async {
    if (playlistName.isEmpty) {
      return null;
    }

    int? id;
    MediaPlaylistDB mediaPlaylistDB = MediaPlaylistDB(
      playlistName: playlistName,
      lastUpdated: DateTime.now(),
    );
    id = await addPlaylist(mediaPlaylistDB);
    if (id != null) {
      if (mediaItems.isNotEmpty) {
        for (var element in mediaItems) {
          await addMediaItem(element, playlistName);
        }
      }
      if (artURL != null ||
          description != null ||
          permaURL != null ||
          source != null ||
          artists != null ||
          isAlbum) {
        await createPlaylistInfo(
          playlistName,
          artURL: artURL,
          description: description,
          permaURL: permaURL,
          source: source,
          artists: artists,
          isAlbum: isAlbum,
        );
      }
      log("Playlist Created: $playlistName", name: "DB");
    }
    return id;
  }

  /// 获取播放列表
  /// @param playlistName 播放列表名称
  /// @return 返回播放列表对象
  static Future<MediaPlaylistDB?> getPlaylist(String playlistName) async {
    Isar isarDB = await db;
    return isarDB.mediaPlaylistDBs
        .filter()
        .playlistNameEqualTo(playlistName)
        .findFirstSync();
  }

  /// 删除播放列表
  /// @param mediaPlaylistDB 要删除的播放列表
  static Future<void> removePlaylist(MediaPlaylistDB mediaPlaylistDB) async {
    Isar isarDB = await db;
    bool _res = false;

    MediaPlaylistDB? _mediaPlaylistDB = isarDB.mediaPlaylistDBs
        .filter()
        .isarIdEqualTo(mediaPlaylistDB.isarId)
        .findFirstSync();
    if (_mediaPlaylistDB != null) {
      final mediaItems = _mediaPlaylistDB.mediaItems.map((e) => e).toList();
      isarDB.writeTxnSync(() =>
          _res = isarDB.mediaPlaylistDBs.deleteSync(mediaPlaylistDB.isarId));
      if (_res) {
        await purgeUnassociatedMediaFromList(mediaItems);
        await removePlaylistByName(mediaPlaylistDB.playlistName);
        log("${mediaPlaylistDB.playlistName} is Deleted!!", name: "DB");
      }
    }
  }

  /// 根据名称删除播放列表
  /// @param playlistName 要删除的播放列表名称
  static Future<void> removePlaylistByName(String playlistName) async {
    Isar isarDB = await db;
    MediaPlaylistDB? mediaPlaylistDB = isarDB.mediaPlaylistDBs
        .filter()
        .playlistNameEqualTo(playlistName)
        .findFirstSync();
    if (mediaPlaylistDB != null) {
      await removePlaylist(mediaPlaylistDB);
    }
  }

  /// 获取播放列表中媒体项目的排序
  /// @param mediaPlaylistDB 播放列表
  /// @return 返回排序索引列表
  static Future<List<int>> getPlaylistItemsRank(
      MediaPlaylistDB mediaPlaylistDB) async {
    Isar isarDB = await db;
    return isarDB.mediaPlaylistDBs
            .getSync(mediaPlaylistDB.isarId)
            ?.mediaRanks
            .toList() ??
        [];
  }

  /// 根据播放列表名称获取媒体项目的排序
  /// @param playlistName 播放列表名称
  /// @return 返回排序索引列表
  static Future<List<int>> getPlaylistItemsRankByName(
      String playlistName) async {
    Isar isarDB = await db;
    MediaPlaylistDB? mediaPlaylistDB = isarDB.mediaPlaylistDBs
        .filter()
        .playlistNameEqualTo(playlistName)
        .findFirstSync();
    return mediaPlaylistDB?.mediaRanks.toList() ?? [];
  }

  /// 设置播放列表中媒体项目的排序
  /// @param mediaPlaylistDB 播放列表
  /// @param rankList 排序索引列表
  static Future<void> setPlaylistItemsRank(
      MediaPlaylistDB mediaPlaylistDB, List<int> rankList) async {
    Isar isarDB = await db;
    MediaPlaylistDB? _mediaPlaylistDB =
        isarDB.mediaPlaylistDBs.getSync(mediaPlaylistDB.isarId);
    if (_mediaPlaylistDB != null &&
        _mediaPlaylistDB.mediaItems.length >= rankList.length) {
      isarDB.writeTxnSync(() {
        _mediaPlaylistDB.mediaRanks = rankList;
        isarDB.mediaPlaylistDBs.putSync(_mediaPlaylistDB);
      });
    }
  }

  /// 根据播放列表名称更新媒体项目的排序
  /// @param playlistName 播放列表名称
  /// @param rankList 排序索引列表
  static Future<void> updatePltItemsRankByName(
      String playlistName, List<int> rankList) async {
    Isar isarDB = await db;
    MediaPlaylistDB? mediaPlaylistDB = isarDB.mediaPlaylistDBs
        .filter()
        .playlistNameEqualTo(playlistName)
        .findFirstSync();
    if (mediaPlaylistDB != null &&
        mediaPlaylistDB.mediaItems.length >= rankList.length) {
      isarDB.writeTxnSync(() {
        mediaPlaylistDB.mediaRanks = rankList;
        isarDB.mediaPlaylistDBs.putSync(mediaPlaylistDB);
      });
    }
  }

  /// 获取播放列表中的所有媒体项目
  /// @param mediaPlaylistDB 播放列表
  /// @return 返回媒体项目列表
  static Future<List<MediaItemDB>?> getPlaylistItems(
      MediaPlaylistDB mediaPlaylistDB) async {
    Isar isarDB = await db;
    return isarDB.mediaPlaylistDBs
        .getSync(mediaPlaylistDB.isarId)
        ?.mediaItems
        .toList();
  }

  /// 根据播放列表名称获取所有媒体项目
  /// @param playlistName 播放列表名称
  /// @return 返回媒体项目列表
  static Future<List<MediaItemDB>?> getPlaylistItemsByName(
      String playlistName) async {
    Isar isarDB = await db;
    MediaPlaylistDB? mediaPlaylistDB = isarDB.mediaPlaylistDBs
        .filter()
        .playlistNameEqualTo(playlistName)
        .findFirstSync();
    return mediaPlaylistDB?.mediaItems.toList();
  }

  /// 获取所有播放列表
  /// @return 返回所有播放列表的列表
  static Future<List<MediaPlaylist>> getPlaylists4Library() async {
    Isar isarDB = await db;
    final playlists = await isarDB.mediaPlaylistDBs.where().findAll();
    List<MediaPlaylist> mediaPlaylists = [];
    for (var e in playlists) {
      PlaylistsInfoDB? info = await getPlaylistInfo(e.playlistName);
      mediaPlaylists
          .add(fromPlaylistDB2MediaPlaylist(e, playlistsInfoDB: info));
    }
    return mediaPlaylists;
  }

  /// 获取播放列表变化的观察者流
  /// @return 返回播放列表变化的数据流
  static Future<Stream<void>> getPlaylistsWatcher() async {
    Isar isarDB = await db;
    return isarDB.mediaPlaylistDBs.watchLazy(fireImmediately: true);
  }

  /// 创建播放列表信息
  /// @param playlistName 播放列表名称
  /// @param artURL 封面图片URL
  /// @param description 描述
  /// @param permaURL 永久链接
  /// @param source 来源
  /// @param artists 艺术家
  /// @param isAlbum 是否为专辑
  /// @return 返回创建的信息ID
  static Future<int?> createPlaylistInfo(
    String playlistName, {
    String? artURL,
    String? description,
    String? permaURL,
    String? source,
    String? artists,
    bool isAlbum = false,
  }) async {
    if (playlistName.isNotEmpty) {
      return await addPlaylistInfo(
        PlaylistsInfoDB(
          playlistName: playlistName,
          lastUpdated: DateTime.now(),
          artURL: artURL,
          description: description,
          permaURL: permaURL,
          source: source,
          artists: artists,
          isAlbum: isAlbum,
        ),
      );
    }
    return null;
  }

  /// 添加播放列表信息
  /// @param playlistInfoDB 播放列表信息对象
  /// @return 返回添加的信息ID
  static Future<int> addPlaylistInfo(PlaylistsInfoDB playlistInfoDB) async {
    Isar isarDB = await db;
    return isarDB
        .writeTxnSync(() => isarDB.playlistsInfoDBs.putSync(playlistInfoDB));
  }

  /// 更新播放列表信息
  /// @param playlistsInfoDB 播放列表信息对象
  Future<void> updatePlaylistInfo(PlaylistsInfoDB playlistsInfoDB) async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(() => isarDB.playlistsInfoDBs.putSync(playlistsInfoDB));
  }

  /// 删除播放列表信息
  /// @param playlistsInfoDB 播放列表信息对象
  static Future<void> removePlaylistInfo(
      PlaylistsInfoDB playlistsInfoDB) async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(
        () => isarDB.playlistsInfoDBs.deleteSync(playlistsInfoDB.isarId));
  }

  /// 获取播放列表信息
  /// @param playlistName 播放列表名称
  /// @return 返回播放列表信息对象
  static Future<PlaylistsInfoDB?> getPlaylistInfo(String playlistName) async {
    Isar isarDB = await db;
    return isarDB.playlistsInfoDBs
        .filter()
        .playlistNameEqualTo(playlistName)
        .findFirstSync();
  }

  /// 获取所有播放列表信息
  /// @return 返回所有播放列表信息的列表
  static Future<List<PlaylistsInfoDB>> getPlaylistsInfo() async {
    Isar isarDB = await db;
    return isarDB.playlistsInfoDBs.where().findAllSync();
  }

  static Future<void> removePlaylistInfoByName(String playlistName) async {
    Isar isarDB = await db;
    int c = isarDB.writeTxnSync(() => isarDB.playlistsInfoDBs
        .filter()
        .playlistNameEqualTo(playlistName)
        .deleteAllSync());
    log("$c items deleted", name: "DB");
  }

  /// 设置媒体项目的收藏状态
  /// @param mediaItemDB 要设置的媒体项目
  /// @param isLiked 是否收藏
  static Future<void> likeMediaItem(MediaItemDB mediaItemDB,
      {isLiked = false}) async {
    Isar isarDB = await db;
    addPlaylist(MediaPlaylistDB(playlistName: "Liked"));
    MediaItemDB? _mediaItem = isarDB.mediaItemDBs
        .filter()
        .titleEqualTo(mediaItemDB.title)
        .and()
        .permaURLEqualTo(mediaItemDB.permaURL)
        .findFirstSync();
    if (isLiked && _mediaItem != null) {
      addMediaItem(mediaItemDB, "Liked");
    } else if (_mediaItem != null) {
      removeMediaItemFromPlaylist(
          mediaItemDB, MediaPlaylistDB(playlistName: "Liked"));
    }
  }

  /// 重新排序播放列表中的媒体项目位置
  /// @param mediaPlaylistDB 播放列表
  /// @param old_idx 原始位置
  /// @param new_idx 新位置
  static Future<void> reorderItemPositionInPlaylist(
      MediaPlaylistDB mediaPlaylistDB, int old_idx, int new_idx) async {
    Isar isarDB = await db;
    MediaPlaylistDB? _mediaPlaylistDB = isarDB.mediaPlaylistDBs
        .where()
        .isarIdEqualTo(mediaPlaylistDB.isarId)
        .findFirstSync();

    if (_mediaPlaylistDB != null) {
      if (_mediaPlaylistDB.mediaRanks.length > old_idx &&
          _mediaPlaylistDB.mediaRanks.length > new_idx) {
        List<int> _rankList =
            _mediaPlaylistDB.mediaRanks.toList(growable: true);
        int _element = (_rankList.removeAt(old_idx));
        _rankList.insert(new_idx, _element);
        _mediaPlaylistDB.mediaRanks = _rankList;
        isarDB.writeTxnSync(
            () => isarDB.mediaPlaylistDBs.putSync(_mediaPlaylistDB));
      }
    }
  }

  /// 检查媒体项目是否已收藏
  /// @param mediaItemDB 要检查的媒体项目
  /// @return 返回是否已收藏
  static Future<bool> isMediaLiked(MediaItemDB mediaItemDB) async {
    Isar isarDB = await db;
    MediaItemDB? _mediaItemDB = isarDB.mediaItemDBs
        .filter()
        .permaURLEqualTo(mediaItemDB.permaURL)
        .findFirstSync();
    if (_mediaItemDB != null) {
      return (isarDB.mediaPlaylistDBs
                  .getSync(MediaPlaylistDB(playlistName: "Liked").isarId))
              ?.mediaItems
              .contains(_mediaItemDB) ??
          true;
    } else {
      return false;
    }
  }

  /// 获取播放列表的数据流
  /// @param mediaPlaylistDB 播放列表
  /// @return 返回播放列表的数据流
  static Future<Stream> getStream4MediaList(
      MediaPlaylistDB mediaPlaylistDB) async {
    Isar isarDB = await db;
    return isarDB.mediaPlaylistDBs.watchObject(mediaPlaylistDB.isarId);
  }

  /// 保存字符串类型的设置值
  /// @param key 设置项键
  /// @param value 设置项值
  static Future<void> putSettingStr(String key, String value) async {
    Isar isarDB = await db;
    if (key.isNotEmpty && value.isNotEmpty) {
      isarDB.writeTxnSync(() => isarDB.appSettingsStrDBs
          .putSync(AppSettingsStrDB(settingName: key, settingValue: value)));
    }
  }

  /// 保存布尔类型的设置值
  /// @param key 设置项键
  /// @param value 设置项值
  static Future<void> putSettingBool(String key, bool value) async {
    Isar isarDB = await db;
    if (key.isNotEmpty) {
      isarDB.writeTxnSync(() => isarDB.appSettingsBoolDBs
          .putSync(AppSettingsBoolDB(settingName: key, settingValue: value)));
    }
  }

  /// 保存API缓存
  /// @param key 缓存键
  /// @param value 缓存值
  static Future<void> putAPICache(String key, String value) async {
    Isar isarDB = await db;
    if (key.isNotEmpty && value.isNotEmpty) {
      isarDB.writeTxnSync(
        () => isarDB.appSettingsStrDBs.putSync(
          AppSettingsStrDB(
            settingName: key,
            settingValue: value,
            settingValue2: "CACHE",
            lastUpdated: DateTime.now(),
          ),
        ),
      );
    }
  }

  /// 获取API缓存
  /// @param key 缓存键
  /// @return 返回缓存值
  static Future<String?> getAPICache(String key) async {
    Isar isarDB = await db;
    final apiCache = isarDB.appSettingsStrDBs
        .filter()
        .settingNameEqualTo(key)
        .findFirstSync();
    if (apiCache != null) {
      return apiCache.settingValue;
    }
    return null;
  }

  /// 清除所有API缓存
  static clearAPICache() async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(
      () => isarDB.appSettingsStrDBs
          .filter()
          .settingValue2Contains("CACHE")
          .deleteAllSync(),
    );
  }

  /// 获取字符串类型的设置值
  /// @param key 设置项键
  /// @param defaultValue 默认值
  /// @return 返回设置值
  static Future<String?> getSettingStr(String key,
      {String? defaultValue}) async {
    Isar isarDB = await db;
    final settingValue = isarDB.appSettingsStrDBs
        .filter()
        .settingNameEqualTo(key)
        .findFirstSync()
        ?.settingValue;
    if (settingValue != null) {
      return settingValue;
    } else {
      // if (defaultValue != null) {
      //   putSettingStr(key, defaultValue);
      // }
      return defaultValue;
    }
  }

  static Future<bool?> getSettingBool(String key, {bool? defaultValue}) async {
    Isar isarDB = await db;
    final settingValue = isarDB.appSettingsBoolDBs
        .filter()
        .settingNameEqualTo(key)
        .findFirstSync()
        ?.settingValue;
    if (settingValue != null) {
      return settingValue;
    } else {
      // if (defaultValue != null) {
      //   putSettingBool(key, defaultValue);
      // }
      return defaultValue;
    }
  }

  static Future<Stream<AppSettingsStrDB?>?> getWatcher4SettingStr(
      String key) async {
    Isar isarDB = await db;
    int? id = isarDB.appSettingsStrDBs
        .filter()
        .settingNameEqualTo(key)
        .findFirstSync()
        ?.isarId;
    if (id != null) {
      return isarDB.appSettingsStrDBs.watchObject(
        id,
        fireImmediately: true,
      );
    } else {
      return null;
    }
  }

  static Future<Stream<AppSettingsBoolDB?>?> getWatcher4SettingBool(
      String key) async {
    Isar isarDB = await db;
    int? id = isarDB.appSettingsBoolDBs
        .filter()
        .settingNameEqualTo(key)
        .findFirstSync()
        ?.isarId;
    if (id != null) {
      return isarDB.appSettingsBoolDBs.watchObject(
        id,
        fireImmediately: true,
      );
    } else {
      isarDB.writeTxnSync(() => isarDB.appSettingsBoolDBs
          .putSync(AppSettingsBoolDB(settingName: key, settingValue: false)));
      return isarDB.appSettingsBoolDBs.watchObject(
        isarDB.appSettingsBoolDBs
            .filter()
            .settingNameEqualTo(key)
            .findFirstSync()!
            .isarId,
        fireImmediately: true,
      );
    }
  }

  /// 添加最近播放的媒体项目
  /// @param mediaItemDB 要添加的媒体项目
  static Future<void> putRecentlyPlayed(MediaItemDB mediaItemDB) async {
    Isar isarDB = await db;
    int? id;
    id = await addMediaItem(mediaItemDB, "recently_played");
    MediaItemDB? _mediaItemDB =
        isarDB.mediaItemDBs.filter().idEqualTo(id).findFirstSync();

    if (_mediaItemDB != null) {
      RecentlyPlayedDB? _recentlyPlayed = isarDB.recentlyPlayedDBs
          .filter()
          .mediaItem((q) => q.idEqualTo(_mediaItemDB.id!))
          .findFirstSync();
      if (_recentlyPlayed != null) {
        isarDB.writeTxnSync(() => isarDB.recentlyPlayedDBs
            .putSync(_recentlyPlayed..lastPlayed = DateTime.now()));
      } else {
        isarDB.writeTxnSync(() => isarDB.recentlyPlayedDBs.putSync(
            RecentlyPlayedDB(lastPlayed: DateTime.now())
              ..mediaItem.value = _mediaItemDB));
      }
    } else {
      log("Failed to add in Recently_Played", name: "DB");
    }
  }

  /// 刷新最近播放列表
  /// 删除超过指定天数的播放记录
  static Future<void> refreshRecentlyPlayed() async {
    Isar isarDB = await db;
    List<int> ids = List.empty(growable: true);

    int days = int.parse((await getSettingStr(GlobalStrConsts.historyClearTime,
        defaultValue: "7"))!);

    List<RecentlyPlayedDB> _recentlyPlayed =
        isarDB.recentlyPlayedDBs.where().findAllSync();
    for (var element in _recentlyPlayed) {
      if (DateTime.now().difference(element.lastPlayed).inDays > days) {
        await element.mediaItem.load();
        if (element.mediaItem.value != null) {
          log("Removing ${element.mediaItem.value!.title}", name: "DB");
          removeMediaItemFromPlaylist(element.mediaItem.value!,
              MediaPlaylistDB(playlistName: "recently_played"));
          ids.add(element.id!);
        } else {
          ids.add(element.id!);
        }
      }
    }
    isarDB.writeTxnSync(() => isarDB.recentlyPlayedDBs.deleteAllSync(ids));
  }

  /// 获取最近播放列表
  /// @param limit 限制返回的数量，0表示不限制
  /// @return 返回最近播放的媒体播放列表
  static Future<MediaPlaylist> getRecentlyPlayed({int limit = 0}) async {
    List<MediaItemModel> mediaItems = [];
    Isar isarDB = await db;
    if (limit == 0) {
      List<RecentlyPlayedDB> recentlyPlayed =
          isarDB.recentlyPlayedDBs.where().sortByLastPlayedDesc().findAllSync();
      for (var element in recentlyPlayed) {
        if (element.mediaItem.value != null) {
          mediaItems.add(MediaItemDB2MediaItem(element.mediaItem.value!));
        }
      }
    } else {
      List<RecentlyPlayedDB> recentlyPlayed = isarDB.recentlyPlayedDBs
          .where()
          .sortByLastPlayedDesc()
          .limit(limit)
          .findAllSync();
      for (var element in recentlyPlayed) {
        if (element.mediaItem.value != null) {
          mediaItems.add(MediaItemDB2MediaItem(element.mediaItem.value!));
        }
      }
    }
    return MediaPlaylist(
        mediaItems: mediaItems, playlistName: "Recently Played");
  }

  /// 获取最近播放列表的观察者流
  /// @return 返回最近播放列表变化的数据流
  static Future<Stream<void>> watchRecentlyPlayed() async {
    Isar isarDB = await db;
    return isarDB.recentlyPlayedDBs.watchLazy();
  }

  /// 保存排行榜数据
  /// @param chartModel 排行榜数据模型
  static Future<void> putChart(ChartModel chartModel) async {
    log("Putting Chart", name: "DB");
    Isar isarDB = await db;
    int? _id;
    isarDB.writeTxnSync(() => _id =
        isarDB.chartsCacheDBs.putSync(chartModelToChartCacheDB(chartModel)));
    log("Chart Putted with ID: $_id", name: "DB");
  }

  /// 获取排行榜数据
  /// @param chartName 排行榜名称
  /// @return 返回排行榜数据模型
  static Future<ChartModel?> getChart(String chartName) async {
    Isar isarDB = await db;
    final chartCacheDB = isarDB.chartsCacheDBs
        .filter()
        .chartNameEqualTo(chartName)
        .findFirstSync();
    if (chartCacheDB != null) {
      return chartCacheDBToChartModel(chartCacheDB);
    } else {
      return null;
    }
  }

  /// 获取排行榜第一项
  /// @param chartName 排行榜名称
  /// @return 返回排行榜第一项数据
  static Future<ChartItemModel?> getFirstFromChart(String chartName) async {
    Isar isarDB = await db;
    final chartCacheDB = isarDB.chartsCacheDBs
        .filter()
        .chartNameEqualTo(chartName)
        .findFirstSync();
    if (chartCacheDB != null) {
      return chartItemDBToChartItemModel(chartCacheDB.chartItems.first);
    } else {
      return null;
    }
  }

  /// 缓存YouTube视频链接
  /// @param id 视频ID
  /// @param lowUrl 低质量视频URL
  /// @param highUrl 高质量视频URL
  /// @param expireAt 过期时间戳
  static Future<void> putYtLinkCache(
      String id, String lowUrl, String highUrl, int expireAt) async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(() => isarDB.ytLinkCacheDBs.putSync(YtLinkCacheDB(
        videoId: id, lowQURL: lowUrl, highQURL: highUrl, expireAt: expireAt)));
  }

  /// 获取YouTube视频链接缓存
  /// @param id 视频ID
  /// @return 返回视频链接缓存数据
  static Future<YtLinkCacheDB?> getYtLinkCache(String id) async {
    Isar isarDB = await db;
    return isarDB.ytLinkCacheDBs.filter().videoIdEqualTo(id).findFirstSync();
  }

  /// 保存API令牌
  /// @param apiName API名称
  /// @param token 令牌值
  /// @param expireIn 过期时间
  static Future<void> putApiTokenDB(
      String apiName, String token, String expireIn) async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(
      () => isarDB.appSettingsStrDBs.putSync(
        AppSettingsStrDB(
          settingName: apiName,
          settingValue: token,
          settingValue2: expireIn,
          lastUpdated: DateTime.now(),
        ),
      ),
    );
  }

  static Future<String?> getApiTokenDB(String apiName) async {
    Isar isarDB = await db;
    final apiToken = isarDB.appSettingsStrDBs
        .filter()
        .settingNameEqualTo(apiName)
        .findFirstSync();
    if (apiToken != null) {
      if ((apiToken.lastUpdated!.difference(DateTime.now()).inSeconds + 30)
                  .abs() <
              int.parse(apiToken.settingValue2!) ||
          apiToken.settingValue2 == "0") {
        return apiToken.settingValue;
      }
    }
    return null;
  }

  static Future<void> putDownloadDB(
      {required String fileName,
      required String filePath,
      required DateTime lastDownloaded,
      required MediaItemModel mediaItem}) async {
    DownloadDB downloadDB = DownloadDB(
      fileName: fileName,
      filePath: filePath,
      lastDownloaded: lastDownloaded,
      mediaId: mediaItem.id,
    );
    Isar isarDB = await db;
    isarDB.writeTxnSync(() => isarDB.downloadDBs.putSync(downloadDB));
    addMediaItem(
        MediaItem2MediaItemDB(mediaItem), GlobalStrConsts.downloadPlaylist);
  }

  static Future<void> removeDownloadDB(MediaItemModel mediaItem) async {
    Isar isarDB = await db;
    DownloadDB? downloadDB = isarDB.downloadDBs
        .filter()
        .mediaIdEqualTo(mediaItem.id)
        .findFirstSync();
    if (downloadDB != null) {
      isarDB.writeTxnSync(() => isarDB.downloadDBs.deleteSync(downloadDB.id!));
      removeMediaItemFromPlaylist(MediaItem2MediaItemDB(mediaItem),
          MediaPlaylistDB(playlistName: GlobalStrConsts.downloadPlaylist));
    }

    try {
      File file = File("${downloadDB!.filePath}/${downloadDB.fileName}");
      if (file.existsSync()) {
        file.deleteSync();
        log("File Deleted: ${downloadDB.fileName}", name: "DB");
      }
    } catch (e) {
      log("Failed to delete file: ${downloadDB!.fileName}",
          error: e, name: "DB");
    }
  }

  static Future<DownloadDB?> getDownloadDB(MediaItemModel mediaItem) async {
    Isar isarDB = await db;
    final temp = isarDB.downloadDBs
        .filter()
        .mediaIdEqualTo(mediaItem.id)
        .findFirstSync();
    if (temp != null &&
        File("${temp.filePath}/${temp.fileName}").existsSync()) {
      return temp;
    }
    return null;
  }

  static Future<void> updateDownloadDB(DownloadDB downloadDB) async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(() => isarDB.downloadDBs.putSync(downloadDB));
  }

  static Future<List<MediaItemModel>> getDownloadedSongs() async {
    Isar isarDB = await db;
    List<DownloadDB> _downloadedSongs =
        isarDB.downloadDBs.where().findAllSync();
    List<MediaItemModel> _mediaItems = List.empty(growable: true);
    for (var element in _downloadedSongs) {
      if (File("${element.filePath}/${element.fileName}").existsSync()) {
        log("File exists", name: "DB");
        _mediaItems.add(MediaItemDB2MediaItem(isarDB.mediaItemDBs
            .filter()
            .mediaIDEqualTo(element.mediaId)
            .findFirstSync()!));
      } else {
        log("File not exists ${element.fileName} ", name: "DB");
        removeDownloadDB(MediaItemDB2MediaItem(isarDB.mediaItemDBs
            .filter()
            .mediaIDEqualTo(element.mediaId)
            .findFirstSync()!));
      }
    }
    return _mediaItems;
  }

  /// 保存通知
  /// @param title 通知标题
  /// @param body 通知内容
  /// @param type 通知类型
  /// @param url 相关链接
  /// @param payload 附加数据
  /// @param unique 是否唯一（同类型通知只保留一个）
  static Future<void> putNotification({
    required String title,
    required String body,
    required String type,
    String? url,
    String? payload,
    bool unique = false,
  }) async {
    Isar isarDB = await db;

    if (unique) {
      final _notification =
          isarDB.notificationDBs.filter().typeEqualTo(type).findFirstSync();
      if (_notification != null) {
        isarDB.writeTxnSync(
            () => isarDB.notificationDBs.deleteSync(_notification.id!));
      }
    }

    isarDB.writeTxnSync(
      () => isarDB.notificationDBs.putSync(
        NotificationDB(
          title: title,
          body: body,
          time: DateTime.now(),
          type: type,
          url: url,
          payload: payload,
        ),
      ),
    );
  }

  /// 获取所有通知
  /// @return 返回按时间倒序排列的通知列表
  static Future<List<NotificationDB>> getNotifications() async {
    Isar isarDB = await db;
    return isarDB.notificationDBs.where().sortByTimeDesc().findAllSync();
  }

  /// 清除所有通知
  static Future<void> clearNotifications() async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(() => isarDB.notificationDBs.where().deleteAllSync());
  }

  /// 获取通知变化的观察者流
  /// @return 返回通知变化的数据流
  static Future<Stream<void>> watchNotification() async {
    Isar isarDB = await db;
    return isarDB.notificationDBs.watchLazy();
  }

  /// 保存在线艺术家信息
  /// @param artistModel 艺术家模型
  static Future<void> putOnlArtistModel(ArtistModel artistModel) async {
    Isar isarDB = await db;
    Map extra = Map.from(artistModel.extra);
    extra["country"] = artistModel.country;

    await isarDB.writeTxn(
      () => isarDB.savedCollectionsDBs.put(
        SavedCollectionsDB(
          type: "artist",
          coverArt: artistModel.imageUrl,
          title: artistModel.name,
          subtitle: artistModel.description,
          source: artistModel.source,
          sourceId: artistModel.sourceId,
          sourceURL: artistModel.sourceURL,
          lastUpdated: DateTime.now(),
          extra: jsonEncode(extra),
        ),
      ),
    );
  }

  /// 保存在线专辑信息
  /// @param albumModel 专辑模型
  static Future<void> putOnlAlbumModel(AlbumModel albumModel) async {
    Isar isarDB = await db;
    Map extra = albumModel.extra;
    extra.addEntries([MapEntry("country", albumModel.country)]);
    extra.addEntries([MapEntry("artists", albumModel.artists)]);
    extra.addEntries([MapEntry("genre", albumModel.genre)]);
    extra.addEntries([MapEntry("language", albumModel.language)]);
    extra.addEntries([MapEntry("year", albumModel.year)]);

    await isarDB.writeTxn(
      () => isarDB.savedCollectionsDBs.put(
        SavedCollectionsDB(
          type: "album",
          coverArt: albumModel.imageURL,
          title: albumModel.name,
          subtitle: albumModel.description,
          source: albumModel.source,
          sourceId: albumModel.sourceId,
          sourceURL: albumModel.sourceURL,
          lastUpdated: DateTime.now(),
          extra: jsonEncode(extra),
        ),
      ),
    );
  }

  /// 保存在线播放列表信息
  /// @param playlistModel 播放列表模型
  static Future<void> putOnlPlaylistModel(
      PlaylistOnlModel playlistModel) async {
    Isar isarDB = await db;
    Map extra = Map.from(playlistModel.extra);
    extra.addEntries([MapEntry("artists", playlistModel.artists)]);
    extra.addEntries([MapEntry("language", playlistModel.language)]);
    extra.addEntries([MapEntry("year", playlistModel.year)]);

    await isarDB.writeTxn(
      () => isarDB.savedCollectionsDBs.put(
        SavedCollectionsDB(
          type: "playlist",
          coverArt: playlistModel.imageURL,
          title: playlistModel.name,
          subtitle: playlistModel.description,
          source: playlistModel.source,
          sourceId: playlistModel.sourceId,
          sourceURL: playlistModel.sourceURL,
          lastUpdated: DateTime.now(),
          extra: jsonEncode(extra),
        ),
      ),
    );
  }

  /// 获取所有已保存的收藏
  /// @return 返回包含艺术家、专辑和播放列表的收藏列表
  static Future<List> getSavedCollections() async {
    Isar isarDB = await db;
    final savedCollections = isarDB.savedCollectionsDBs.where().findAllSync();
    List _savedCollections = [];
    for (var element in savedCollections) {
      switch (element.type) {
        case "artist":
          _savedCollections.add(formatSavedArtistOnl(element));
          break;
        case "album":
          _savedCollections.add(formatSavedAlbumOnl(element));
          break;
        case "playlist":
          _savedCollections.add(formatSavedPlaylistOnl(element));
          break;
        default:
          break;
      }
    }
    return _savedCollections;
  }

  /// 从收藏中移除项目
  /// @param sourceID 源ID
  static Future<void> removeFromSavedCollecs(String sourceID) async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(
      () => isarDB.savedCollectionsDBs
          .filter()
          .sourceIdEqualTo(sourceID)
          .deleteAllSync(),
    );
  }

  /// 检查项目是否在收藏中
  /// @param sourceID 源ID
  /// @return 如果项目已收藏返回true，否则返回false
  static Future<bool> isInSavedCollections(String sourceID) async {
    bool value = false;
    Isar isarDB = await db;
    final item = isarDB.savedCollectionsDBs
        .filter()
        .sourceIdEqualTo(sourceID)
        .findFirstSync();
    if (item != null) {
      value = true;
    }
    return value;
  }

  /// 获取收藏变化的观察者流
  /// @return 返回收藏变化的数据流
  static Future<Stream<void>> getSavedCollecsWatcher() async {
    Isar isarDB = await db;
    return isarDB.savedCollectionsDBs.watchLazy(fireImmediately: true);
  }

  /// 保存歌词
  /// @param lyrics 歌词对象
  /// @param offset 时间偏移量（毫秒）
  static Future<void> putLyrics(Lyrics lyrics, {int? offset}) async {
    if (lyrics.mediaID != null) {
      Isar isarDB = await db;
      isarDB.writeTxnSync(() => isarDB.lyricsDBs.putSync(LyricsDB(
            mediaID: lyrics.mediaID!,
            sourceId: lyrics.id,
            plainLyrics: lyrics.lyricsPlain,
            syncedLyrics: lyrics.lyricsSynced,
            title: lyrics.title,
            source: "lrcnet",
            artist: lyrics.artist,
            album: lyrics.album,
            duration: double.parse(lyrics.duration ?? "0").toInt(),
            offset: offset,
            url: lyrics.url,
          )));
    }
  }

  /// 获取歌词
  /// @param mediaID 媒体ID
  /// @return 返回歌词对象，如果不存在则返回null
  static Future<Lyrics?> getLyrics(String mediaID) async {
    Isar isarDB = await db;
    LyricsDB? lyricsDB =
        isarDB.lyricsDBs.filter().mediaIDEqualTo(mediaID).findFirstSync();
    if (lyricsDB != null) {
      return Lyrics(
        id: lyricsDB.sourceId,
        title: lyricsDB.title,
        artist: lyricsDB.artist,
        album: lyricsDB.album,
        duration: lyricsDB.duration.toString(),
        lyricsPlain: lyricsDB.plainLyrics,
        lyricsSynced: lyricsDB.syncedLyrics,
        provider: LyricsProvider.lrcnet,
        url: lyricsDB.url,
        mediaID: lyricsDB.mediaID,
      );
    }
    return null;
  }

  /// 删除歌词
  /// @param mediaID 媒体ID
  static Future<void> removeLyricsById(String mediaID) async {
    Isar isarDB = await db;
    isarDB.writeTxnSync(() =>
        isarDB.lyricsDBs.filter().mediaIDEqualTo(mediaID).deleteAllSync());
  }
}

/// 将保存的艺术家收藏数据转换为艺术家模型
/// @param savedCollectionsDB 保存的收藏数据库对象
/// @return 返回转换后的艺术家模型对象
ArtistModel formatSavedArtistOnl(SavedCollectionsDB savedCollectionsDB) {
  Map extra = jsonDecode(savedCollectionsDB.extra ?? "{}");
  return ArtistModel(
    name: savedCollectionsDB.title,
    description: savedCollectionsDB.subtitle,
    imageUrl: savedCollectionsDB.coverArt,
    source: savedCollectionsDB.source,
    sourceId: savedCollectionsDB.sourceId,
    sourceURL: savedCollectionsDB.sourceURL,
    country: extra["country"],
  );
}

/// 将保存的专辑收藏数据转换为专辑模型对象
/// @param savedCollectionsDB 保存的收藏数据库对象
/// @return 返回转换后的专辑模型对象，包含专辑的完整信息（艺术家、流派、年份等）
AlbumModel formatSavedAlbumOnl(SavedCollectionsDB savedCollectionsDB) {
  Map extra = jsonDecode(savedCollectionsDB.extra ?? "{}");
  return AlbumModel(
    name: savedCollectionsDB.title,
    description: savedCollectionsDB.subtitle,
    imageURL: savedCollectionsDB.coverArt,
    source: savedCollectionsDB.source,
    sourceId: savedCollectionsDB.sourceId,
    sourceURL: savedCollectionsDB.sourceURL,
    country: extra["country"],
    artists: extra["artists"],
    genre: extra["genre"],
    year: extra["year"],
    extra: extra,
    language: extra["language"],
  );
}

/// 将保存的播放列表收藏数据转换为播放列表模型对象
/// @param savedCollectionsDB 保存的收藏数据库对象
/// @return 返回转换后的播放列表模型对象，包含播放列表的基本信息和额外数据
PlaylistOnlModel formatSavedPlaylistOnl(SavedCollectionsDB savedCollectionsDB) {
  Map extra = jsonDecode(savedCollectionsDB.extra ?? "{}");
  return PlaylistOnlModel(
    name: savedCollectionsDB.title,
    description: savedCollectionsDB.subtitle,
    imageURL: savedCollectionsDB.coverArt,
    source: savedCollectionsDB.source,
    sourceId: savedCollectionsDB.sourceId,
    sourceURL: savedCollectionsDB.sourceURL,
    artists: extra["artists"],
    language: extra["language"],
    year: extra["year"],
    extra: extra,
  );
}
