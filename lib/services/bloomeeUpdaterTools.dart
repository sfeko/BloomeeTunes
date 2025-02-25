import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// 检查是否有新版本可用
/// @param currentVer 当前版本号
/// @param currentBuild 当前构建号
/// @param newVer 新版本号
/// @param newBuild 新构建号
/// @param checkBuild 是否检查构建号（默认为true）
/// @return 如果有新版本返回true，否则返回false
bool isUpdateAvailable(
    String currentVer, String currentBuild, String newVer, String newBuild,
    {bool checkBuild = true}) {
  List<int> currentVersionParts = currentVer.split('.').map(int.parse).toList();
  List<int> newVersionParts = newVer.split('.').map(int.parse).toList();

  // 比较版本号的每个部分
  for (int i = 0; i < currentVersionParts.length; i++) {
    if (newVersionParts[i] > currentVersionParts[i]) {
      return true;
    } else if (newVersionParts[i] < currentVersionParts[i]) {
      return false;
    }
  }

  // 如果需要检查构建号
  if (checkBuild) {
    int currentBuildNumber = int.parse(currentBuild);
    int newBuildNumber = int.parse(newBuild);

    if (newBuildNumber > currentBuildNumber) {
      return true;
    } else if (newBuildNumber < currentBuildNumber) {
      return false;
    }
  }

  return false;
}

/// 从SourceForge获取更新信息
/// 根据不同平台获取对应的更新包信息
/// @return 包含更新信息的Map，包括新版本号、下载链接等
Future<Map<String, dynamic>> sourceforgeUpdate() async {
  String platform = Platform.operatingSystem;
  if (platform == 'linux') {
    platform = 'linux';
  } else if (platform == 'android') {
    platform = 'android';
  } else {
    platform = 'win';
  }
  const url = 'https://sourceforge.net/projects/bloomee/best_release.json';
  
  // 针对不同平台设置不同的User-Agent
  final userAgent = {
    'win':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
    'linux':
        'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/65.0.3868.146 Safari/537.36 OPR/54.0.4087.46',
    'android':
        'Mozilla/5.0 (Linux; Android 13;) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/112.0.0.0 Mobile Safari/537.36',
  };

  final headers = {
    'user-agent': userAgent[platform]!,
  };
  
  // 获取当前应用版本信息
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  final response = await http.get(Uri.parse(url), headers: headers);
  log("response status code: ${response.statusCode}", name: 'UpdaterTools');
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final releaseUrl = data['release']['url'];
    final filename = data['release']['filename'];
    final fileNameParts = filename.split('/');
    
    // 解析版本号和构建号
    final versionMatch =
        RegExp(r'v(\d+\.\d+\.\d+)').firstMatch(fileNameParts.last);
    final buildMatch = RegExp(r'\+(\d+)').firstMatch(fileNameParts.last);
    final version = versionMatch?.group(1);
    final build = buildMatch?.group(1);

    return {
      'newVer': version ?? '',
      'newBuild': build ?? '',
      'download_url': releaseUrl,
      'currVer': packageInfo.version,
      'currBuild': packageInfo.buildNumber,
      'results': isUpdateAvailable(
        packageInfo.version,
        packageInfo.buildNumber,
        version ?? '0.0.0',
        build ?? '0',
        checkBuild: platform == 'linux' ? false : true,
      ),
    };
  } else {
    throw Exception('Failed to load latest version!');
  }
}

/// 从GitHub获取更新信息
/// 通过GitHub API获取最新发布版本信息
/// @return 包含更新信息的Map
Future<Map<String, dynamic>> githubUpdate() async {
  http.Response response;
  try {
    response = await http.get(
      Uri.parse(
          'https://api.github.com/repos/HemantKArya/BloomeeTunes/releases/latest'),
    );
  } catch (e) {
    log('Failed to load latest version!', name: 'UpdaterTools');
    return {
      "results": false,
    };
  }
  PackageInfo packageInfo = await PackageInfo.fromPlatform();
  if (response.statusCode == 200) {
    Map<String, dynamic> data = json.decode(response.body);
    String newBuildVer = (data['tag_name'] as String).split("+")[1];
    return {
      "results": isUpdateAvailable(
        packageInfo.version,
        packageInfo.buildNumber,
        data["tag_name"].toString().split("+")[0].replaceFirst("v", ''),
        newBuildVer,
        checkBuild: false,
      ),
      "newBuild": newBuildVer,
      "currBuild": packageInfo.buildNumber,
      "currVer": packageInfo.version,
      "newVer": data["tag_name"].toString().split("+")[0].replaceFirst("v", ''),
      // "download_url": extractUpUrl(data),
      "download_url":
          "https://sourceforge.net/projects/bloomee/files/latest/download",
    };
  } else {
    log('Failed to load latest version!', name: 'UpdaterTools');
    return {
      "currBuild": packageInfo.buildNumber,
      "currVer": packageInfo.version,
      "results": false,
    };
  }
}

/// 获取最新版本信息
/// 首先尝试从SourceForge获取更新信息，如果失败则从GitHub获取
/// @return 包含更新信息的Map，包括：
/// - results: 是否有新版本可用
/// - newVer: 新版本号
/// - newBuild: 新构建号
/// - currVer: 当前版本号
/// - currBuild: 当前构建号
/// - download_url: 下载链接
Future<Map<String, dynamic>> getLatestVersion() async {
  try {
    return await sourceforgeUpdate();
  } catch (e) {
    return await githubUpdate();
  }
}

/// 从GitHub release资源中提取对应平台的下载链接
/// @param data GitHub API返回的release数据
/// @return 返回对应当前平台的下载链接，如果没有找到对应平台的下载链接则返回null
String? extractUpUrl(Map<String, dynamic> data) {
  // List<String> urls = [];

  for (var element in (data["assets"] as List)) {
    // urls.add(element["browser_download_url"]);
    if (element["browser_download_url"].toString().contains("windows")) {
      if (Platform.isWindows) {
        return element["browser_download_url"].toString();
      }
    } else if (element["browser_download_url"].toString().contains("android")) {
      if (Platform.isAndroid) {
        return element["browser_download_url"].toString();
      }
    } else {
      continue;
    }
  }
  return null;
}
