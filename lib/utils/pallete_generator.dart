/// 调色板生成工具类
/// 用于从图片中提取主色调，生成调色板
/// 支持网络图片和本地图片的颜色提取

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// 从图片URL生成调色板
/// 尝试从网络图片生成调色板，如果失败则使用默认图片
/// @param url 图片URL
/// @return 返回生成的调色板对象
Future<PaletteGenerator> getPalleteFromImage(String url) async {
  ImageProvider<Object> placeHolder =
      const AssetImage("assets/icons/bloomee_new_logo_c.png");

  try {
    return (await PaletteGenerator.fromImageProvider(
        CachedNetworkImageProvider(url)));
  } catch (e) {
    return await PaletteGenerator.fromImageProvider(placeHolder);
  }
}
