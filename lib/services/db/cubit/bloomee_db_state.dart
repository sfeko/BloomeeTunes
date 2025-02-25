part of 'bloomee_db_cubit.dart';

/// 媒体数据库状态基类
/// 用于表示数据库操作的不同状态
@immutable
sealed class MediadbState {}

/// 媒体数据库初始状态
/// 表示数据库刚刚初始化，尚未进行任何操作的状态
final class MediadbInitial extends MediadbState {}
