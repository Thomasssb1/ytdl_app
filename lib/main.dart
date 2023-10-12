import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ytdl_app/home.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:resize/resize.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('settings');
  var status = await Permission.storage.status;
  if (status.isDenied) {
    await Permission.storage.request();
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]).then((value) => runApp(MainApp()));
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
    return Resize(
        size: const Size(392.72727272727275, 803.6363636363636),
        builder: () {
          return const MaterialApp(home: HomeApp(), debugShowCheckedModeBanner: false);
        });
  }
}
