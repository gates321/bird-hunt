import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'game_screen.dart';

class BirdType {
  final String emoji;
  final String name;
  final int points;
  BirdType(this.emoji, this.name, this.points);
}

class LeaderboardEntry {
  final int score;
  final String date;
  final String mode;
  final String playerName;
  
  LeaderboardEntry({required this.score, required this.date, required this.mode, required this.playerName});
  
  Map<String, dynamic> toJson() => {'score': score, 'date': date, 'mode': mode, 'playerName': playerName};
  
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) => LeaderboardEntry(
    score: json['score'], date: json['date'], mode: json['mode'], playerName: json['playerName'],
  );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  String selectedMode = 'duck';
  String selectedGameType = 'classic';
  late AnimationController _pulseController;
  
  String playerName = 'Guest';
  String playerAvatar = '🎯';
  int highScore = 0;
  int gamesPlayed = 0;
  int totalBirdsHit = 0;
  int totalShots = 0;
  int selectedGun = 0;
  bool isDarkMode = true;
  
  List<Map<String, dynamic>> guns = [
    {'name': 'Shotgun', 'emoji': '🔫', 'unlock': 0},
    {'name': 'Rifle', 'emoji': '🎯', 'unlock': 100},
    {'name': 'Sniper', 'emoji': '🔭', 'unlock': 300},
    {'name': 'Golden', 'emoji': '⭐', 'unlock': 500},
  ];
  
  List<LeaderboardEntry> leaderboard = [];
  Set<String> selectedBirds = {'mallard', 'goose', 'swan', 'coot', 'moorhen', 'heron', 'custom'};

  final Map<String, BirdType> birdModes = {
    'duck': BirdType('🦆', 'Duck', 30),
    'random': BirdType('🐦', 'Random', 30),
    'custom': BirdType('🎯', 'Custom', 30),
  };
  
  final Map<String, Map<String, dynamic>> gameTypes = {
    'classic': {'name': 'Classic', 'emoji': '🎮', 'desc': '10 levels, 30 birds'},
    'speedrun': {'name': 'Speed Run', 'emoji': '🏃', 'desc': 'Hit 100 birds fast!'},
    'boss': {'name': 'Boss Hunt', 'emoji': '🎪', 'desc': 'Giant boss birds!'},
  };
  
  final Map<String, Map<String, dynamic>> allBirds = {
    'mallard': {'name': 'Mallard', 'emoji': '🦆'},
    'goose': {'name': 'Goose', 'emoji': '🪿'},
    'swan': {'name': 'Swan', 'emoji': '🦢'},
    'coot': {'name': 'Coot', 'emoji': '🐧'},
    'moorhen': {'name': 'Moorhen', 'emoji': '🐓'},
    'heron': {'name': 'Heron', 'emoji': '🦩'},
    'custom': {'name': 'Colorful', 'emoji': '🐤'},
  };

  @override
  void initState() {
    super.initState();
    _loadData();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      playerName = prefs.getString('playerName') ?? 'Guest';
      playerAvatar = prefs.getString('playerAvatar') ?? '🎯';
      highScore = prefs.getInt('highScore') ?? 0;
      gamesPlayed = prefs.getInt('gamesPlayed') ?? 0;
      totalBirdsHit = prefs.getInt('totalBirdsHit') ?? 0;
      totalShots = prefs.getInt('totalShots') ?? 0;
      selectedGun = prefs.getInt('selectedGun') ?? 0;
      isDarkMode = prefs.getBool('isDarkMode') ?? true;
      final lbJson = prefs.getString('leaderboard');
      if (lbJson != null) {
        leaderboard = (jsonDecode(lbJson) as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
      }
    });
  }

  Future<void> _addToLeaderboard(int score, String mode) async {
    leaderboard.add(LeaderboardEntry(score: score, date: DateTime.now().toString().substring(0, 10), mode: mode, playerName: playerName));
    leaderboard.sort((a, b) => b.score.compareTo(a.score));
    if (leaderboard.length > 10) leaderboard = leaderboard.sublist(0, 10);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('leaderboard', jsonEncode(leaderboard.map((e) => e.toJson()).toList()));
  }

  void _showLeaderboard() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🏆 Leaderboard', style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (leaderboard.isEmpty)
              Text('No scores yet!', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45))
            else
              SizedBox(
                height: 280,
                child: ListView.builder(
                  itemCount: leaderboard.length,
                  itemBuilder: (context, i) {
                    final e = leaderboard[i];
                    final medal = i == 0 ? '🥇' : i == 1 ? '🥈' : i == 2 ? '🥉' : '${i + 1}.';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Text(medal, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 12),
                          Expanded(child: Text(e.playerName, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold))),
                          Text('${e.score}', style: TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showGuns() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🔫 Arsenal', style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontSize: 22, fontWeight: FontWeight.bold)),
              Text('Birds hit: $totalBirdsHit', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45, fontSize: 12)),
              const SizedBox(height: 16),
              ...guns.asMap().entries.map((entry) {
                final i = entry.key;
                final gun = entry.value;
                final unlocked = totalBirdsHit >= gun['unlock'];
                final selected = selectedGun == i;
                return GestureDetector(
                  onTap: unlocked ? () async {
                    setModalState(() => selectedGun = i);
                    setState(() {});
                    (await SharedPreferences.getInstance()).setInt('selectedGun', i);
                  } : null,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? Colors.amber.withOpacity(0.2) : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: selected ? Colors.amber : Colors.transparent, width: 2),
                    ),
                    child: Row(
                      children: [
                        Text(unlocked ? gun['emoji'] : '🔒', style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(gun['name'], style: TextStyle(color: unlocked ? (isDarkMode ? Colors.white : Colors.black87) : Colors.grey, fontWeight: FontWeight.bold))),
                        if (!unlocked) Text('${gun['unlock'] - totalBirdsHit} more', style: const TextStyle(color: Colors.orange, fontSize: 12)),
                        if (selected) const Icon(Icons.check_circle, color: Colors.amber),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  void _showProfile() {
    final ctrl = TextEditingController(text: playerName == 'Guest' ? '' : playerName);
    String tempAvatar = playerAvatar;
    final avatars = ['🎯', '🦅', '🏆', '⭐', '🔥', '💪', '🎮', '👤'];
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(left: 20, right: 20, top: 20, bottom: MediaQuery.of(context).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Profile', style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                children: avatars.map((a) => GestureDetector(
                  onTap: () => setModalState(() => tempAvatar = a),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: tempAvatar == a ? Colors.amber.withOpacity(0.3) : (isDarkMode ? Colors.white10 : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: tempAvatar == a ? Colors.amber : Colors.transparent, width: 2),
                    ),
                    child: Text(a, style: const TextStyle(fontSize: 28)),
                  ),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                style: TextStyle(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  setState(() { playerName = ctrl.text.isEmpty ? 'Guest' : ctrl.text; playerAvatar = tempAvatar; });
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('playerName', playerName);
                  await prefs.setString('playerAvatar', playerAvatar);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showStats() {
    final acc = totalShots > 0 ? (totalBirdsHit / totalShots * 100).round() : 0;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📊 Stats', style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _stat('🏆', 'Best', '$highScore'),
              _stat('🎮', 'Games', '$gamesPlayed'),
            ]),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              _stat('🎯', 'Birds', '$totalBirdsHit'),
              _stat('💯', 'Accuracy', '$acc%'),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _stat(String emoji, String label, String value) => Container(
    width: 130,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: isDarkMode ? Colors.white10 : Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
    child: Column(children: [
      Text(emoji, style: const TextStyle(fontSize: 26)),
      Text(value, style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 11)),
    ]),
  );

  void _showBirds() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Select Birds', style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: allBirds.entries.map((e) {
                  final sel = selectedBirds.contains(e.key);
                  return GestureDetector(
                    onTap: () { setModalState(() { if (sel && selectedBirds.length > 1) selectedBirds.remove(e.key); else selectedBirds.add(e.key); }); setState(() {}); },
                    child: Container(
                      width: 80,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: sel ? Colors.amber.withOpacity(0.2) : (isDarkMode ? Colors.white10 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? Colors.amber : Colors.transparent, width: 2),
                      ),
                      child: Column(children: [
                        Text(e.value['emoji'], style: const TextStyle(fontSize: 22)),
                        Text(e.value['name'], style: TextStyle(fontSize: 9, color: isDarkMode ? Colors.white70 : Colors.black87)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black), child: const Text('Done')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: isDarkMode ? [const Color(0xFF0a0a1a), const Color(0xFF1a1a3a), const Color(0xFF0a1510)] : [const Color(0xFF87CEEB), const Color(0xFFB0E0E6), const Color(0xFF98FB98)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: _showProfile,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: isDarkMode ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(20)),
                        child: Row(children: [
                          Text(playerAvatar, style: const TextStyle(fontSize: 18)),
                          const SizedBox(width: 6),
                          Text(playerName.length > 8 ? '${playerName.substring(0, 8)}...' : playerName, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 13)),
                        ]),
                      ),
                    ),
                    Row(children: [
                      _iconBtn('🏆', _showLeaderboard),
                      _iconBtn(guns[selectedGun]['emoji'], _showGuns),
                      _iconBtn(isDarkMode ? '🌙' : '☀️', () async { setState(() => isDarkMode = !isDarkMode); (await SharedPreferences.getInstance()).setBool('isDarkMode', isDarkMode); }),
                      _iconBtn('📊', _showStats),
                    ]),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      const Text('🎯', style: TextStyle(fontSize: 50)),
                      ShaderMask(
                        shaderCallback: (b) => LinearGradient(colors: isDarkMode ? [Colors.amber, Colors.orange] : [Colors.orange, Colors.red]).createShader(b),
                        child: const Text('BIRD HUNT', style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 4)),
                      ),
                      Text('High Score: $highScore', style: TextStyle(color: isDarkMode ? Colors.amber.withOpacity(0.7) : Colors.orange, fontSize: 13)),
                      
                      const SizedBox(height: 20),
                      Text('Game Mode', style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: gameTypes.entries.map((e) {
                          final sel = selectedGameType == e.key;
                          return GestureDetector(
                            onTap: () => setState(() => selectedGameType = e.key),
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: sel ? Colors.amber.withOpacity(0.25) : (isDarkMode ? Colors.white10 : Colors.black12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sel ? Colors.amber : Colors.transparent, width: 2),
                              ),
                              child: Column(children: [
                                Text(e.value['emoji'], style: const TextStyle(fontSize: 24)),
                                Text(e.value['name'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                      Text(gameTypes[selectedGameType]!['desc'], style: TextStyle(fontSize: 11, color: isDarkMode ? Colors.white38 : Colors.black38)),
                      
                      const SizedBox(height: 16),
                      Text('Target', style: TextStyle(fontSize: 14, color: isDarkMode ? Colors.white70 : Colors.black54)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: birdModes.entries.map((e) {
                          final sel = selectedMode == e.key;
                          return GestureDetector(
                            onTap: () { setState(() => selectedMode = e.key); if (e.key == 'custom') _showBirds(); },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: sel ? Colors.amber.withOpacity(0.25) : (isDarkMode ? Colors.white10 : Colors.black12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: sel ? Colors.amber : Colors.transparent, width: 2),
                              ),
                              child: Column(children: [
                                Text(e.value.emoji, style: const TextStyle(fontSize: 28)),
                                Text(e.value.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black87)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                      
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) => Transform.scale(scale: 1 + (_pulseController.value * 0.05), child: child),
                        child: ElevatedButton(
                          onPressed: () => _startGame(context),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.amber, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          child: const Text('START HUNT', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2)),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconBtn(String emoji, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: isDarkMode ? Colors.white10 : Colors.black12, borderRadius: BorderRadius.circular(12)),
      child: Text(emoji, style: const TextStyle(fontSize: 18)),
    ),
  );

  void _startGame(BuildContext context) {
    List<int> birdStyles = selectedMode == 'duck' ? [1] : selectedMode == 'random' ? [0, 1, 2, 3, 4, 5, 6] : selectedBirds.map((b) => {'custom': 0, 'mallard': 1, 'goose': 2, 'swan': 3, 'coot': 4, 'moorhen': 5, 'heron': 6}[b]!).toList();
    
    // Gun stats
    final gunStats = [
      {'ammo': 5, 'damage': 1.0, 'name': 'Shotgun'},
      {'ammo': 8, 'damage': 1.2, 'name': 'Rifle'},
      {'ammo': 3, 'damage': 2.0, 'name': 'Sniper'},
      {'ammo': 6, 'damage': 1.5, 'name': 'Golden Gun'},
    ];
    final gun = gunStats[selectedGun];
    
    Navigator.push(context, MaterialPageRoute(
      builder: (context) => GameScreen(
        birdType: birdModes[selectedMode]!,
        birdStyles: birdStyles,
        isDarkMode: isDarkMode,
        playerName: playerName,
        playerAvatar: playerAvatar,
        gunAmmo: gun['ammo'] as int,
        gunDamage: gun['damage'] as double,
        gunName: gun['name'] as String,
        isSpeedRun: selectedGameType == 'speedrun',
        bossEnabled: selectedGameType == 'boss',
        onGameEnd: (score, hits, shots) async {
          final prefs = await SharedPreferences.getInstance();
          gamesPlayed++;
          totalBirdsHit += hits;
          totalShots += shots;
          if (score > highScore) { highScore = score; await prefs.setInt('highScore', score); }
          await prefs.setInt('gamesPlayed', gamesPlayed);
          await prefs.setInt('totalBirdsHit', totalBirdsHit);
          await prefs.setInt('totalShots', totalShots);
          if (score > 0) await _addToLeaderboard(score, '${gameTypes[selectedGameType]!['name']}');
          setState(() {});
        },
      ),
    ));
  }
}
