// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Bloomee/theme_data/default.dart';
import 'package:http/http.dart' as http;

/// 加载网络图片
/// @param coverImageUrl 图片URL
/// @param placeholderPath 占位图路径，默认使用应用logo
/// @return 返回配置好的Image组件
Image loadImage(coverImageUrl,
    {placeholderPath = "assets/icons/bloomee_new_logo_c.png"}) {
  ImageProvider<Object> placeHolder = AssetImage(placeholderPath);
  return Image.network(
    coverImageUrl,
    fit: BoxFit.cover,
    loadingBuilder: (context, child, loadingProgress) {
      if (loadingProgress == null) {
        return child;
      } else {
        return Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxHeight > constraints.maxWidth) {
                return SizedBox(
                  height: constraints.maxWidth,
                  width: constraints.maxWidth,
                  child: const CircularProgressIndicator(
                      color: Default_Theme.accentColor2),
                );
              } else {
                return SizedBox(
                  height: constraints.maxHeight,
                  width: constraints.maxHeight,
                  child: const CircularProgressIndicator(
                      color: Default_Theme.accentColor2),
                );
              }
            },
          ),
        );
      }
    },
    errorBuilder: (context, error, stackTrace) {
      return Image(
        image: placeHolder,
        fit: BoxFit.cover,
      );
    },
  );
}

/// 加载带缓存的网络图片
/// @param coverImageURL 图片URL
/// @param placeholderPath 占位图路径，默认使用应用logo
/// @param fit 图片填充模式，默认为BoxFit.cover
/// @return 返回配置好的CachedNetworkImage组件
CachedNetworkImage loadImageCached(coverImageURL,
    {placeholderPath = "assets/icons/bloomee_new_logo_c.png",
    fit = BoxFit.cover}) {
  ImageProvider<Object> placeHolder = AssetImage(placeholderPath);
  return CachedNetworkImage(
    imageUrl: coverImageURL,
    memCacheWidth: 500,
    placeholder: (context, url) => Image(
      image: const AssetImage("assets/icons/lazy_loading.png"),
      fit: fit,
    ),
    errorWidget: (context, url, error) => Image(
      image: placeHolder,
      fit: fit,
    ),
    fadeInDuration: const Duration(milliseconds: 700),
    fit: fit,
  );
}

/// 带缓存的图片加载组件
/// 提供更灵活的图片加载选项，包括备用URL和自定义占位图
class LoadImageCached extends StatefulWidget {
  /// 图片URL
  final String imageUrl;
  /// 备用图片URL，加载失败时使用
  final String? fallbackUrl;
  /// 占位图URL
  final String placeholderUrl;
  /// 图片填充模式
  final BoxFit fit;

  const LoadImageCached({
    Key? key,
    required this.imageUrl,
    this.placeholderUrl = "assets/icons/bloomee_new_logo_c.png",
    this.fit = BoxFit.cover,
    this.fallbackUrl,
  }) : super(key: key);

  @override
  State<LoadImageCached> createState() => _LoadImageCachedState();
}

/// LoadImageCached组件的状态类
/// 负责管理LoadImageCached组件的状态和渲染逻辑
class _LoadImageCachedState extends State<LoadImageCached> {
  @override
  Widget build(BuildContext context) {
    // 使用CachedNetworkImage组件加载网络图片
    // 提供了图片加载中的占位图、加载失败时的错误处理，以及图片淡入动画效果
    return CachedNetworkImage(
      imageUrl: widget.imageUrl,  // 设置要加载的网络图片URL
      placeholder: (context, url) => Image(
        // 加载过程中显示lazy_loading占位图
        image: const AssetImage("assets/icons/lazy_loading.png"),
        fit: widget.fit,
      ),
      errorWidget: (context, url, error) => widget.fallbackUrl == null
          ? Image(
              // 如果没有设置备用URL，则显示默认占位图
              image: AssetImage(widget.placeholderUrl),
              fit: widget.fit,
            )
          : CachedNetworkImage(
              // 如果设置了备用URL，尝试加载备用图片
              imageUrl: widget.fallbackUrl!,
              memCacheWidth: 500,  // 设置图片缓存的最大宽度
              placeholder: (context, url) => Image(
                // 加载备用图片时也显示lazy_loading占位图
                image: const AssetImage("assets/icons/lazy_loading.png"),
                fit: widget.fit,
              ),
              errorWidget: (context, url, error) => Image(
                // 如果备用图片也加载失败，显示默认占位图
                image: AssetImage(widget.placeholderUrl),
                fit: widget.fit,
              ),
              fadeInDuration: const Duration(milliseconds: 300),  // 设置图片淡入动画时长
              fit: widget.fit,
            ),
      fadeInDuration: const Duration(milliseconds: 300),  // 设置主图片淡入动画时长
      fit: widget.fit,  // 设置图片填充模式
    );
  }
}

/// 异步获取图片提供者
/// 首先尝试获取网络图片，如果网络图片不可用则返回默认占位图
/// @param imageUrl 需要加载的图片URL
/// @param placeholderUrl 占位图路径，默认使用应用logo
/// @return 返回ImageProvider对象，可能是CachedNetworkImageProvider或AssetImage
Future<ImageProvider> getImageProvider(String imageUrl,
    {String placeholderUrl = "assets/icons/bloomee_new_logo_c.png"}) async {
  if (imageUrl != "") {
    // 使用HEAD请求检查图片URL是否可访问
    final response = await http.head(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      // 如果图片可访问，返回带缓存的网络图片提供者
      CachedNetworkImageProvider cachedImageProvider =
          CachedNetworkImageProvider(imageUrl);
      return cachedImageProvider;
    } else {
      // 如果图片不可访问，返回占位图
      return AssetImage(placeholderUrl);
    }
  }
  // 如果URL为空，返回占位图
  return AssetImage(placeholderUrl);
}
