import 'package:flutter/material.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:ytdl_app/home.dart';

void main() {
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
    return MaterialApp(home: HomeApp());
  }
}
