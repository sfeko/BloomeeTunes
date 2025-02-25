/// 计时器工具类
/// 提供倒计时和定时器功能
/// 支持秒级计时和时分秒格式的计时

/// 计时器类
/// 提供基于Stream的计时功能
class Ticker {
  const Ticker();

  /// 基础计时器
  /// 每秒触发一次，倒计时指定的秒数
  /// @param ticks 需要倒计时的秒数
  /// @return 返回一个Stream，每秒发出剩余秒数
  Stream<int> tick({required int ticks}) {
    return Stream.periodic(const Duration(seconds: 1), (x) => ticks - x - 1)
        .take(ticks);
  }

  /// 时分秒格式计时器
  /// 将时分秒转换为总秒数进行倒计时
  /// @param hours 小时数
  /// @param minutes 分钟数
  /// @param seconds 秒数
  /// @param onTick 计时回调函数
  /// @return 返回一个Stream，每秒发出剩余秒数
  Stream<int> tickHMS(
      {required int hours,
      required int minutes,
      required int seconds,
      required Function(int) onTick}) {
    final totalSeconds = (hours * 3600) + (minutes * 60) + seconds;
    return tick(ticks: totalSeconds);
  }
}
