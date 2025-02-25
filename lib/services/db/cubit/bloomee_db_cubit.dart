/// BloomeeDBCubit类负责管理应用程序的数据库操作
/// 包括播放列表管理、媒体项目管理、设置管理等功能
/// 使用Bloc模式实现状态管理

import 'dart:developer';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:audio_service/audio_service.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:Bloomee/model/MediaPlaylistModel.dart';
import 'package:Bloomee/model/songModel.dart';
import 'package:Bloomee/services/db/GlobalDB.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';

part 'bloomee_db_state.dart';

/// 数据库操作Cubit类
/// 负责管理应用程序的数据库状态和操作
class BloomeeDBCubit extends Cubit<MediadbState> {
  BloomeeDBService bloomeeDBService = BloomeeDBService();
  
  /// 构造函数
  /// 初始化时创建"Liked"播放列表
  BloomeeDBCubit() : super(MediadbInitial()) {
    addNewPlaylistToDB(MediaPlaylistDB(playlistName: "Liked"));
  }

  /// 向数据库添加新的播放列表
  /// @param mediaPlaylistDB 要添加的播放列表
  /// @param undo 是否为撤销操作
  Future<void> addNewPlaylistToDB(MediaPlaylistDB mediaPlaylistDB,
      {bool undo = false}) async {
    List<String> _list = await getListOfPlaylists();
    if (!_list.contains(mediaPlaylistDB.playlistName)) {
      BloomeeDBService.addPlaylist(mediaPlaylistDB);
      // refreshLibrary.add(true);
      if (!undo) {
        SnackbarService.showMessage(
            "Playlist ${mediaPlaylistDB.playlistName} added");
      }
    }
  }

  /// 设置媒体项目的收藏状态
  /// @param mediaItem 要设置的媒体项目
  /// @param isLiked 是否收藏
  Future<void> setLike(MediaItem mediaItem, {isLiked = false}) async {
    BloomeeDBService.addMediaItem(MediaItem2MediaItemDB(mediaItem), "Liked");
    // refreshLibrary.add(true);
    BloomeeDBService.likeMediaItem(MediaItem2MediaItemDB(mediaItem),
        isLiked: isLiked);
    if (isLiked) {
      SnackbarService.showMessage("${mediaItem.title} is Liked!!");
    } else {
      SnackbarService.showMessage("${mediaItem.title} is Unliked!!");
    }
  }

  /// 检查媒体项目是否已收藏
  /// @param mediaItem 要检查的媒体项目
  /// @return 返回是否已收藏
  Future<bool> isLiked(MediaItem mediaItem) {
    // bool res = true;
    return BloomeeDBService.isMediaLiked(MediaItem2MediaItemDB(mediaItem));
  }

  /// 根据排序索引重新排序媒体项目列表
  /// @param orgMediaList 原始媒体列表
  /// @param rankIndex 排序索引
  /// @return 返回重新排序后的列表
  List<MediaItemDB> reorderByRank(
      List<MediaItemDB> orgMediaList, List<int> rankIndex) {
    // rankIndex = rankIndex.toSet().toList();
    // orgMediaList.toSet().toList();
    List<MediaItemDB> reorderedList = orgMediaList;
    // orgMediaList.forEach((element) {
    //   log('orgMEdia - ${element.id} - ${element.title}',
    //       name: "BloomeeDBCubit");
    // });
    log(rankIndex.toString(), name: "BloomeeDBCubit");
    if (rankIndex.length == orgMediaList.length) {
      reorderedList = rankIndex
          .map((e) => orgMediaList.firstWhere(
                (element) => e == element.id,
              ))
          .map((e) => e)
          .toList();
      log('ranklist length - ${rankIndex.length} org length - ${orgMediaList.length}',
          name: "BloomeeDBCubit");
      return reorderedList;
    } else {
      return orgMediaList;
    }
  }

  /// 获取播放列表中的所有媒体项目
  /// @param mediaPlaylistDB 要获取的播放列表
  /// @return 返回包含所有媒体项目的播放列表
  Future<MediaPlaylist> getPlaylistItems(
      MediaPlaylistDB mediaPlaylistDB) async {
    MediaPlaylist _mediaPlaylist = MediaPlaylist(
        mediaItems: [], playlistName: mediaPlaylistDB.playlistName);

    var _dbList = await BloomeeDBService.getPlaylistItems(mediaPlaylistDB);
    final playlist =
        await BloomeeDBService.getPlaylist(mediaPlaylistDB.playlistName);
    final info =
        await BloomeeDBService.getPlaylistInfo(mediaPlaylistDB.playlistName);
    if (playlist != null) {
      _mediaPlaylist =
          fromPlaylistDB2MediaPlaylist(mediaPlaylistDB, playlistsInfoDB: info);

      if (_dbList != null) {
        List<int> _rankList =
            await BloomeeDBService.getPlaylistItemsRank(mediaPlaylistDB);

        if (_rankList.isNotEmpty) {
          _dbList = reorderByRank(_dbList, _rankList);
        }
        _mediaPlaylist.mediaItems.clear();

        for (var element in _dbList) {
          _mediaPlaylist.mediaItems.add(MediaItemDB2MediaItem(element));
        }
      }
    }
    return _mediaPlaylist;
  }

  /// 设置播放列表中媒体项目的排序
  /// @param mediaPlaylistDB 要设置的播放列表
  /// @param rankList 排序列表
  Future<void> setPlayListItemsRank(
      MediaPlaylistDB mediaPlaylistDB, List<int> rankList) async {
    BloomeeDBService.setPlaylistItemsRank(mediaPlaylistDB, rankList);
  }

  /// 获取播放列表的数据流
  /// @param mediaPlaylistDB 要获取的播放列表
  /// @return 返回播放列表的数据流
  Future<Stream> getStreamOfPlaylist(MediaPlaylistDB mediaPlaylistDB) async {
    return await BloomeeDBService.getStream4MediaList(mediaPlaylistDB);
  }

  /// 获取所有播放列表的名称列表
  /// @return 返回播放列表名称列表
  Future<List<String>> getListOfPlaylists() async {
    List<String> mediaPlaylists = [];
    final _albumList = await BloomeeDBService.getPlaylists4Library();
    if (_albumList.isNotEmpty) {
      _albumList.toList().forEach((element) {
        mediaPlaylists.add(element.playlistName);
      });
    }
    return mediaPlaylists;
  }

  /// 获取所有播放列表对象的列表
  /// @return 返回播放列表对象列表
  Future<List<MediaPlaylist>> getListOfPlaylists2() async {
    List<MediaPlaylist> mediaPlaylists = [];
    final _albumList = await BloomeeDBService.getPlaylists4Library();
    if (_albumList.isNotEmpty) {
      _albumList.toList().forEach((element) {
        mediaPlaylists.add(element);
      });
    }
    return mediaPlaylists;
  }

  /// 在数据库中重新排序播放列表中的项目
  /// @param playlistName 播放列表名称
  /// @param old_idx 原始位置
  /// @param new_idx 新位置
  Future<void> reorderPositionOfItemInDB(
      String playlistName, int old_idx, int new_idx) async {
    BloomeeDBService.reorderItemPositionInPlaylist(
        MediaPlaylistDB(playlistName: playlistName), old_idx, new_idx);
  }

  /// 从数据库中删除播放列表
  /// @param mediaPlaylistDB 要删除的播放列表
  Future<void> removePlaylist(MediaPlaylistDB mediaPlaylistDB) async {
    BloomeeDBService.removePlaylist(mediaPlaylistDB);
    SnackbarService.showMessage("${mediaPlaylistDB.playlistName} is Deleted!!",
        duration: const Duration(seconds: 3),
        action: SnackBarAction(
          label: "Undo",
          textColor: Default_Theme.accentColor2,
          onPressed: () => addNewPlaylistToDB(mediaPlaylistDB, undo: true),
        ));
  }

  /// 从播放列表中移除媒体项目
  /// @param mediaItem 要移除的媒体项目
  /// @param mediaPlaylistDB 所在的播放列表
  Future<void> removeMediaFromPlaylist(
      MediaItem mediaItem, MediaPlaylistDB mediaPlaylistDB) async {
    MediaItemDB _mediaItemDB = MediaItem2MediaItemDB(mediaItem);
    BloomeeDBService.removeMediaItemFromPlaylist(_mediaItemDB, mediaPlaylistDB)
        .then((value) {
      SnackbarService.showMessage(
          "${mediaItem.title} is removed from ${mediaPlaylistDB.playlistName}!!",
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
              label: "Undo",
              textColor: Default_Theme.accentColor2,
              onPressed: () => addMediaItemToPlaylist(
                  MediaItemDB2MediaItem(_mediaItemDB), mediaPlaylistDB,
                  undo: true)));
    });
  }

  /// 向播放列表添加媒体项目
  /// @param mediaItemModel 要添加的媒体项目
  /// @param mediaPlaylistDB 目标播放列表
  /// @param undo 是否为撤销操作
  /// @return 返回添加的项目ID
  Future<int?> addMediaItemToPlaylist(
      MediaItemModel mediaItemModel, MediaPlaylistDB mediaPlaylistDB,
      {bool undo = false}) async {
    final _id = await BloomeeDBService.addMediaItem(
        MediaItem2MediaItemDB(mediaItemModel), mediaPlaylistDB.playlistName);
    // refreshLibrary.add(true);
    if (!undo) {
      SnackbarService.showMessage(
          "${mediaItemModel.title} is added to ${mediaPlaylistDB.playlistName}!!");
    }
    return _id;
  }

  /// 获取布尔类型的设置值
  /// @param key 设置项的键
  /// @return 返回设置的布尔值
  Future<bool?> getSettingBool(String key) async {
    return await BloomeeDBService.getSettingBool(key);
  }

  /// 保存布尔类型的设置值
  /// @param key 设置项的键
  /// @param value 要保存的布尔值
  Future<void> putSettingBool(String key, bool value) async {
    if (key.isNotEmpty) {
      BloomeeDBService.putSettingBool(key, value);
    }
  }

  /// 获取字符串类型的设置值
  /// @param key 设置项的键
  /// @return 返回设置的字符串值
  Future<String?> getSettingStr(String key) async {
    return await BloomeeDBService.getSettingStr(key);
  }

  /// 保存字符串类型的设置值
  /// @param key 设置项的键
  /// @param value 要保存的字符串值
  Future<void> putSettingStr(String key, String value) async {
    if (key.isNotEmpty && value.isNotEmpty) {
      BloomeeDBService.putSettingStr(key, value);
    }
  }

  /// 获取字符串设置的观察者流
  /// @param key 设置项的键
  /// @return 返回设置变化的数据流
  Future<Stream<AppSettingsStrDB?>?> getWatcher4SettingStr(String key) async {
    if (key.isNotEmpty) {
      return await BloomeeDBService.getWatcher4SettingStr(key);
    } else {
      return null;
    }
  }

  /// 获取布尔设置的观察者流
  /// @param key 设置项的键
  /// @return 返回设置变化的数据流
  Future<Stream<AppSettingsBoolDB?>?> getWatcher4SettingBool(String key) async {
    if (key.isNotEmpty) {
      var _watcher = await BloomeeDBService.getWatcher4SettingBool(key);
      if (_watcher != null) {
        return _watcher;
      } else {
        BloomeeDBService.putSettingBool(key, false);
        return BloomeeDBService.getWatcher4SettingBool(key);
      }
    } else {
      return null;
    }
  }

  @override
  Future<void> close() async {
    // refreshLibrary.close();
    super.close();
  }
}
