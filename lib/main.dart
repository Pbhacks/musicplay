import 'package:flutter/material.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart'; // Import for persistent storage

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidConfig = FlutterBackgroundAndroidConfig(
    notificationTitle: "Music Player",
    notificationText: "Playing music in background",
    notificationImportance: AndroidNotificationImportance.high,
    notificationIcon: AndroidResource(name: 'background_icon', defType: 'drawable'),
  );
  await FlutterBackground.initialize(androidConfig: androidConfig);
  await FlutterBackground.enableBackgroundExecution();

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system; // Default to system theme

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
      _saveThemeMode();
    });
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeMode = prefs.getString('themeMode') ?? 'system';
    setState(() {
      _themeMode = themeMode == 'light' ? ThemeMode.light : (themeMode == 'dark' ? ThemeMode.dark : ThemeMode.system);
    });
  }

  Future<void> _saveThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', _themeMode == ThemeMode.light ? 'light' : 'dark');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Music Player',
      theme: ThemeData.light().copyWith(
        primaryColor: Colors.white,
        scaffoldBackgroundColor: Colors.grey[200],
        appBarTheme: AppBarTheme(
          color: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        primaryColor: Colors.black,
        scaffoldBackgroundColor: Colors.grey[850],
        appBarTheme: AppBarTheme(
          color: Colors.black,
          iconTheme: IconThemeData(color: Colors.white),
        ),
      ),
      themeMode: _themeMode,
      home: HomePage(onToggleTheme: _toggleTheme),
    );
  }
}

class HomePage extends StatefulWidget {
  final VoidCallback onToggleTheme;

  HomePage({required this.onToggleTheme});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _searchController = TextEditingController();
  List<YoutubeVideo> _searchResults = [];
  bool _isSearching = false;

  Future<void> _searchYouTube(String query) async {
    setState(() {
      _isSearching = true;
    });

    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? 'YOUR_DEFAULT_API_KEY'; // Retrieve API key from persistent storage

    final url = 'https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=10&q=$query&type=video&key=$apiKey';
    final response = await http.get(Uri.parse(url));
    final jsonResponse = jsonDecode(response.body);

    setState(() {
      _searchResults = (jsonResponse['items'] as List)
          .map((item) => YoutubeVideo.fromJson(item))
          .toList();
      _isSearching = false;
    });
  }

  void _navigateToPlayer(YoutubeVideo video) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VideoPlayerPage(video: video),
      ),
    );
  }

  void clearSearchResults() {
    setState(() {
      _searchResults = [];
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Music Player'),
        actions: [
          IconButton(
            icon: Icon(Icons.brightness_6),
            onPressed: widget.onToggleTheme,
          ),
        ],
      ),
      drawer: CustomDrawer(), // Use the custom drawer widget
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search YouTube',
                suffixIcon: IconButton(
                  icon: Icon(Icons.search),
                  onPressed: () => _searchYouTube(_searchController.text),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isSearching
                ? Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final video = _searchResults[index];
                      return ListTile(
                        leading: Image.network(video.thumbnailUrl),
                        title: Text(video.title),
                        onTap: () => _navigateToPlayer(video),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class YoutubeVideo {
  final String id;
  final String title;
  final String thumbnailUrl;

  YoutubeVideo({required this.id, required this.title, required this.thumbnailUrl});

  factory YoutubeVideo.fromJson(Map<String, dynamic> json) {
    return YoutubeVideo(
      id: json['id']['videoId'],
      title: json['snippet']['title'],
      thumbnailUrl: json['snippet']['thumbnails']['default']['url'],
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final YoutubeVideo video;

  VideoPlayerPage({required this.video});

  @override
  _VideoPlayerPageState createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late YoutubePlayerController _controller;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();

    _controller = YoutubePlayerController(
      initialVideoId: widget.video.id,
      flags: YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        loop: false,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    FlutterBackground.disableBackgroundExecution();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _controller.play();
      } else {
        _controller.pause();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.video.title),
      ),
      body: Column(
        children: [
          Expanded(
            child: YoutubePlayer(
              controller: _controller,
              showVideoProgressIndicator: true,
              bottomActions: [
                CurrentPosition(),
                ProgressBar(isExpanded: true),
                PlaybackSpeedButton(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: Icon(Icons.skip_next),
                  onPressed: () {
                    // Logic to play the next video
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CustomDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.black,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Image.network(
                'https://images.stockcake.com/public/d/1/e/d1ef90ef-7bf7-466c-8af8-ded274aa978a_large/mountain-graphic-design-stockcake.jpg', // Unsplash image URL
                fit: BoxFit.cover,
              ),
              decoration: BoxDecoration(
                color: Colors.black,
              ),
            ),
            ListTile(
              title: Text(
                'Home',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            ListTile(
              title: Text(
                'Settings',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SettingsPage()),
                );
              },
            ),
            ListTile(
              title: Text(
                'Clear Main Page',
                style: TextStyle(color: Colors.white, fontSize: 16),
              ),
              onTap: () {
                Navigator.pop(context);
                final homePageState = context.findAncestorStateOfType<_HomePageState>();
                homePageState?.clearSearchResults();
              },
            ),
            // Add more items here
          ],
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _apiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    final apiKey = prefs.getString('apiKey') ?? '';
    _apiKeyController.text = apiKey;
  }

  Future<void> _saveApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('apiKey', _apiKeyController.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: 'YouTube API Key',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveApiKey,
              child: Text('Save API Key'),
            ),
          ],
        ),
      ),
    );
  }
}
