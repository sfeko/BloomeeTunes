import 'dart:convert';
import 'dart:developer';
import 'dart:io';
// import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/services/db/GlobalDB.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:path_provider/path_provider.dart';

/// BloomeeFileManager类
/// 负责处理应用程序的文件操作，包括播放列表和媒体文件的导入导出
class BloomeeFileManager {
  /// 检查播放列表是否存在
  /// @param playlistName 播放列表名称
  /// @return 如果播放列表存在返回true，否则返回false
  static Future<bool> isPlaylistExists(String playlistName) async {
    final _list = await BloomeeDBService.getPlaylists4Library();
    for (final playlist in _list) {
      if (playlist.playlistName == playlistName) {
        return true;
      }
    }
    return false;
  }

  /// 导出播放列表到JSON文件
  /// @param playlistName 要导出的播放列表名称
  /// @return 导出文件的路径，如果导出失败返回null
  static Future<String?> exportPlaylist(String playlistName) async {
    final mediaPlaylistDB = await BloomeeDBService.getPlaylist(playlistName);
    if (mediaPlaylistDB != null) {
      try {
        List<MediaItemDB>? playlistItems =
            await BloomeeDBService.getPlaylistItems(mediaPlaylistDB);
        if (playlistItems != null) {
          final Map<String, dynamic> playlistMap = {
            'playlistName': mediaPlaylistDB.playlistName,
            'mediaRanks': mediaPlaylistDB.mediaRanks,
            'mediaItems': playlistItems.map((e) => e.toMap()).toList(),
          };
          final path = await writeToJSON(
              '${mediaPlaylistDB.playlistName}_BloomeePlaylist.blm',
              playlistMap);
          log("Playlist exported successfully", name: "FileManager");
          return path;
        }
      } catch (e) {
        log("Error exporting playlist: $e");
        return null;
      }
    } else {
      log("Playlist not found", name: "FileManager");
    }
    return null;
  }

  /// 导出单个媒体项到JSON文件
  /// @param mediaItemDB 要导出的媒体项
  /// @return 导出文件的路径，如果导出失败返回null
  static Future<String?> exportMediaItem(MediaItemDB mediaItemDB) async {
    try {
      final Map<String, dynamic> mediaItemMap = mediaItemDB.toMap();
      final path = await writeToJSON(
          '${mediaItemDB.title}_BloomeeSong.blm', mediaItemMap);
      log("Media item exported successfully", name: "FileManager");
      return path;
    } catch (e) {
      log("Error exporting media item: $e", name: "FileManager");
      return null;
    }
  }

  /// 从JSON文件导入播放列表
  /// @param filePath 要导入的文件路径
  /// @return 导入是否成功
  static Future<bool> importPlaylist(String filePath) async {
    try {
      await readFromJSON(filePath).then((playlistMap) async {
        log("Playlist map: $playlistMap", name: "FileManager");
        if (playlistMap != null && playlistMap.isNotEmpty) {
          bool playlistExists =
              await isPlaylistExists(playlistMap['playlistName']);
          int i = 1;
          String playlistName = playlistMap['playlistName'];
          // 如果播放列表已存在，添加数字后缀
          while (playlistExists) {
            playlistName = playlistMap['playlistName'] + "_$i";
            playlistExists = await isPlaylistExists(playlistName);
            i++;
          }
          log("Playlist name: $playlistName", name: "FileManager");

          // 导入播放列表中的所有媒体项
          for (final mediaItemMap in playlistMap['mediaItems']) {
            final mediaItemDB = MediaItemDB.fromMap(mediaItemMap);
            await BloomeeDBService.addMediaItem(mediaItemDB, playlistName);
            log("Media item imported successfully - ${mediaItemDB.title}",
                name: "FileManager");
          }

          log("Playlist imported successfully");
        }
      });
      return true;
    } catch (e) {
      log("Invalid file format");
      return false;
    }
  }

  /// 从JSON文件导入单个媒体项
  /// @param filePath 要导入的文件路径
  /// @return 导入是否成功
  static Future<bool> importMediaItem(String filePath) async {
    try {
      await readFromJSON(filePath).then((mediaItemMap) {
        if (mediaItemMap != null && mediaItemMap.isNotEmpty) {
          final mediaItemDB = MediaItemDB.fromMap(mediaItemMap);
          BloomeeDBService.addMediaItem(mediaItemDB, "Imported");
          log("Media item imported successfully");
        }
      });
      return true;
    } catch (e) {
      log("Invalid file format");
    }
    return false;
  }

  /// 将数据写入JSON文件
  /// @param fileName 文件名
  /// @param data 要写入的数据
  /// @return 写入文件的完整路径，如果写入失败返回null
  static Future<String?> writeToJSON(
      String fileName, Map<String, dynamic> data) async {
    try {
      final filePath = (await getApplicationCacheDirectory()).path;
      final file = File('$filePath/$fileName');
      await file.writeAsString(jsonEncode(data));
      log("Data written to file: $filePath/$fileName", name: "FileManager");
      return '$filePath/$fileName';
    } catch (e) {
      log("Error writing file:", error: e, name: "FileManager");
      return null;
    }
  }

  /// 从JSON文件读取数据
  /// @param filePath 要读取的文件路径
  /// @return 读取的数据，如果读取失败返回null
  static Future<Map<String, dynamic>?> readFromJSON(String filePath) async {
    try {
      final file = File(filePath);
      final data = await file.readAsString();
      log("Data read from file: $filePath", name: "FileManager");
      return jsonDecode(data);
    } catch (e) {
      log("Error reading file:", error: e);
      return null;
    }
  }
}
