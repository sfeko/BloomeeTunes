/// 快捷键意图（Intents）定义文件
/// 定义了应用程序中所有与键盘快捷键相关的Intent类
/// 每个Intent类对应一个特定的操作，如播放/暂停、下一首、上一首等

import 'package:flutter/material.dart';

/// 播放/暂停音乐的意图
/// 用于控制当前播放的音乐暂停或继续播放
class PlayPauseIntent extends Intent {
  const PlayPauseIntent();
}

/// 播放下一首歌曲的意图
/// 用于切换到播放列表中的下一首歌曲
class NextIntent extends Intent {
  const NextIntent();
}

/// 播放上一首歌曲的意图
/// 用于切换到播放列表中的上一首歌曲
class PreviousIntent extends Intent {
  const PreviousIntent();
}

/// 切换随机播放模式的意图
/// 用于开启或关闭随机播放功能
class ShuffleIntent extends Intent {
  const ShuffleIntent();
}

/// 切换重复播放模式的意图
/// 用于切换不同的重复播放模式（单曲循环、列表循环等）
class RepeatIntent extends Intent {
  const RepeatIntent();
}

/// 收藏/取消收藏当前歌曲的意图
/// 用于将当前播放的歌曲添加到收藏列表或从收藏列表中移除
class LikeIntent extends Intent {
  const LikeIntent();
}

/// 快进N秒的意图
/// 用于在当前播放进度上快进指定的秒数
class NSecForwardIntent extends Intent {
  const NSecForwardIntent();
}

/// 快退N秒的意图
/// 用于在当前播放进度上快退指定的秒数
class NSecBackwardIntent extends Intent {
  const NSecBackwardIntent();
}

/// 增加音量的意图
/// 用于提高当前播放音量
class VolumeUpIntent extends Intent {
  const VolumeUpIntent();
}

/// 降低音量的意图
/// 用于降低当前播放音量
class VolumeDownIntent extends Intent {
  const VolumeDownIntent();
}

/// 静音/取消静音的意图
/// 用于切换音频的静音状态
class MuteIntent extends Intent {
  const MuteIntent();
}

/// 设置单曲循环的意图
/// 用于将当前歌曲设置为单曲循环模式
class LoopSingleIntent extends Intent {
  const LoopSingleIntent();
}

/// 设置列表循环的意图
/// 用于将播放模式设置为列表循环
class LoopPlaylistIntent extends Intent {
  const LoopPlaylistIntent();
}

/// 关闭循环播放的意图
/// 用于关闭所有循环播放模式
class LoopOffIntent extends Intent {
  const LoopOffIntent();
}

/// 打开定时器设置的意图
/// 用于打开定时关闭播放的设置界面
class TimerIntent extends Intent {
  const TimerIntent();
}

/// 返回上一页的意图
/// 用于导航返回上一个页面
class BackIntent extends Intent {
  const BackIntent();
}
