import 'dart:developer';
import 'dart:isolate';
import 'package:Bloomee/repository/Youtube/youtube_api.dart';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:async/async.dart';

/// 缓存YouTube视频流
/// @param id 视频ID
/// @param hURL 高质量视频流URL
/// @param lURL 低质量视频流URL
Future<void> cacheYtStreams({
  required String id,
  required String hURL,
  required String lURL,
}) async {
  // 从URL中提取过期时间
  final expireAt = RegExp('expire=(.*?)&').firstMatch(lURL)!.group(1) ??
      (DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600 * 5.5).toString();

  try {
    BloomeeDBService.putYtLinkCache(
      id,
      lURL,
      hURL,
      int.parse(expireAt),
    );
    log("Cached: $id, ExpireAt: $expireAt", name: "CacheYtStreams");
  } catch (e) {
    log(e.toString(), name: "CacheYtStreams");
  }
}

/// YouTube后台服务isolate
/// 在独立的isolate中处理视频流的刷新和缓存
/// @param opts isolate初始化参数列表
Future<void> ytbgIsolate(List<dynamic> opts) async {
  final appDocPath = opts[0] as String;
  final appSupPath = opts[1] as String;
  final SendPort port = opts[2] as SendPort;

  // 初始化数据库服务
  BloomeeDBService(appDocPath: appDocPath, appSuppPath: appSupPath);
  final yt = YouTubeServices(
    appDocPath: appDocPath,
    appSuppPath: appSupPath,
  );

  // 创建可取消的操作
  CancelableOperation<Map?> canOprn =
      CancelableOperation.fromFuture(Future.value(null));

  final ReceivePort receivePort = ReceivePort();
  port.send(receivePort.sendPort);

  // 监听接收端口的消息
  receivePort.listen(
    (dynamic data) async {
      /*
      Map<String, dynamic> =>
      {
        "mediaId": "media_id",
        "id": "video_id",
        "quality": "high"
      }*/
      if (data is Map) {
        var time = DateTime.now().millisecondsSinceEpoch;

        // 取消之前的操作并开始新的刷新
        await canOprn.cancel();
        canOprn = CancelableOperation.fromFuture(
          yt.refreshLink(data["id"], quality: 'Low'),
          onCancel: () {
            log("Operation Cancelled-${data['id']}", name: "IsolateBG");
          },
        );

        Map? refreshedUrl = await canOprn.value;
        int quality = 2;

        // 获取视频质量设置
        await BloomeeDBService.getSettingStr(GlobalStrConsts.ytStrmQuality)
            .then(
          (value) {
            if (value != null) {
              switch (value) {
                case "Low":
                  quality = 1;
                  break;

                case "High":
                  quality = 2;
                  break;
                default:
                  quality = 2;
              }
            }
          },
        );

        var time2 = DateTime.now().millisecondsSinceEpoch;
        log("Time taken: ${time2 - time}ms, quality: $quality",
            name: "IsolateBG");
        
        // 处理刷新结果
        if (refreshedUrl!['qurls'][0] == true) {
          port.send(
            {
              "mediaId": data["mediaId"],
              "id": data["id"],
              "quality": data["quality"],
              "link": refreshedUrl['qurls'][quality],
            },
          );
          // 缓存视频流URL
          cacheYtStreams(
            id: data["id"],
            hURL: refreshedUrl['qurls'][2],
            lURL: refreshedUrl['qurls'][1],
          );
        } else {
          port.send(
            {
              "mediaId": data["mediaId"],
              "id": data["id"],
              "quality": data["quality"],
              "link": null,
            },
          );
        }
      }
    },
  );
}
