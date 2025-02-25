/// 字符串扩展工具类
/// 提供了一系列字符串处理的扩展方法
/// 包括首字母大写、数字检查、HTML转义、时间格式化等功能

/// 字符串扩展类
extension StringExtension on String {
  /// 将字符串的首字母转换为大写
  /// @return 返回首字母大写的字符串
  String capitalize() {
    if (this != '') {
      return '${this[0].toUpperCase()}${substring(1)}';
    } else {
      return '';
    }
  }

  /// 检查字符串是否为数字
  /// @return 如果字符串可以转换为数字则返回true
  bool isNumeric() {
    return double.tryParse(this) != null;
  }

  /// 解除HTML转义
  /// 将HTML实体转换回原始字符
  /// @return 返回解除转义后的字符串
  String unescape() {
    return replaceAll('&amp;', '&')
        .replaceAll('&#039;', "'")
        .replaceAll('&quot;', '"')
        .trim();
  }

  /// 将秒数格式化为HH:MM:SS格式
  /// @return 返回格式化后的时间字符串
  String formatToHHMMSS() {
    final int? time = int.tryParse(this);
    if (time != null) {
      final int hours = time ~/ 3600;
      final int seconds = time % 3600;
      final int minutes = seconds ~/ 60;

      final String hoursStr = hours.toString().padLeft(2, '0');
      final String minutesStr = minutes.toString().padLeft(2, '0');
      final String secondsStr = (seconds % 60).toString().padLeft(2, '0');

      if (hours == 0) {
        return '$minutesStr:$secondsStr';
      }
      return '$hoursStr:$minutesStr:$secondsStr';
    } else {
      return '';
    }
  }

  /// 从Unix时间戳获取年份
  String get yearFromEpoch =>
      DateTime.fromMillisecondsSinceEpoch(int.parse(this) * 1000)
          .year
          .toString();

  /// 从Unix时间戳获取完整日期
  /// @return 返回格式化的日期字符串 (DD/MM/YYYY)
  String get dateFromEpoch {
    final time = DateTime.fromMillisecondsSinceEpoch(int.parse(this) * 1000);
    return '${time.day}/${time.month}/${time.year}';
  }
}

extension DateTimeExtension on int {
  String formatToHHMMSS() {
    if (this != 0) {
      final int hours = this ~/ 3600;
      final int seconds = this % 3600;
      final int minutes = seconds ~/ 60;

      final String hoursStr = hours.toString().padLeft(2, '0');
      final String minutesStr = minutes.toString().padLeft(2, '0');
      final String secondsStr = (seconds % 60).toString().padLeft(2, '0');

      if (hours == 0) {
        return '$minutesStr:$secondsStr';
      }
      return '$hoursStr:$minutesStr:$secondsStr';
    } else {
      return '';
    }
  }

  int get yearFromEpoch =>
      DateTime.fromMillisecondsSinceEpoch(this * 1000).year;
}
