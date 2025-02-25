/// BloomeTunes音乐播放器应用程序的主入口文件
/// 负责初始化应用程序、配置依赖注入、设置主题和路由等核心功能
/// 包含应用程序的根组件MyApp和全局状态管理配置

// 系统库导入
import 'dart:async';
import 'dart:developer';
import 'dart:io' as io;

// 状态管理相关导入
import 'package:Bloomee/blocs/downloader/cubit/downloader_cubit.dart';
import 'package:Bloomee/blocs/internet_connectivity/cubit/connectivity_cubit.dart';
import 'package:Bloomee/blocs/lastdotfm/lastdotfm_cubit.dart';
import 'package:Bloomee/blocs/lyrics/lyrics_cubit.dart';
import 'package:Bloomee/blocs/mini_player/mini_player_bloc.dart';
import 'package:Bloomee/blocs/notification/notification_cubit.dart';
import 'package:Bloomee/blocs/settings_cubit/cubit/settings_cubit.dart';
import 'package:Bloomee/blocs/timer/timer_bloc.dart';

// 服务和工具类导入
import 'package:Bloomee/repository/Youtube/youtube_api.dart';
import 'package:Bloomee/screens/widgets/snackbar.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:Bloomee/services/shortcuts_intents.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:Bloomee/services/file_manager.dart';
import 'package:Bloomee/utils/external_list_importer.dart';
import 'package:Bloomee/utils/ticker.dart';
import 'package:Bloomee/utils/url_checker.dart';

// Flutter框架相关导入
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// 播放列表和库管理相关导入
import 'package:Bloomee/blocs/add_to_playlist/cubit/add_to_playlist_cubit.dart';
import 'package:Bloomee/blocs/library/cubit/library_items_cubit.dart';
import 'package:Bloomee/blocs/search/fetch_search_results.dart';
import 'package:Bloomee/routes_and_consts/routes.dart';
import 'package:Bloomee/screens/screen/library_views/cubit/current_playlist_cubit.dart';
import 'package:Bloomee/screens/screen/library_views/cubit/import_playlist_cubit.dart';
import 'package:Bloomee/services/db/cubit/bloomee_db_cubit.dart';

// 第三方库导入
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:metadata_god/metadata_god.dart';
import 'package:path_provider/path_provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:responsive_framework/responsive_framework.dart';
import 'blocs/mediaPlayer/bloomee_player_cubit.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// 处理外部分享意图
/// @param sharedMediaFiles 共享的媒体文件列表
/// 根据分享的URL类型执行不同的导入操作
void processIncomingIntent(List<SharedMediaFile> sharedMediaFiles) {
  if (isUrl(sharedMediaFiles[0].path)) {
    final urlType = getUrlType(sharedMediaFiles[0].path);
    switch (urlType) {
      case UrlType.spotifyTrack:
        // 导入Spotify单曲
        ExternalMediaImporter.sfyMediaImporter(sharedMediaFiles[0].path)
            .then((value) async {
          if (value != null) {
            await bloomeePlayerCubit.bloomeePlayer
                .addQueueItem(value, doPlay: true);
          }
        });
        break;
      case UrlType.spotifyPlaylist:
        SnackbarService.showMessage("Import Spotify Playlist from library!");
        break;
      case UrlType.youtubePlaylist:
        SnackbarService.showMessage("Import Youtube Playlist from library!");
        break;
      case UrlType.spotifyAlbum:
        SnackbarService.showMessage("Import Spotify Album from library!");
        break;
      case UrlType.youtubeVideo:
        // 导入YouTube视频
        ExternalMediaImporter.ytMediaImporter(sharedMediaFiles[0].path)
            .then((value) async {
          if (value != null) {
            await bloomeePlayerCubit.bloomeePlayer
                .addQueueItem(value, doPlay: true);
          }
        });
        break;
      case UrlType.other:
        // 处理其他类型文件
        if (sharedMediaFiles[0].mimeType == "application/octet-stream") {
          SnackbarService.showMessage("Processing File...");
          importItems(
              Uri.parse(sharedMediaFiles[0].path).toFilePath().toString());
        }
      default:
        log("Invalid URL");
    }
  }
}

/// 导入媒体项目或播放列表
/// @param path 文件路径
/// 尝试导入媒体项目，如果失败则尝试导入播放列表
Future<void> importItems(String path) async {
  bool _res = await BloomeeFileManager.importMediaItem(path);
  if (_res) {
    SnackbarService.showMessage("Media Item Imported");
  } else {
    _res = await BloomeeFileManager.importPlaylist(path);
    if (_res) {
      SnackbarService.showMessage("Playlist Imported");
    } else {
      SnackbarService.showMessage("Invalid File Format");
    }
  }
}

/// 设置高刷新率
/// 仅在Android平台上启用高刷新率显示
Future<void> setHighRefreshRate() async {
  if (io.Platform.isAndroid) {
    await FlutterDisplayMode.setHighRefreshRate();
  }
}

/// 全局播放器Cubit实例
late BloomeePlayerCubit bloomeePlayerCubit;

/// 初始化播放器Cubit
void setupPlayerCubit() {
  bloomeePlayerCubit = BloomeePlayerCubit();
}

/// 初始化应用服务
/// 设置应用文档和支持目录路径
/// 初始化数据库服务和YouTube服务
Future<void> initServices() async {
  String appDocPath = (await getApplicationDocumentsDirectory()).path;
  String appSuppPath = (await getApplicationSupportDirectory()).path;
  BloomeeDBService(appDocPath: appDocPath, appSuppPath: appSuppPath);
  YouTubeServices(appDocPath: appDocPath, appSuppPath: appSuppPath);
}

/// 应用程序入口点
/// 初始化必要的服务和配置
Future<void> main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();
  GestureBinding.instance.resamplingEnabled = true;
  
  // 在Linux和Windows平台初始化音频播放器
  if (io.Platform.isLinux || io.Platform.isWindows) {
    JustAudioMediaKit.ensureInitialized(
      linux: true,
      windows: true,
    );
  }
  
  // 初始化各项服务
  await initServices();
  setHighRefreshRate();
  MetadataGod.initialize();
  setupPlayerCubit();
  
  // 运行应用
  runApp(const MyApp());
}

/// 应用程序根组件
/// 负责配置全局状态管理、主题和路由
class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // 外部分享意图订阅
  late StreamSubscription _intentSub;
  final sharedMediaFiles = <SharedMediaFile>[];

  @override
  void initState() {
    super.initState();
    // 在Android平台处理外部分享意图
    if (io.Platform.isAndroid) {
      // 处理应用在内存中时的分享意图
      _intentSub =
          ReceiveSharingIntent.instance.getMediaStream().listen((event) {
        sharedMediaFiles.clear();
        sharedMediaFiles.addAll(event);
        log(sharedMediaFiles[0].mimeType.toString(), name: "Shared Files");
        log(sharedMediaFiles[0].path, name: "Shared Files");
        processIncomingIntent(sharedMediaFiles);

        // 通知库已完成处理意图
        ReceiveSharingIntent.instance.reset();
      });

      // 处理应用关闭时的分享意图
      ReceiveSharingIntent.instance.getInitialMedia().then((event) {
        sharedMediaFiles.clear();
        sharedMediaFiles.addAll(event);
        log(sharedMediaFiles[0].mimeType.toString(),
            name: "Shared Files Offline");
        log(sharedMediaFiles[0].path, name: "Shared Files Offline");
        processIncomingIntent(sharedMediaFiles);
        ReceiveSharingIntent.instance.reset();
      });
    }
  }

  @override
  void dispose() {
    // 清理资源
    _intentSub.cancel();
    bloomeePlayerCubit.bloomeePlayer.audioPlayer.dispose();
    bloomeePlayerCubit.close();
    super.dispose();
  }

  @override
  /// 构建应用程序的根Widget
  /// @param context 构建上下文
  /// @return 返回配置了全局状态管理、路由和主题的应用程序根Widget
  Widget build(BuildContext context) {
    // 使用MultiBlocProvider配置全局状态管理
    return MultiBlocProvider(
      // 配置全局状态管理提供者
      // 配置所有需要的BlocProvider
      // 包括播放器、数据库、设置、通知、定时器等核心功能的状态管理
      providers: [
        BlocProvider(
          create: (context) => bloomeePlayerCubit,
          lazy: false,
        ),
        BlocProvider(
            create: (context) =>
                MiniPlayerBloc(playerCubit: bloomeePlayerCubit),
            lazy: true),
        BlocProvider(
          create: (context) => BloomeeDBCubit(),
          lazy: false,
        ),
        BlocProvider(
          create: (context) => SettingsCubit(),
          lazy: false,
        ),
        BlocProvider(create: (context) => NotificationCubit(), lazy: false),
        BlocProvider(
            create: (context) => TimerBloc(
                ticker: const Ticker(), bloomeePlayer: bloomeePlayerCubit)),
        BlocProvider(
          create: (context) => ConnectivityCubit(),
          lazy: false,
        ),
        BlocProvider(
          create: (context) => CurrentPlaylistCubit(
              bloomeeDBCubit: context.read<BloomeeDBCubit>()),
          lazy: false,
        ),
        BlocProvider(
          create: (context) =>
              LibraryItemsCubit(bloomeeDBCubit: context.read<BloomeeDBCubit>()),
        ),
        BlocProvider(
          create: (context) => AddToPlaylistCubit(),
          lazy: false,
        ),
        BlocProvider(
          create: (context) => ImportPlaylistCubit(),
        ),
        BlocProvider(
          create: (context) => FetchSearchResultsCubit(),
        ),
        BlocProvider(
          create: (context) => LyricsCubit(bloomeePlayerCubit),
        ),
        BlocProvider(
          create: (context) => LastdotfmCubit(playerCubit: bloomeePlayerCubit),
          lazy: false,
        ),
      ],
      // 配置下载器的RepositoryProvider
      child: RepositoryProvider(
        create: (context) => DownloaderCubit(
            connectivityCubit: context.read<ConnectivityCubit>()),
        lazy: false,
        // 使用BlocBuilder监听播放器状态变化
        child: BlocBuilder<BloomeePlayerCubit, BloomeePlayerState>(
          builder: (context, state) {
            if (state is BloomeePlayerInitial) {
              // 显示加载指示器
              return const SizedBox(
                  width: 50, height: 50, child: CircularProgressIndicator());
            } else {
              // 配置应用的路由、主题和其他全局设置
              // 使用MaterialApp.router支持声明式路由
              return MaterialApp.router(
                // 配置全局键盘快捷键映射
                // 定义各种媒体控制快捷键，如播放/暂停、上一首/下一首、音量控制等
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.space):
                      const PlayPauseIntent(),
                  LogicalKeySet(LogicalKeyboardKey.mediaPlayPause):
                      const PlayPauseIntent(),
                  LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                      const PreviousIntent(),
                  LogicalKeySet(LogicalKeyboardKey.arrowRight):
                      const NextIntent(),
                  LogicalKeySet(LogicalKeyboardKey.keyR): const RepeatIntent(),
                  LogicalKeySet(LogicalKeyboardKey.keyL): const LikeIntent(),
                  LogicalKeySet(LogicalKeyboardKey.arrowRight,
                      LogicalKeyboardKey.alt): const NSecForwardIntent(),
                  LogicalKeySet(
                          LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.alt):
                      const NSecBackwardIntent(),
                  LogicalKeySet(LogicalKeyboardKey.arrowUp):
                      const VolumeUpIntent(),
                  LogicalKeySet(LogicalKeyboardKey.arrowDown):
                      const VolumeDownIntent(),
                },
                // 配置快捷键对应的具体操作行为
                // 实现各个快捷键的回调函数，处理具体的播放控制逻辑
                actions: {
                  PlayPauseIntent: CallbackAction(onInvoke: (intent) {
                    if (context
                        .read<BloomeePlayerCubit>()
                        .bloomeePlayer
                        .audioPlayer
                        .playing) {
                      context
                          .read<BloomeePlayerCubit>()
                          .bloomeePlayer
                          .audioPlayer
                          .pause();
                    } else {
                      context
                          .read<BloomeePlayerCubit>()
                          .bloomeePlayer
                          .audioPlayer
                          .play();
                    }
                    return null;
                  }),
                  NextIntent: CallbackAction(onInvoke: (intent) {
                    context
                        .read<BloomeePlayerCubit>()
                        .bloomeePlayer
                        .skipToNext();
                    return null;
                  }),
                  PreviousIntent: CallbackAction(onInvoke: (intent) {
                    context
                        .read<BloomeePlayerCubit>()
                        .bloomeePlayer
                        .skipToPrevious();
                    return null;
                  }),
                  NSecForwardIntent: CallbackAction(onInvoke: (intent) {
                    context
                        .read<BloomeePlayerCubit>()
                        .bloomeePlayer
                        .seekNSecForward(const Duration(seconds: 5));
                    return null;
                  }),
                  NSecBackwardIntent: CallbackAction(onInvoke: (intent) {
                    context
                        .read<BloomeePlayerCubit>()
                        .bloomeePlayer
                        .seekNSecBackward(const Duration(seconds: 5));
                    return null;
                  }),
                  VolumeUpIntent: CallbackAction(onInvoke: (intent) {
                    context
                        .read<BloomeePlayerCubit>()
                        .bloomeePlayer
                        .audioPlayer
                        .setVolume((context
                                    .read<BloomeePlayerCubit>()
                                    .bloomeePlayer
                                    .audioPlayer
                                    .volume +
                                0.1)
                            .clamp(0.0, 1.0));
                    return null;
                  }),
                  VolumeDownIntent: CallbackAction(onInvoke: (intent) {
                    context
                        .read<BloomeePlayerCubit>()
                        .bloomeePlayer
                        .audioPlayer
                        .setVolume((context
                                    .read<BloomeePlayerCubit>()
                                    .bloomeePlayer
                                    .audioPlayer
                                    .volume -
                                0.1)
                            .clamp(0.0, 1.0));
                    return null;
                  }),
                },
                // 配置响应式布局
                // 使用ResponsiveBreakpoints.builder实现不同屏幕尺寸的自适应布局
                builder: (context, child) => ResponsiveBreakpoints.builder(
                  child: child!,
                  breakpoints: [
                    const Breakpoint(start: 0, end: 450, name: MOBILE),
                    const Breakpoint(start: 451, end: 800, name: TABLET),
                    const Breakpoint(start: 801, end: 1920, name: DESKTOP),
                    const Breakpoint(
                        start: 1921, end: double.infinity, name: '4K'),
                  ],
                ),
                // 配置Snackbar服务的全局Key
                scaffoldMessengerKey: SnackbarService.messengerKey,
                // 配置全局路由
                routerConfig: GlobalRoutes.globalRouter,
                // 配置应用主题
                theme: Default_Theme().defaultThemeData,
                // 配置自定义滚动行为
                scrollBehavior: CustomScrollBehavior(),
                // 关闭调试横幅
                debugShowCheckedModeBanner: false,
              );
            }
          },
        ),
      ),
    );
  }
}

class CustomScrollBehavior extends MaterialScrollBehavior {
  /// 重写dragDevices getter方法，定义支持的拖动设备类型
  /// @return 返回支持的输入设备类型集合
  /// - PointerDeviceKind.touch: 支持触摸屏幕滚动
  /// - PointerDeviceKind.mouse: 支持鼠标滚轮和拖动
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        // 可以根据需要添加其他设备类型支持
      };
}
