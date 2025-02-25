// This page contains the code to format the image url.
// it takes [imageURL, quality(low, medium, high)] and source as input and returns the formated image url.

/// 图片URL格式化工具类
/// 负责处理和格式化来自不同来源的图片URL
/// 支持YouTube、JioSaavn、Spotify等多个平台的图片URL格式化

/// 图片质量枚举
/// 定义了三种图片质量级别：低、中、高
enum ImageQuality { low, medium, high }

/// 图片来源枚举
/// 定义了支持的图片来源平台
enum ImageSource {
  /// YouTube平台
  yt,
  /// JioSaavn平台
  jiosaavn,
  /// Spotify平台
  spotify,
  /// Billboard平台
  billboard,
  /// Last.fm平台
  lastfm,
  /// Melon平台
  melon,
  /// 其他来源
  other,
}

/// 格式化图片URL
/// 根据图片来源和所需质量返回适当格式的URL
/// @param imgURL 原始图片URL
/// @param quality 目标图片质量
/// @return 返回格式化后的图片URL
String formatImgURL(String imgURL, ImageQuality quality) {
  ImageSource source;
  if (imgURL.contains('youtube') ||
      imgURL.contains('ytimg') ||
      imgURL.contains('googleusercontent')) {
    source = ImageSource.yt;
  } else if (imgURL.contains('saavn')) {
    source = ImageSource.jiosaavn;
  } else if (imgURL.contains('spotify')) {
    source = ImageSource.spotify;
  } else if (imgURL.contains('billboard')) {
    source = ImageSource.billboard;
  } else if (imgURL.contains('lastfm')) {
    source = ImageSource.lastfm;
  } else if (imgURL.contains('melon')) {
    source = ImageSource.melon;
  } else {
    source = ImageSource.other;
  }

  switch (source) {
    case ImageSource.yt:
      {
        return formatYtImgURL(imgURL, quality);
      }

    case ImageSource.jiosaavn:
      {
        switch (quality) {
          case ImageQuality.low:
            {
              return imgURL.replaceAll('500x500', '250x250');
            }
          case ImageQuality.medium:
            {
              return imgURL.replaceAll('500x500', '350x350');
            }
          case ImageQuality.high:
            {
              return imgURL;
            }
        }
      }
    case ImageSource.spotify:
      return imgURL;

    case ImageSource.billboard:
      {
        switch (quality) {
          case ImageQuality.low:
            {
              return imgURL.replaceAll('344x344', '180x180');
            }
          case ImageQuality.medium:
            {
              return imgURL.replaceAll('344x344', '344x344');
            }
          case ImageQuality.high:
            {
              return imgURL;
            }
        }
      }

    case ImageSource.lastfm:
      {
        switch (quality) {
          case ImageQuality.low:
            {
              return imgURL.replaceAll('500x500', 'avatar70s');
            }
          case ImageQuality.medium:
            {
              return imgURL;
            }
          case ImageQuality.high:
            {
              return imgURL;
            }
        }
      }

    case ImageSource.melon:
      {
        switch (quality) {
          case ImageQuality.low:
            {
              return imgURL.replaceAll(
                  'resize/350/quality', 'resize/250/quality');
            }
          case ImageQuality.medium:
            {
              return imgURL.replaceAll(
                  'resize/350/quality', 'resize/400/quality');
            }
          case ImageQuality.high:
            {
              return imgURL.replaceAll(
                  'resize/350/quality', 'resize/500/quality');
            }
        }
      }
    default:
      return imgURL;
  }
}

/// 格式化YouTube图片URL
/// 根据质量要求调整YouTube缩略图的尺寸
/// @param imgURL YouTube图片URL
/// @param quality 目标图片质量
/// @return 返回格式化后的YouTube图片URL
String formatYtImgURL(String imgURL, ImageQuality quality) {
  // types of urls for youtube and youtube music
  // https://i.ytimg.com/vi/VIDEO_ID/maxresdefault.jpg
  // https://i.ytimg.com/vi/VIDEO_ID/hqdefault.jpg
  // https://i.ytimg.com/vi/VIDEO_ID/mqdefault.jpg
  // https://i.ytimg.com/vi/VIDEO_ID/sddefault.jpg
  // https://i.ytimg.com/vi/VIDEO_ID/default.jpg
  // https://lh3.googleusercontent.com/{encryptedID}=w{width}-h{height}-l90-rj
  // https://img.youtube.com/vi/VIDEO_ID/{quality}.jpg

  if (imgURL.contains('mqdefault')) {
    imgURL = imgURL.replaceAll('mqdefault', 'maxresdefault');
  } else if (imgURL.contains('hqdefault')) {
    imgURL = imgURL.replaceAll('hqdefault', 'maxresdefault');
  } else if (imgURL.contains('sddefault')) {
    imgURL = imgURL.replaceAll('sddefault', 'maxresdefault');
  } else if (imgURL.contains('default')) {
    imgURL = imgURL.replaceAll('default', 'maxresdefault');
  }

  Pattern pattern = RegExp(r'w\d+-h\d+');

  switch (quality) {
    case ImageQuality.low:
      {
        return imgURL
            .replaceAll('maxresdefault', 'mqdefault')
            .replaceAll(pattern, 'w200-h200');
      }
    case ImageQuality.medium:
      {
        return imgURL
            .replaceAll('maxresdefault', 'sddefault')
            .replaceAll(pattern, 'w400-h400');
      }
    case ImageQuality.high:
      {
        return imgURL
            .replaceAll('maxresdefault', 'maxresdefault')
            .replaceAll(pattern, 'w600-h600');
      }
  }
}
