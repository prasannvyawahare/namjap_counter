// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_settings.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserSettingsAdapter extends TypeAdapter<UserSettings> {
  @override
  final int typeId = 1;

  @override
  UserSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserSettings(
      name: fields[0] as String,
      dailyGoalCount: fields[1] as int,
      soundEnabled: fields[2] as bool,
      vibrationEnabled: fields[3] as bool,
      darkMode: fields[4] as bool,
      autoReset: fields[5] as bool,
      onboarded: fields[6] as bool,
      activeDate: fields[7] as String?,
      dndWhileCounting: fields[8] as bool,
      reminderEnabled: fields[9] as bool,
      reminderHour: fields[10] as int,
      reminderMinute: fields[11] as int,
      keepScreenAwake: fields[12] == null ? true : fields[12] as bool,
      progressNotificationEnabled:
          fields[13] == null ? true : fields[13] as bool,
      dismissNotificationOnGoalComplete:
          fields[14] == null ? false : fields[14] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, UserSettings obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.dailyGoalCount)
      ..writeByte(2)
      ..write(obj.soundEnabled)
      ..writeByte(3)
      ..write(obj.vibrationEnabled)
      ..writeByte(4)
      ..write(obj.darkMode)
      ..writeByte(5)
      ..write(obj.autoReset)
      ..writeByte(6)
      ..write(obj.onboarded)
      ..writeByte(7)
      ..write(obj.activeDate)
      ..writeByte(8)
      ..write(obj.dndWhileCounting)
      ..writeByte(9)
      ..write(obj.reminderEnabled)
      ..writeByte(10)
      ..write(obj.reminderHour)
      ..writeByte(11)
      ..write(obj.reminderMinute)
      ..writeByte(12)
      ..write(obj.keepScreenAwake)
      ..writeByte(13)
      ..write(obj.progressNotificationEnabled)
      ..writeByte(14)
      ..write(obj.dismissNotificationOnGoalComplete);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
