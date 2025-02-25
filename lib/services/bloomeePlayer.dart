import 'dart:developer';
import 'dart:io';
import 'package:Bloomee/model/saavnModel.dart';
import 'package:Bloomee/model/yt_music_model.dart';
import 'package:Bloomee/repository/Saavn/saavn_api.dart';
import 'package:Bloomee/repository/Youtube/yt_music_api.dart';
import 'package:Bloomee/routes_and_consts/global_conts.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:Bloomee/utils/ytstream_source.dart';
import 'package:audio_service/audio_service.dart';
import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:Bloomee/model/songModel.dart';
import '../model/MediaPlaylistModel.dart';

/// 生成随机索引列表
/// 用于实现随机播放功能
/// @param length 需要生成的索引列表长度
/// @return 打乱顺序的索引列表
List<int> generateRandomIndices(int length) {
  List<int> indices = List<int>.generate(length, (i) => i);
  indices.shuffle();
  return indices;
}

/// BloomeePlayer核心播放器类
/// 实现了音频播放、播放列表管理、播放模式控制等功能
class BloomeeMusicPlayer extends BaseAudioHandler
    with SeekHandler, QueueHandler {
  /// 底层音频播放器实例
  late AudioPlayer audioPlayer;
  
  /// 播放状态相关的BehaviorSubject
  BehaviorSubject<bool> fromPlaylist = BehaviorSubject<bool>.seeded(false);
  BehaviorSubject<bool> isOffline = BehaviorSubject<bool>.seeded(false);
  BehaviorSubject<bool> shuffleMode = BehaviorSubject<bool>.seeded(false);

  /// 相关歌曲列表
  BehaviorSubject<List<MediaItem>> relatedSongs =
      BehaviorSubject<List<MediaItem>>.seeded([]);
  
  /// 循环播放模式
  BehaviorSubject<LoopMode> loopMode =
      BehaviorSubject<LoopMode>.seeded(LoopMode.off);

  /// 播放位置相关变量
  int currentPlayingIdx = 0;
  int shuffleIdx = 0;
  List<int> shuffleList = [];
  
  /// 播放列表音频源
  final _playlist = ConcatenatingAudioSource(children: []);

  /// 暂停状态标记
  bool isPaused = false;

  /// 构造函数
  /// 初始化播放器并设置相关监听器
  BloomeeMusicPlayer() {
    audioPlayer = AudioPlayer(
      handleInterruptions: true,
    );
    audioPlayer.setVolume(1);
    audioPlayer.playbackEventStream.listen(_broadcastPlayerEvent);
    audioPlayer.setLoopMode(LoopMode.off);
    audioPlayer.setAudioSource(_playlist, preload: false);

    // 监听播放序列变化，更新当前媒体项
    Rx.combineLatest2(
      audioPlayer.sequenceStream,
      audioPlayer.currentIndexStream,
      (sequence, index) {
        if (sequence == null || sequence.isEmpty) return null;
        return sequence[index ?? 0].tag as MediaItem;
      },
    ).whereType<MediaItem>().listen(mediaItem.add);

    // 监听播放位置，处理歌曲结束逻辑
    final endingOffset =
        Platform.isWindows ? 200 : (Platform.isLinux ? 700 : 0);
    audioPlayer.positionStream.listen((event) {
      if (audioPlayer.duration != null &&
          audioPlayer.duration?.inSeconds != 0 &&
          event.inMilliseconds >
              audioPlayer.duration!.inMilliseconds - endingOffset &&
          loopMode.value != LoopMode.one) {
        EasyThrottle.throttle('skipNext', const Duration(milliseconds: 2000),
            () async => await skipToNext());
      }
    });

    // 队列变化时刷新随机播放列表
    queue.listen((e) {
      shuffleList = generateRandomIndices(e.length);
    });
  }

  /// 广播播放器事件
  /// 更新播放状态和控制按钮
  void _broadcastPlayerEvent(PlaybackEvent event) {
    bool isPlaying = audioPlayer.playing;
    playbackState.add(PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        isPlaying ? MediaControl.pause : MediaControl.play,
        MediaControl.skipToNext,
      ],
      processingState: switch (event.processingState) {
        ProcessingState.idle => AudioProcessingState.idle,
        ProcessingState.loading => AudioProcessingState.loading,
        ProcessingState.buffering => AudioProcessingState.buffering,
        ProcessingState.ready => AudioProcessingState.ready,
        ProcessingState.completed => AudioProcessingState.completed,
      },
      // Which other actions should be enabled in the notification
      systemActions: const {
        MediaAction.skipToPrevious,
        MediaAction.playPause,
        MediaAction.skipToNext,
        MediaAction.seek,
      },
      androidCompactActionIndices: const [0, 1, 2],
      updatePosition: audioPlayer.position,
      playing: isPlaying,
      bufferedPosition: audioPlayer.bufferedPosition,
      speed: audioPlayer.speed,
      // playing: audioPlayer.playerState.playing,
    ));
  }
  /// 获取当前播放的媒体项
  /// 如果播放队列为空，返回空的媒体项模型
  MediaItemModel get currentMedia => queue.value.isNotEmpty
      ? mediaItem2MediaItemModel(queue.value[currentPlayingIdx])
      : mediaItemModelNull;

  @override
  /// 开始播放
  /// 调用底层播放器的播放方法，并更新暂停状态标记
  Future<void> play() async {
    await audioPlayer.play();
    isPaused = false;
  }

  /// 检查并加载相关歌曲
  /// 当播放队列即将播放完毕且不处于循环播放模式时，获取相关歌曲推荐
  Future<void> check4RelatedSongs() async {
    log("Checking for related songs: ${queue.value.isNotEmpty && (queue.value.length - currentPlayingIdx) < 2}",
        name: "bloomeePlayer");
    if (queue.value.isNotEmpty &&
        (queue.value.length - currentPlayingIdx) < 2 &&
        loopMode.value != LoopMode.all) {
      if (currentMedia.extras?["source"] == "saavn") {
        final songs = await compute(SaavnAPI().getRelated, currentMedia.id);
        if (songs['total'] > 0) {
          final List<MediaItem> temp =
              fromSaavnSongMapList2MediaItemList(songs['songs']);
          relatedSongs.add(temp.sublist(1));
          log("Related Songs: ${songs['total']}");
        }
      } else if (currentMedia.extras?["source"].contains("youtube") ?? false) {
        final songs = await compute(YtMusicService().getRelated,
            currentMedia.id.replaceAll('youtube', ''));
        if (songs['total'] > 0) {
          final List<MediaItem> temp =
              fromYtSongMapList2MediaItemList(songs['songs']);
          relatedSongs.add(temp.sublist(1));
          log("Related Songs: ${songs['total']}");
        }
      }
    }
    loadRelatedSongs();
  }

  /// 加载相关歌曲到播放队列
  /// 当相关歌曲列表不为空且当前播放位置接近队列末尾时，将相关歌曲添加到队列末尾
  Future<void> loadRelatedSongs() async {
    if (relatedSongs.value.isNotEmpty &&
        (queue.value.length - currentPlayingIdx) < 3 &&
        loopMode.value != LoopMode.all) {
      await addQueueItems(relatedSongs.value, atLast: true);
      fromPlaylist.add(false);
      relatedSongs.add([]);
    }
  }

  @override
  /// 跳转到指定播放位置
  /// @param position 目标播放位置
  Future<void> seek(Duration position) async {
    audioPlayer.seek(position);
  }

  /// 向前跳转指定时长
  /// @param n 跳转时长
  Future<void> seekNSecForward(Duration n) async {
    if ((audioPlayer.duration ?? const Duration(seconds: 0)) >=
        audioPlayer.position + n) {
      await audioPlayer.seek(audioPlayer.position + n);
    } else {
      await audioPlayer
          .seek(audioPlayer.duration ?? const Duration(seconds: 0));
    }
  }

  /// 向后跳转指定时长
  /// @param n 跳转时长
  Future<void> seekNSecBackward(Duration n) async {
    if (audioPlayer.position - n >= const Duration(seconds: 0)) {
      await audioPlayer.seek(audioPlayer.position - n);
    } else {
      await audioPlayer.seek(const Duration(seconds: 0));
    }
  }

  /// 设置循环播放模式
  /// @param loopMode 循环模式（单曲循环或关闭循环）
  void setLoopMode(LoopMode loopMode) {
    if (loopMode == LoopMode.one) {
      audioPlayer.setLoopMode(LoopMode.one);
    } else {
      audioPlayer.setLoopMode(LoopMode.off);
    }
    this.loopMode.add(loopMode);
  }

  /// 设置随机播放模式
  /// @param shuffle 是否开启随机播放
  Future<void> shuffle(bool shuffle) async {
    shuffleMode.add(shuffle);
    if (shuffle) {
      shuffleIdx = 0;
      shuffleList = generateRandomIndices(queue.value.length);
    }
  }

  /// 加载播放列表
  /// @param mediaList 要加载的播放列表
  /// @param idx 起始播放位置
  /// @param doPlay 是否立即开始播放
  /// @param shuffling 是否开启随机播放
  Future<void> loadPlaylist(MediaPlaylist mediaList,
      {int idx = 0, bool doPlay = false, bool shuffling = false}) async {
    fromPlaylist.add(true);
    queue.add([]);
    relatedSongs.add([]);
    queue.add(mediaList.mediaItems);
    queueTitle.add(mediaList.playlistName);
    shuffle(shuffling || shuffleMode.value);
    if (shuffling || shuffleMode.value) {
      await prepare4play(idx: shuffleList[shuffleIdx], doPlay: doPlay);
    } else {
      await prepare4play(idx: idx, doPlay: doPlay);
    }
    // if (doPlay) play();
  }

  @override
  /// 暂停播放
  Future<void> pause() async {
    await audioPlayer.pause();
    isPaused = true;
    log("paused", name: "bloomeePlayer");
  }

  /// 获取音频源
  /// @param mediaItem 媒体项
  /// @return 音频源对象
  Future<AudioSource> getAudioSource(MediaItem mediaItem) async {
    final _down = await BloomeeDBService.getDownloadDB(
        mediaItem2MediaItemModel(mediaItem));
    if (_down != null) {
      log("Playing Offline", name: "bloomeePlayer");
      SnackbarService.showMessage("Playing Offline",
          duration: const Duration(seconds: 1));
      isOffline.add(true);
      return AudioSource.uri(Uri.file('${_down.filePath}/${_down.fileName}'),
          tag: mediaItem);
    } else {
      isOffline.add(false);
      log("Playing online", name: "bloomeePlayer");
      if (mediaItem.extras?["source"] == "youtube") {
        final id = mediaItem.id.replaceAll("youtube", '');
        return YouTubeAudioSource(videoId: id, quality: "high", tag: mediaItem);
      }
      String? kurl = await getJsQualityURL(mediaItem.extras?["url"]);
      log('Playing: $kurl', name: "bloomeePlayer");
      return AudioSource.uri(Uri.parse(kurl!), tag: mediaItem);
    }
  }

  @override
  /// 跳转到队列中的指定项目
  /// @param index 目标索引
  Future<void> skipToQueueItem(int index) async {
    if (index < queue.value.length) {
      currentPlayingIdx = index;
      await playMediaItem(queue.value[index]);
    } else {
      // await loadRelatedSongs();
      if (index < queue.value.length) {
        currentPlayingIdx = index;
        await playMediaItem(queue.value[index]);
      }
    }

    log("skipToQueueItem", name: "bloomeePlayer");
    return super.skipToQueueItem(index);
  }

  /// 播放音频源
  /// @param audioSource 音频源
  /// @param mediaId 媒体ID
  Future<void> playAudioSource({
    required AudioSource audioSource,
    required String mediaId,
  }) async {
    await pause();
    await seek(Duration.zero);
    try {
      if (_playlist.children.isNotEmpty) {
        await _playlist.clear();
      }
      await _playlist.add(audioSource);
      await audioPlayer.load();
      if (!audioPlayer.playing) await play();
    } catch (e) {
      log("Error: $e", name: "bloomeePlayer");
      if (e is PlayerException) {
        SnackbarService.showMessage("Failed to play song: $e");
        await stop();
      }
    }
  }

  @override
  /// 播放媒体项
  /// @param mediaItem 要播放的媒体项
  /// @param doPlay 是否立即开始播放
  Future<void> playMediaItem(MediaItem mediaItem, {bool doPlay = true}) async {
    final audioSource = await getAudioSource(mediaItem);
    await playAudioSource(audioSource: audioSource, mediaId: mediaItem.id);
    await check4RelatedSongs();
  }

  /// 准备播放
  /// @param idx 播放索引
  /// @param doPlay 是否立即开始播放
  Future<void> prepare4play({int idx = 0, bool doPlay = false}) async {
    if (queue.value.isNotEmpty) {
      currentPlayingIdx = idx;
      await playMediaItem(currentMedia, doPlay: doPlay);
      BloomeeDBService.putRecentlyPlayed(MediaItem2MediaItemDB(currentMedia));
    }
  }

  @override
  /// 重新播放当前歌曲
  Future<void> rewind() async {
    if (audioPlayer.processingState == ProcessingState.ready) {
      await audioPlayer.seek(Duration.zero);
    } else if (audioPlayer.processingState == ProcessingState.completed) {
      await prepare4play(idx: currentPlayingIdx);
    }
  }

  @override
  /// 跳转到下一首
  Future<void> skipToNext() async {
    if (!shuffleMode.value) {
      if (currentPlayingIdx < (queue.value.length - 1)) {
        currentPlayingIdx++;
        prepare4play(idx: currentPlayingIdx, doPlay: true);
      } else if (loopMode.value == LoopMode.all) {
        currentPlayingIdx = 0;
        prepare4play(idx: currentPlayingIdx, doPlay: true);
      }
    } else {
      if (shuffleIdx < (queue.value.length - 1)) {
        shuffleIdx++;
        prepare4play(idx: shuffleList[shuffleIdx], doPlay: true);
      } else if (loopMode.value == LoopMode.all) {
        shuffleIdx = 0;
        prepare4play(idx: shuffleList[shuffleIdx], doPlay: true);
      }
    }
  }

  @override
  /// 停止播放
  Future<void> stop() async {
    // log("Called Stop!!");
    audioPlayer.stop();
    super.stop();
  }

  @override
  /// 跳转到上一首
  Future<void> skipToPrevious() async {
    if (!shuffleMode.value) {
      if (currentPlayingIdx > 0) {
        currentPlayingIdx--;
        prepare4play(idx: currentPlayingIdx, doPlay: true);
      }
    } else {
      if (shuffleIdx > 0) {
        shuffleIdx--;
        prepare4play(idx: shuffleList[shuffleIdx], doPlay: true);
      }
    }
  }

  @override
  /// 任务被移除时的处理
  Future<void> onTaskRemoved() {
    super.stop();
    audioPlayer.dispose();
    return super.onTaskRemoved();
  }

  @override
  /// 通知被删除时的处理
  Future<void> onNotificationDeleted() {
    audioPlayer.dispose();
    audioPlayer.stop();
    super.stop();
    return super.onNotificationDeleted();
  }

  @override
  /// 在指定位置插入队列项
  /// @param index 插入位置
  /// @param mediaItem 要插入的媒体项
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    List<MediaItem> temp = queue.value;
    if (index < queue.value.length) {
      temp.insert(index, mediaItem);
    } else {
      temp.add(mediaItem);
    }
    queue.add(temp);

    // 调整当前播放索引
    if (currentPlayingIdx >= index) {
      currentPlayingIdx++;
    }
  }

  @override
  /// 添加队列项
  /// @param mediaItem 要添加的媒体项
  /// @param doPlay 是否立即播放
  Future<void> addQueueItem(MediaItem mediaItem, {bool doPlay = true}) async {
    if (queue.value.any((e) => e.id == mediaItem.id)) return;
    queueTitle.add("Queue");
    queue.add(queue.value..add(mediaItem));
    if (doPlay || queue.value.length == 1) {
      prepare4play(idx: queue.value.length - 1, doPlay: true);
    }
  }

  @override
  /// 更新播放队列
  /// @param newQueue 新的播放队列
  /// @param doPlay 是否立即开始播放
  Future<void> updateQueue(List<MediaItem> newQueue,
      {bool doPlay = false}) async {
    queue.add(newQueue);
    await prepare4play(idx: 0, doPlay: doPlay);
  }

  @override
  /// 批量添加队列项
  /// @param mediaItems 要添加的媒体项列表
  /// @param queueName 队列名称
  /// @param atLast 是否添加到队列末尾
  Future<void> addQueueItems(List<MediaItem> mediaItems,
      {String queueName = "Queue", bool atLast = false}) async {
    if (!atLast) {
      for (var mediaItem in mediaItems) {
        await addQueueItem(
          mediaItem,
        );
      }
    } else {
      if (fromPlaylist.value) {
        fromPlaylist.add(false);
      }
      queue.add(queue.value..addAll(mediaItems));
      queueTitle.add("Queue");
    }
  }

  /// 在当前播放项后添加下一首歌曲
  /// @param mediaItem 要添加的媒体项
  Future<void> addPlayNextItem(MediaItem mediaItem) async {
    if (queue.value.isNotEmpty) {
      // 检查媒体项是否已存在，如果存在则返回
      if (queue.value.any((e) => e.id == mediaItem.id)) return;
      queue.add(queue.value..insert(currentPlayingIdx + 1, mediaItem));
    } else {
      updateQueue([mediaItem], doPlay: true);
    }
  }

  @override
  /// 从队列中移除指定位置的项目
  /// @param index 要移除的项目索引
  Future<void> removeQueueItemAt(int index) async {
    if (index < queue.value.length) {
      List<MediaItem> temp = queue.value;
      temp.removeAt(index);
      queue.add(temp);

      if (currentPlayingIdx == index) {
        if (index < queue.value.length) {
          prepare4play(idx: index, doPlay: true);
        } else if (index > 0) {
          prepare4play(idx: index - 1, doPlay: true);
        } else {
          // stop();
        }
      } else if (currentPlayingIdx > index) {
        currentPlayingIdx--;
      }
    }
  }

  /// 移动队列中的项目
  /// @param oldIndex 原始位置
  /// @param newIndex 目标位置
  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    log("Moving from $oldIndex to $newIndex", name: "bloomeePlayer");
    List<MediaItem> temp = queue.value;
    if (oldIndex < newIndex) {
      newIndex--;
    }

    final item = temp.removeAt(oldIndex);
    temp.insert(newIndex, item);
    queue.add(temp);

    // 更新当前播放索引
    if (currentPlayingIdx == oldIndex) {
      currentPlayingIdx = newIndex;
    } else if (oldIndex < currentPlayingIdx && newIndex >= currentPlayingIdx) {
      currentPlayingIdx--;
    } else if (oldIndex > currentPlayingIdx && newIndex <= currentPlayingIdx) {
      currentPlayingIdx++;
    }
  }
}
