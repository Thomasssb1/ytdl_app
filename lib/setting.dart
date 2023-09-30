import 'package:hive/hive.dart';
import 'dart:io';

@HiveType(typeId: 0)
class Setting extends HiveObject {
  Setting({required installDirectory});

  @HiveField(0)
  Directory? installDirectory;

  @HiveField(1)
  bool lightMode = true;

  void setInstallDirectory(String directory) {
    installDirectory = Directory(directory);
  }
}
