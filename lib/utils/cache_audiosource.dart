// Not used right now but can be in future for caching audio files
import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// 获取缓存目录
/// 返回专门用于存储音频缓存的临时目录
/// @return 返回音频缓存的专用目录
Future<Directory> _getCacheDir() async =>
    Directory(p.join((await getTemporaryDirectory()).path, 'just_audio_cache'));

/// 创建带锁定缓存的音频源
/// 根据提供的URI和可选参数创建一个带缓存功能的音频源
/// @param uri 音频文件的URI
/// @param fileName 可选的文件名，用于生成缓存文件名
/// @param headers 可选的HTTP头信息，用于网络请求
/// @param tag 可选的标签信息，用于音频源标识
/// @return 返回配置好的LockCachingAudioSource实例
Future<LockCachingAudioSource> getLockCachingAudioSource(
  Uri uri, {
  String? fileName,
  Map<String, String>? headers,
  dynamic tag,
}) async {
  log("path: ${(await _getCacheDir()).path}  file: $fileName");
  return LockCachingAudioSource(
    uri,
    headers: headers,
    tag: tag,
    cacheFile: fileName != null
        ? File(p.joinAll([
            (await _getCacheDir()).path,
            'remote',
            sha256.convert(utf8.encode(fileName)).toString() +
                p.extension('.m4a'),
          ]))
        : null,
  );
}
