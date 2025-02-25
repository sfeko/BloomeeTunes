/// 音频服务初始化器
/// 负责初始化和管理BloomeePlayer的音频服务实例
/// 使用单例模式确保全局只有一个音频服务实例

import 'package:Bloomee/services/bloomeePlayer.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:audio_service/audio_service.dart';

/// 播放器初始化类
/// 使用单例模式确保全局只有一个播放器实例
class PlayerInitializer {
  /// 私有静态实例
  static final PlayerInitializer _instance = PlayerInitializer._internal();

  /// 工厂构造函数，返回单例实例
  factory PlayerInitializer() {
    return _instance;
  }

  /// 私有构造函数
  PlayerInitializer._internal();

  /// 标记是否已初始化
  static bool _isInitialized = false;

  /// 播放器实例
  static BloomeeMusicPlayer? bloomeeMusicPlayer;

  /// 初始化音频服务
  /// 配置通知栏等Android特定设置
  Future<void> _initialize() async {
    bloomeeMusicPlayer = await AudioService.init(
      builder: () => BloomeeMusicPlayer(),
      config: const AudioServiceConfig(
        androidStopForegroundOnPause: false,
        androidNotificationChannelId: 'com.BloomeePlayer.notification.status',
        androidNotificationChannelName: 'BloomeTunes',
        androidResumeOnClick: true,
        // androidNotificationIcon: 'assets/icons/Bloomee_logo_fore.png',
        androidShowNotificationBadge: true,
        notificationColor: Default_Theme.accentColor2,
      ),
    );
  }

  /// 获取播放器实例
  /// 如果播放器未初始化，则先进行初始化
  /// 返回已初始化的播放器实例
  Future<BloomeeMusicPlayer> getBloomeeMusicPlayer() async {
    if (!_isInitialized) {
      await _initialize();
      _isInitialized = true;
    }
    return bloomeeMusicPlayer!;
  }
}
