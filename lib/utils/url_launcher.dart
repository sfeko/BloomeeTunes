/// URL启动工具类
/// 提供在外部应用程序中打开URL的功能
/// 使用url_launcher包实现URL的外部打开

import 'dart:developer';
import 'package:url_launcher/url_launcher.dart';

/// 在外部应用程序中启动URL
/// @param _url 要启动的URL
/// @return 无返回值，启动失败时会记录日志
Future<void> launch_Url(_url) async {
  if (!await launchUrl(_url, mode: LaunchMode.externalApplication)) {
    log('Could not launch $_url', name: "launch_Url");
  }
}
