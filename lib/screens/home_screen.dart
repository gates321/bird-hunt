import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import 'game_screen.dart';
import '../services/ad_service.dart';

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
  
  // Coins system
  int coins = 0;
  
  // Power-up inventory (consumables)
  int slowMoCount = 0;
  int buckshotCount = 0;
  bool hasConfetti = false; // Permanent unlock
  
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
      
      // Load coins and power-ups
      coins = prefs.getInt('coins') ?? 0;
      slowMoCount = prefs.getInt('slowMoCount') ?? 0;
      buckshotCount = prefs.getInt('buckshotCount') ?? 0;
      hasConfetti = prefs.getBool('hasConfetti') ?? false;
      
      final lbJson = prefs.getString('leaderboard');
      if (lbJson != null) {
        leaderboard = (jsonDecode(lbJson) as List).map((e) => LeaderboardEntry.fromJson(e)).toList();
      }
    });
  }
  
  Future<void> _saveCoinsAndPowerUps() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('coins', coins);
    await prefs.setInt('slowMoCount', slowMoCount);
    await prefs.setInt('buckshotCount', buckshotCount);
    await prefs.setBool('hasConfetti', hasConfetti);
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

  void _showShop() {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with coins
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('🛒 Shop', style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontSize: 22, fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Text('🪙', style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 4),
                        Text('$coins', style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Power-ups section
              Text('⚡ Power-ups', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 14)),
              const SizedBox(height: 12),
              
              // Slow-Mo
              _shopItem(
                emoji: '🐌',
                name: 'Slow-Mo',
                desc: 'Birds move 50% slower for 5 sec',
                price: 50,
                owned: slowMoCount,
                onBuy: () {
                  if (coins >= 50) {
                    setState(() { coins -= 50; slowMoCount++; });
                    setModalState(() {});
                    _saveCoinsAndPowerUps();
                  }
                },
              ),
              const SizedBox(height: 10),
              
              // Buckshot
              _shopItem(
                emoji: '💥',
                name: 'Buckshot',
                desc: 'Hit multiple birds with one shot',
                price: 75,
                owned: buckshotCount,
                onBuy: () {
                  if (coins >= 75) {
                    setState(() { coins -= 75; buckshotCount++; });
                    setModalState(() {});
                    _saveCoinsAndPowerUps();
                  }
                },
              ),
              const SizedBox(height: 10),
              
              // Mystery Box
              _shopItem(
                emoji: '🎁',
                name: 'Mystery Box',
                desc: 'Random reward (10-200 coins!)',
                price: 100,
                owned: -1, // -1 means don't show owned count
                onBuy: () {
                  if (coins >= 100) {
                    setState(() => coins -= 100);
                    setModalState(() {});
                    _saveCoinsAndPowerUps();
                    Navigator.pop(context);
                    _openMysteryBox();
                  }
                },
              ),
              const SizedBox(height: 10),
              
              // Confetti (permanent unlock)
              if (!hasConfetti)
                _shopItem(
                  emoji: '🎊',
                  name: 'Confetti Kill',
                  desc: 'Birds explode in confetti (permanent)',
                  price: 150,
                  owned: -1,
                  onBuy: () {
                    if (coins >= 150) {
                      setState(() { coins -= 150; hasConfetti = true; });
                      setModalState(() {});
                      _saveCoinsAndPowerUps();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('🎊 Confetti unlocked!'), backgroundColor: Colors.green),
                      );
                    }
                  },
                ),
              if (hasConfetti)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Text('🎊', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 12),
                      Text('Confetti Kill', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      Spacer(),
                      Text('✓ OWNED', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              
              const SizedBox(height: 20),
              
              // Remove Ads (if not removed)
              if (!AdService().adsRemoved)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Text('🚫', style: TextStyle(fontSize: 28)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Remove Ads', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                            Text('No interruptions!', style: TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);
                          await IAPService().buyRemoveAds();
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.green.shade700),
                        child: const Text('\$2.99', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  await IAPService().restorePurchases();
                  Navigator.pop(context);
                },
                child: Text('Restore Purchases', style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _shopItem({
    required String emoji,
    required String name,
    required String desc,
    required int price,
    required int owned,
    required VoidCallback onBuy,
  }) {
    final canAfford = coins >= price;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDarkMode ? Colors.white12 : Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
                    if (owned > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('x$owned', style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ],
                ),
                Text(desc, style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 11)),
              ],
            ),
          ),
          GestureDetector(
            onTap: canAfford ? onBuy : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: canAfford ? Colors.amber : Colors.grey,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Text('🪙', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text('$price', style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _openMysteryBox() {
    final rewards = [10, 20, 30, 50, 75, 100, 150, 200];
    final weights = [25, 20, 18, 15, 10, 7, 4, 1]; // Lower = rarer
    
    // Weighted random selection
    final totalWeight = weights.reduce((a, b) => a + b);
    var roll = random.nextInt(totalWeight);
    int reward = rewards[0];
    for (int i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) {
        reward = rewards[i];
        break;
      }
    }
    
    setState(() => coins += reward);
    _saveCoinsAndPowerUps();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDarkMode ? const Color(0xFF1a1a2e) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎁', style: TextStyle(fontSize: 60)),
            const SizedBox(height: 16),
            Text('You won!', style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🪙', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 8),
                Text('$reward', style: TextStyle(color: Colors.amber, fontSize: 36, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              reward >= 100 ? '🎉 LUCKY!' : reward >= 50 ? '👍 Nice!' : '😊 Thanks!',
              style: TextStyle(color: isDarkMode ? Colors.white54 : Colors.black45),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }
  
  final random = Random();

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
                      // Coins display
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Text('🪙', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text('$coins', style: TextStyle(color: isDarkMode ? Colors.amber : Colors.orange, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      _iconBtn('🏆', _showLeaderboard),
                      _iconBtn(guns[selectedGun]['emoji'], _showGuns),
                      _iconBtn(isDarkMode ? '🌙' : '☀️', () async { setState(() => isDarkMode = !isDarkMode); (await SharedPreferences.getInstance()).setBool('isDarkMode', isDarkMode); }),
                      _iconBtn('📊', _showStats),
                      _iconBtn('🛒', _showShop),
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
    
    // Store current power-ups for this game session
    final gameSlowMo = slowMoCount;
    final gameBuckshot = buckshotCount;
    
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
        slowMoCount: gameSlowMo,
        buckshotCount: gameBuckshot,
        hasConfetti: hasConfetti,
        onGameEnd: (score, hits, shots, usedSlowMo, usedBuckshot) async {
          final prefs = await SharedPreferences.getInstance();
          gamesPlayed++;
          totalBirdsHit += hits;
          totalShots += shots;
          
          // Earn coins: 2 per bird + 20 per level completed (score/100 estimate)
          final earnedCoins = (hits * 2) + ((score ~/ 500) * 20);
          coins += earnedCoins;
          
          // Update power-up counts based on what was used
          slowMoCount -= usedSlowMo;
          buckshotCount -= usedBuckshot;
          if (slowMoCount < 0) slowMoCount = 0;
          if (buckshotCount < 0) buckshotCount = 0;
          
          if (score > highScore) { highScore = score; await prefs.setInt('highScore', score); }
          await prefs.setInt('gamesPlayed', gamesPlayed);
          await prefs.setInt('totalBirdsHit', totalBirdsHit);
          await prefs.setInt('totalShots', totalShots);
          await _saveCoinsAndPowerUps();
          if (score > 0) await _addToLeaderboard(score, '${gameTypes[selectedGameType]!['name']}');
          setState(() {});
        },
      ),
    ));
  }
}
