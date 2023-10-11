import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ytdl_app/home.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  var status = await Permission.storage.status;
  if (status.isDenied) {
    await Permission.storage.request();
  }

  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  final TextEditingController urlController = TextEditingController();
  final yt = YoutubeExplode();
  final messengerKey = GlobalKey<ScaffoldMessengerState>();

  List<Map> videos = [];

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: HomeApp(), debugShowCheckedModeBanner: false);
  }
}
