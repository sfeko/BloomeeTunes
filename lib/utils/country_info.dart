/// 国家信息工具类
/// 负责获取和管理应用程序的国家/地区设置
/// 支持自动获取用户所在国家或使用手动设置的国家代码

import 'dart:convert';
import 'dart:developer';
import 'package:Bloomee/routes_and_consts/global_str_consts.dart';
import 'package:Bloomee/services/db/bloomee_db_service.dart';
import 'package:http/http.dart';

/// 获取当前使用的国家代码
/// 如果启用了自动获取功能，则通过IP地址获取用户所在国家
/// 否则使用存储在数据库中的国家代码
/// @return 返回两字母的国家代码，默认为"IN"(印度)
Future<String> getCountry() async {
  String countryCode = "IN";
  await BloomeeDBService.getSettingBool(GlobalStrConsts.autoGetCountry)
      .then((value) async {
    if (value != null && value == true) {
      try {
        final response = await get(Uri.parse('http://ip-api.com/json'));
        if (response.statusCode == 200) {
          Map data = jsonDecode(utf8.decode(response.bodyBytes));
          countryCode = data['countryCode'];
          await BloomeeDBService.putSettingStr(
              GlobalStrConsts.countryCode, countryCode);
        }
      } catch (err) {
        await BloomeeDBService.getSettingStr(GlobalStrConsts.countryCode)
            .then((value) {
          if (value != null) {
            countryCode = value;
          } else {
            countryCode = "IN";
          }
        });
      }
    } else {
      await BloomeeDBService.getSettingStr(GlobalStrConsts.countryCode)
          .then((value) {
        if (value != null) {
          countryCode = value;
        } else {
          countryCode = "IN";
        }
      });
    }
  });
  log("Country Code: $countryCode");
  return countryCode;
}
