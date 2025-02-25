import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// YouTube音频源类，继承自StreamAudioSource
/// 用于处理YouTube视频的音频流，支持高低质量的音频选择和流数据处理
class YouTubeAudioSource extends StreamAudioSource {
  /// YouTube视频ID
  final String videoId;
  
  /// 音频质量选择，可选值：'high'或'low'
  /// - 'high': 选择最高比特率的音频流
  /// - 'low': 选择最低比特率的音频流
  final String quality;
  
  /// YouTube数据获取客户端实例
  final YoutubeExplode ytExplode;
  
  /// 构造函数
  /// @param videoId - YouTube视频ID
  /// @param quality - 音频质量选择
  /// @param tag - 可选的标签参数
  YouTubeAudioSource({
    required this.videoId,
    required this.quality,
    super.tag,
  }) : ytExplode = YoutubeExplode();
  
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      // 获取视频的流媒体清单
      final manifest = await ytExplode.videos.streams.getManifest(
        videoId,
        requireWatchPage: false,
        ytClients: [YoutubeApiClient.android],
      );
      // 获取所有音频流并按比特率排序
      final supportedStreams = manifest.audioOnly.sortByBitrate();
  
      // 根据quality参数选择合适的音频流
      // high: 选择最高比特率的音频流
      // low: 选择最低比特率的音频流
      final audioStream = quality == 'high'
          ? (supportedStreams.isNotEmpty ? supportedStreams.last : null)
          : (supportedStreams.isNotEmpty ? supportedStreams.first : null);
  
      if (audioStream == null) {
        throw Exception('No audio stream available for this video.');
      }
  
      // 处理起始位置和结束位置
      start ??= 0;
      // 计算结束位置：
      // 1. 如果流被限制，则限制为从起始位置开始的10379935字节
      // 2. 否则使用完整的音频流大小
      int computedEnd = end ??
          (audioStream.isThrottled
              ? (start + 10379935)
              : audioStream.size.totalBytes);
      if (computedEnd > audioStream.size.totalBytes) {
        computedEnd = audioStream.size.totalBytes;
      }
  
      // 获取完整的音频流
      final fullStream = ytExplode.videos.streams.get(audioStream);
  
      // 注：以下代码为流转换器的实现，目前已注释
      // 转换流：跳过开始部分的字节，并且只获取指定范围的字节
      // final adjustedStream = fullStream
      //     .transform(SkipBytesTransformer(start))
      //     .transform(TakeBytesTransformer(computedEnd - start));
  
      // 返回音频流响应
      return StreamAudioResponse(
        sourceLength: audioStream.size.totalBytes,  // 源音频总长度
        contentLength: computedEnd - start,        // 实际内容长度
        offset: start,                            // 起始偏移量
        stream: fullStream,                       // 音频流
        contentType: audioStream.codec.mimeType,   // 内容类型
      );
    } catch (e) {
      throw Exception('Failed to load audio: $e');
    }
  }
}
  
/// 字节跳过转换器
/// 用于跳过流中指定数量的字节
class SkipBytesTransformer extends StreamTransformerBase<List<int>, List<int>> {
  /// 需要跳过的字节数
  final int bytesToSkip;
  
  /// 构造函数
  /// @param bytesToSkip - 要跳过的字节数
  SkipBytesTransformer(this.bytesToSkip);
  
  @override
  Stream<List<int>> bind(Stream<List<int>> stream) async* {
    int remaining = bytesToSkip;
    await for (final chunk in stream) {
      if (remaining > 0) {
        if (chunk.length <= remaining) {
          // 如果当前数据块小于或等于剩余需要跳过的字节数
          // 则跳过整个数据块
          remaining -= chunk.length;
          continue;
        } else {
          // 如果当前数据块大于剩余需要跳过的字节数
          // 则只输出剩余部分
          yield chunk.sublist(remaining);
          remaining = 0;
        }
      } else {
        // 已经跳过了足够的字节，直接输出后续数据
        yield chunk;
      }
    }
  }
}
  
/// 字节获取转换器
/// 用于从流中只获取指定数量的字节
class TakeBytesTransformer extends StreamTransformerBase<List<int>, List<int>> {
  /// 需要获取的字节数
  final int bytesToTake;
  
  /// 构造函数
  /// @param bytesToTake - 要获取的字节数
  TakeBytesTransformer(this.bytesToTake);
  
  @override
  Stream<List<int>> bind(Stream<List<int>> stream) async* {
    int remaining = bytesToTake;
    await for (final chunk in stream) {
      if (remaining <= 0) break;  // 已获取足够的字节，停止处理
      if (chunk.length <= remaining) {
        // 如果当前数据块小于或等于剩余需要获取的字节数
        // 则输出整个数据块
        yield chunk;
        remaining -= chunk.length;
      } else {
        // 如果当前数据块大于剩余需要获取的字节数
        // 则只输出需要的部分
        yield chunk.sublist(0, remaining);
        remaining = 0;
        break;
      }
    }
  }
}
