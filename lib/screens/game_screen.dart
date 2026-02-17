import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'home_screen.dart';

class GameScreen extends StatefulWidget {
  final BirdType birdType;
  final List<int> birdStyles;
  final bool isDarkMode;
  final String playerName;
  final String playerAvatar;
  final int gunAmmo;
  final double gunDamage;
  final String gunName;
  final bool isSpeedRun;
  final bool bossEnabled;
  final Function(int, int, int) onGameEnd;

  const GameScreen({
    super.key,
    required this.birdType,
    required this.birdStyles,
    required this.isDarkMode,
    required this.playerName,
    required this.playerAvatar,
    required this.gunAmmo,
    required this.gunDamage,
    required this.gunName,
    required this.isSpeedRun,
    required this.bossEnabled,
    required this.onGameEnd,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  int score = 0;
  int hits = 0;
  int shots = 0;
  int timeLeft = 30;
  int timeElapsed = 0; // For speed run
  late int ammo;
  late int maxAmmo;
  bool isReloading = false;
  int currentLevel = 1;
  final int maxLevel = 10;
  bool gameRunning = false;
  bool showLevelComplete = false;
  bool showGameOver = false;
  bool canShoot = true;
  
  // 30 birds per level for ALL modes
  int birdsSpawned = 0;
  int birdsPerLevel = 30;
  int totalBirdsTarget = 100; // For speed run

  // 10 levels
  final List<double> levelSpeeds = [1.0, 1.2, 1.4, 1.6, 1.8, 2.0, 2.3, 2.6, 3.0, 3.5];
  final int levelTime = 30;

  List<Bird> birds = [];
  final Random random = Random();

  Timer? gameTimer;
  Timer? spawnTimer;
  Timer? frameTimer;

  List<HitIndicator> hitIndicators = [];
  bool showMuzzleFlash = false;
  double gunRecoil = 0;
  
  AudioPlayer? _audioPlayer;
  AudioPlayer? _hitPlayer;
  
  late AnimationController _levelCompleteController;
  late Animation<double> _scaleAnimation;

  bool get hasScope => currentLevel > 1;

  @override
  void initState() {
    super.initState();
    
    // Set gun ammo from widget
    maxAmmo = widget.gunAmmo;
    ammo = maxAmmo;
    
    _levelCompleteController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _levelCompleteController, curve: Curves.elasticOut),
    );
    
    _initAudio();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startLevel());
  }

  Future<void> _initAudio() async {
    _audioPlayer = AudioPlayer();
    _hitPlayer = AudioPlayer();
    await _audioPlayer?.setVolume(1.0);
    await _hitPlayer?.setVolume(1.0);
    await _audioPlayer?.setPlayerMode(PlayerMode.lowLatency);
    await _hitPlayer?.setPlayerMode(PlayerMode.lowLatency);
  }

  @override
  void dispose() {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    frameTimer?.cancel();
    _levelCompleteController.dispose();
    _audioPlayer?.dispose();
    _hitPlayer?.dispose();
    super.dispose();
  }

  Future<void> _playShootSound() async {
    HapticFeedback.heavyImpact();
    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.play(AssetSource('audio/shoot.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint('Sound error: $e');
    }
  }

  Future<void> _playHitSound() async {
    HapticFeedback.mediumImpact();
    try {
      await _hitPlayer?.stop();
      await _hitPlayer?.play(AssetSource('audio/hit.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint('Hit sound error: $e');
    }
  }

  void _startLevel() {
    birdsSpawned = 0;
    ammo = maxAmmo;
    birds.clear();
    hitIndicators.clear();
    gameRunning = true;
    canShoot = true;
    showLevelComplete = false;
    isReloading = false;
    
    if (widget.isSpeedRun) {
      // Speed run: timer counts up, spawn birds continuously
      timeElapsed = 0;
      birdsPerLevel = totalBirdsTarget;
    } else {
      timeLeft = levelTime;
      birdsPerLevel = 30;
    }
    
    if (mounted) setState(() {});

    gameTimer?.cancel();
    gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!gameRunning) return;
      
      if (widget.isSpeedRun) {
        timeElapsed++;
        if (mounted) setState(() {});
      } else {
        timeLeft--;
        if (timeLeft <= 0) {
          _endLevel();
        } else {
          if (mounted) setState(() {});
        }
      }
    });

    // Spawn birds
    final spawnInterval = widget.isSpeedRun ? 400 : (levelTime * 1000 / birdsPerLevel).round();
    spawnTimer?.cancel();
    spawnTimer = Timer.periodic(Duration(milliseconds: spawnInterval), (timer) {
      if (!gameRunning || birdsSpawned >= birdsPerLevel) return;
      _spawnBird();
      
      // Spawn boss bird every 10 birds if enabled
      if (widget.bossEnabled && birdsSpawned % 10 == 0 && birdsSpawned > 0) {
        _spawnBossBird();
      }
    });

    frameTimer?.cancel();
    frameTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (gameRunning) _updateGame();
    });

    _spawnBird();
    Future.delayed(const Duration(milliseconds: 300), _spawnBird);
  }

  void _spawnBird() {
    if (!gameRunning || !mounted || birdsSpawned >= birdsPerLevel) return;
    birdsSpawned++;

    final size = MediaQuery.of(context).size;
    final fromLeft = random.nextBool();
    
    final startX = fromLeft ? -70.0 : size.width + 70;
    
    final minY = 60.0;
    final maxY = size.height - 200;
    double startY, targetY;
    if (random.nextDouble() < 0.7) {
      startY = minY + random.nextDouble() * ((maxY - minY) * 0.5);
      targetY = minY + random.nextDouble() * ((maxY - minY) * 0.6);
    } else {
      startY = minY + (maxY - minY) * 0.5 + random.nextDouble() * ((maxY - minY) * 0.5);
      targetY = minY + random.nextDouble() * (maxY - minY);
    }
    
    final baseSpeed = 1.5 + random.nextDouble() * 1.5;
    final speed = baseSpeed * levelSpeeds[currentLevel - 1] * (fromLeft ? 1 : -1);

    final colors = [
      Colors.brown.shade600,
      Colors.green.shade700,
      Colors.blue.shade700,
      Colors.red.shade700,
      Colors.purple.shade600,
      Colors.teal.shade600,
      Colors.orange.shade700,
    ];

    // Pick a random bird style from the allowed styles
    int birdStyle = widget.birdStyles[random.nextInt(widget.birdStyles.length)];

    birds.add(Bird(
      x: startX,
      y: startY,
      targetY: targetY,
      speed: speed,
      wobble: 0.5 + random.nextDouble(),
      wobblePhase: random.nextDouble() * 3.14 * 2,
      wingPhase: random.nextDouble() * 3.14 * 2,
      facingRight: fromLeft,
      color: colors[random.nextInt(colors.length)],
      birdStyle: birdStyle,
    ));
  }

  void _spawnBossBird() {
    if (!gameRunning || !mounted) return;

    final size = MediaQuery.of(context).size;
    final fromLeft = random.nextBool();
    
    final startX = fromLeft ? -120.0 : size.width + 120;
    final startY = 80.0 + random.nextDouble() * 150;
    final targetY = 100.0 + random.nextDouble() * 200;
    
    final baseSpeed = 0.8 + random.nextDouble() * 0.5; // Slower
    final speed = baseSpeed * levelSpeeds[currentLevel - 1] * (fromLeft ? 1 : -1);

    birds.add(Bird(
      x: startX,
      y: startY,
      targetY: targetY,
      speed: speed,
      wobble: 0.3,
      wobblePhase: random.nextDouble() * 3.14 * 2,
      wingPhase: random.nextDouble() * 3.14 * 2,
      facingRight: fromLeft,
      color: Colors.red.shade900,
      birdStyle: 0, // Custom drawn
      isBoss: true,
      health: 3, // Takes 3 hits
    ));
  }

  void _updateGame() {
    if (!mounted) return;

    final size = MediaQuery.of(context).size;
    bool needsUpdate = false;

    for (var bird in birds) {
      if (bird.dead) continue;
      bird.wobblePhase += 0.08;
      bird.wingPhase += 0.4;
      bird.x += bird.speed;
      final wobbleY = sin(bird.wobblePhase) * 12 * bird.wobble;
      bird.y += (bird.targetY - bird.y) * 0.008 + wobbleY * 0.08;
      needsUpdate = true;
    }

    birds.removeWhere((b) {
      if ((b.speed > 0 && b.x > size.width + 100) ||
          (b.speed < 0 && b.x < -100) ||
          (b.dead && b.deadTime > 25)) {
        return true;
      }
      return false;
    });

    for (var bird in birds) {
      if (bird.dead) bird.deadTime++;
    }

    hitIndicators.removeWhere((h) =>
        DateTime.now().difference(h.createdAt).inMilliseconds > 600);
        
    if (gunRecoil > 0) {
      gunRecoil = max(0, gunRecoil - 3);
      needsUpdate = true;
    }

    if (needsUpdate && mounted) {
      setState(() {});
    }
  }

  void _shoot(Offset position) {
    if (!gameRunning || !canShoot || ammo <= 0 || isReloading) return;

    _playShootSound();
    
    gunRecoil = 25;
    ammo--;
    shots++;
    showMuzzleFlash = true;
    
    if (mounted) setState(() {});

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) setState(() => showMuzzleFlash = false);
    });

    bool hitAny = false;
    for (var bird in birds) {
      if (bird.dead) continue;

      // Boss birds are bigger
      final birdSize = bird.isBoss ? 70.0 : 35.0;
      final birdCenter = Offset(bird.x + birdSize, bird.y + (bird.isBoss ? 50 : 25));
      final distance = (position - birdCenter).distance;
      final hitRadius = bird.isBoss ? 80.0 : 55.0;

      if (distance < hitRadius) {
        hitAny = true;
        
        // Apply damage (gun damage multiplier)
        bird.health -= widget.gunDamage.round();
        
        if (bird.health <= 0) {
          bird.dead = true;
          bird.deadTime = 0;
          hits++;
          
          _playHitSound();

          int points = bird.isBoss ? 100 : widget.birdType.points;
          String hitType = bird.isBoss ? 'boss' : 'good';

          if (!bird.isBoss) {
            if (distance < hitRadius * 0.3) {
              points *= 2;
              hitType = 'perfect';
            } else if (distance < hitRadius * 0.6) {
              points = (points * 1.5).round();
              hitType = 'great';
            }
          }

          score += points;

          hitIndicators.add(HitIndicator(
            x: position.dx,
            y: position.dy,
            points: points,
            type: hitType,
            createdAt: DateTime.now(),
          ));
          
          // Check for speed run completion
          if (widget.isSpeedRun && hits >= totalBirdsTarget) {
            _endSpeedRun();
          }
        } else {
          // Boss hit but not dead
          _playHitSound();
          hitIndicators.add(HitIndicator(
            x: position.dx,
            y: position.dy,
            points: 10,
            type: 'hit',
            createdAt: DateTime.now(),
          ));
          score += 10;
        }

        break;
      }
    }

    if (!hitAny) {
      score = max(0, score - 20);
      hitIndicators.add(HitIndicator(
        x: position.dx,
        y: position.dy,
        points: -20,
        type: 'miss',
        createdAt: DateTime.now(),
      ));
    }

    if (ammo == 0) {
      Future.delayed(const Duration(milliseconds: 400), _reload);
    }
  }
  
  void _endSpeedRun() {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    frameTimer?.cancel();
    
    HapticFeedback.vibrate();
    
    gameRunning = false;
    canShoot = false;
    
    // Bonus points for time (faster = more points)
    final timeBonus = max(0, 300 - timeElapsed) * 10;
    score += timeBonus;
    
    showGameOver = true;
    widget.onGameEnd(score, hits, shots);
    
    if (mounted) setState(() {});
  }

  void _reload() {
    if (isReloading || ammo == maxAmmo || !gameRunning) return;
    isReloading = true;
    if (mounted) setState(() {});

    Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (!mounted || !gameRunning) {
        timer.cancel();
        return;
      }
      ammo++;
      HapticFeedback.lightImpact();
      if (ammo >= maxAmmo) {
        timer.cancel();
        isReloading = false;
      }
      if (mounted) setState(() {});
    });
  }

  void _endLevel() {
    gameTimer?.cancel();
    spawnTimer?.cancel();
    frameTimer?.cancel();

    HapticFeedback.vibrate();

    gameRunning = false;
    canShoot = false;
    if (currentLevel < maxLevel) {
      showLevelComplete = true;
      _levelCompleteController.forward(from: 0);
    } else {
      showGameOver = true;
      widget.onGameEnd(score, hits, shots);
    }
    if (mounted) setState(() {});
  }

  void _nextLevel() {
    currentLevel++;
    showLevelComplete = false;
    canShoot = true;
    if (mounted) setState(() {});
    _startLevel();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Save stats when leaving mid-game
        widget.onGameEnd(score, hits, shots);
        return true;
      },
      child: Scaffold(
        body: GestureDetector(
          onTapDown: (details) => _shoot(details.globalPosition),
          child: Stack(
            children: [
            // Sky background - day or night
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: widget.isDarkMode
                      ? [
                          const Color(0xFF05051a),
                          const Color(0xFF0a0a2a),
                          const Color(0xFF151535),
                          const Color(0xFF1a2530),
                        ]
                      : [
                          const Color(0xFF87CEEB),
                          const Color(0xFFADD8E6),
                          const Color(0xFFB0E0E6),
                          const Color(0xFF98D8C8),
                        ],
                ),
              ),
            ),

            // Stars (only at night)
            if (widget.isDarkMode)
              CustomPaint(
                size: Size.infinite,
                painter: StarsPainter(),
              ),
            
            // Clouds (only during day)
            if (!widget.isDarkMode) ...[
              Positioned(top: 60, left: 30, child: _buildCloud(80)),
              Positioned(top: 100, right: 50, child: _buildCloud(100)),
              Positioned(top: 150, left: 150, child: _buildCloud(60)),
            ],

            // Moon (night) or Sun (day)
            Positioned(
              top: 80,
              right: 50,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: widget.isDarkMode
                        ? [const Color(0xFFFFFDE7), const Color(0xFFFFF59D), const Color(0xFFFDD835)]
                        : [const Color(0xFFFFFF00), const Color(0xFFFFD700), const Color(0xFFFFA500)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isDarkMode 
                          ? const Color(0xFFFFF9C4).withOpacity(0.4)
                          : Colors.yellow.withOpacity(0.5),
                      blurRadius: 30,
                      spreadRadius: 8,
                    ),
                  ],
                ),
              ),
            ),

            // Ground
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: widget.isDarkMode
                        ? [Colors.transparent, const Color(0xFF0a1208)]
                        : [Colors.transparent, const Color(0xFF228B22)],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 40, 
                color: widget.isDarkMode ? const Color(0xFF081a08) : const Color(0xFF1B5E20),
              ),
            ),

            // Birds
            ...birds.map(_buildBird),

            // Muzzle flash
            if (showMuzzleFlash)
              Positioned(
                bottom: 180,
                left: MediaQuery.of(context).size.width / 2 - 40,
                child: Container(
                  width: 80,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      colors: [
                        Colors.orange.withOpacity(0.9),
                        Colors.yellow.withOpacity(0.6),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

            // Hit indicators
            ...hitIndicators.map(_buildHitIndicator),

            // HUD at TOP
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          widget.onGameEnd(score, hits, shots);
                          Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        ),
                      ),
                      // Level or Speed Run indicator
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.isSpeedRun ? '⚡ SPEED' : 'Lv $currentLevel',
                          style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      // Birds counter
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.isSpeedRun 
                              ? '🎯 $hits/$totalBirdsTarget'
                              : '🐦 ${birdsPerLevel - birdsSpawned + birds.where((b) => !b.dead).length}',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                      Row(
                        children: [
                          _statBox('$score', 'Score'),
                          const SizedBox(width: 12),
                          _statBox(
                            widget.isSpeedRun ? _formatTime(timeElapsed) : '$timeLeft',
                            widget.isSpeedRun ? 'Time' : 'Time',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Shotgun with scope (scope added from level 2)
            Positioned(
              bottom: -20 + gunRecoil,
              left: 0,
              right: 0,
              child: Transform.rotate(
                angle: -gunRecoil * 0.008,
                alignment: Alignment.bottomCenter,
                child: CustomPaint(
                  size: Size(MediaQuery.of(context).size.width, 250),
                  painter: ShotgunPainter(hasScope: hasScope),
                ),
              ),
            ),

            // Ammo
            Positioned(
              bottom: 20,
              left: 16,
              child: Row(
                children: List.generate(maxAmmo, (i) {
                  return Container(
                    width: 10,
                    height: 32,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      gradient: i < ammo
                          ? const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0xFFFFD700), Color(0xFFB8860B)],
                            )
                          : null,
                      color: i < ammo ? null : Colors.white12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),

            if (isReloading)
              Positioned(
                bottom: 60,
                left: 16,
                child: Text(
                  'RELOADING...',
                  style: TextStyle(
                    color: Colors.amber.withOpacity(0.9),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),

            if (showLevelComplete) _buildLevelComplete(),
            if (showGameOver) _buildGameOver(),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildBird(Bird bird) {
    // Boss birds are rendered larger with health indicator
    if (bird.isBoss) {
      return Positioned(
        left: bird.x,
        top: bird.y,
        child: Opacity(
          opacity: bird.dead ? (1 - bird.deadTime / 25).clamp(0, 1).toDouble() : 1,
          child: Transform(
            transform: Matrix4.identity()
              ..scale(bird.facingRight ? 1.0 : -1.0, 1.0)
              ..rotateZ(bird.dead ? bird.deadTime * 0.12 : 0),
            alignment: Alignment.center,
            child: Stack(
              children: [
                CustomPaint(
                  size: const Size(120, 90), // Boss is bigger
                  painter: BossBirdPainter(wingPhase: bird.wingPhase),
                ),
                // Health bar
                if (!bird.dead)
                  Positioned(
                    top: -10,
                    left: 20,
                    child: Container(
                      width: 80,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: bird.health / 3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: bird.health > 1 ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    
    // Regular birds
    if (bird.birdStyle == 1) {
      // Duck emoji with bob animation
      final bobOffset = sin(bird.wingPhase * 0.5) * 3;
      return Positioned(
        left: bird.x,
        top: bird.y + bobOffset,
        child: Opacity(
          opacity: bird.dead ? (1 - bird.deadTime / 25).clamp(0, 1).toDouble() : 1,
          child: Transform(
            transform: Matrix4.identity()
              ..scale(bird.facingRight ? 1.0 : -1.0, 1.0)
              ..rotateZ(bird.dead ? bird.deadTime * 0.12 : sin(bird.wingPhase) * 0.1),
            alignment: Alignment.center,
            child: const Text('🦆', style: TextStyle(fontSize: 50)),
          ),
        ),
      );
    } else if (bird.birdStyle == 2) {
      // Goose emoji with bob animation
      final bobOffset = sin(bird.wingPhase * 0.5) * 3;
      return Positioned(
        left: bird.x,
        top: bird.y + bobOffset,
        child: Opacity(
          opacity: bird.dead ? (1 - bird.deadTime / 25).clamp(0, 1).toDouble() : 1,
          child: Transform(
            transform: Matrix4.identity()
              ..scale(bird.facingRight ? 1.0 : -1.0, 1.0)
              ..rotateZ(bird.dead ? bird.deadTime * 0.12 : sin(bird.wingPhase) * 0.1),
            alignment: Alignment.center,
            child: const Text('🪿', style: TextStyle(fontSize: 50)),
          ),
        ),
      );
    } else {
      // Custom drawn birds with flapping wings (styles 0, 3, 4, 5, 6)
      return Positioned(
        left: bird.x,
        top: bird.y,
        child: Opacity(
          opacity: bird.dead ? (1 - bird.deadTime / 25).clamp(0, 1).toDouble() : 1,
          child: Transform(
            transform: Matrix4.identity()
              ..scale(bird.facingRight ? 1.0 : -1.0, 1.0)
              ..rotateZ(bird.dead ? bird.deadTime * 0.12 : 0),
            alignment: Alignment.center,
            child: CustomPaint(
              size: bird.birdStyle == 6 ? const Size(50, 70) : const Size(70, 50),
              painter: _getBirdPainter(bird),
            ),
          ),
        ),
      );
    }
  }

  CustomPainter _getBirdPainter(Bird bird) {
    switch (bird.birdStyle) {
      case 3:
        return SwanPainter(wingPhase: bird.wingPhase);
      case 4:
        return CootPainter(wingPhase: bird.wingPhase);
      case 5:
        return MoorhenPainter(wingPhase: bird.wingPhase);
      case 6:
        return HeronPainter(wingPhase: bird.wingPhase);
      default:
        return BirdPainter(wingPhase: bird.wingPhase, color: bird.color);
    }
  }

  Widget _buildHitIndicator(HitIndicator h) {
    final age = DateTime.now().difference(h.createdAt).inMilliseconds;
    final progress = (age / 600).clamp(0.0, 1.0);
    final opacity = (1.0 - progress).clamp(0.0, 1.0);
    final yOffset = progress * 40;
    final scale = 1.0 + progress * 0.15;

    Color color;
    String text;
    double fontSize = 16;

    switch (h.type) {
      case 'perfect':
        color = Colors.amber;
        text = '🎯 +${h.points}';
        fontSize = 20;
        break;
      case 'great':
        color = Colors.greenAccent;
        text = '✨ +${h.points}';
        fontSize = 18;
        break;
      case 'miss':
        color = Colors.red;
        text = '-20';
        fontSize = 16;
        break;
      case 'boss':
        color = Colors.purple;
        text = '💀 +${h.points}';
        fontSize = 24;
        break;
      case 'hit':
        color = Colors.orange;
        text = '💥 +${h.points}';
        fontSize = 14;
        break;
      default:
        color = Colors.white;
        text = '+${h.points}';
    }

    return Positioned(
      left: h.x - 30,
      top: h.y - yOffset - 15,
      child: Transform.scale(
        scale: scale,
        child: Opacity(
          opacity: opacity,
          child: Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              shadows: const [Shadow(color: Colors.black, blurRadius: 4)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statBox(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: Colors.amber, fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 10)),
      ],
    );
  }

  Widget _buildCloud(double width) {
    return Container(
      width: width,
      height: width * 0.4,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(width * 0.25),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }

  String _formatTime(int seconds) {
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Widget _buildLevelComplete() {
    final messages = ['🔥 NICE!', '💪 GREAT!', '⭐ AWESOME!', '🏆 AMAZING!', '👑 LEGENDARY!', 
                      '🌟 SUPER!', '💥 INSANE!', '🎯 MASTER!', '⚡ EPIC!', '🔥 GODLIKE!'];
    
    return AnimatedBuilder(
      animation: _levelCompleteController,
      builder: (context, child) {
        return Container(
          color: Colors.black.withOpacity(0.85),
          child: Center(
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(messages[(currentLevel - 1) % messages.length], 
                       style: const TextStyle(color: Colors.amber, fontSize: 32, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Level $currentLevel Complete!', 
                       style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Text('Score: $score', style: const TextStyle(color: Colors.amber, fontSize: 20)),
                  if (currentLevel == 1)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text('🔭 Scope unlocked!', 
                             style: TextStyle(color: Colors.greenAccent, fontSize: 14)),
                    ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _nextLevel,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                    ),
                    child: const Text('NEXT LEVEL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameOver() {
    return Container(
      color: Colors.black.withOpacity(0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Player avatar and name
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.playerAvatar, style: const TextStyle(fontSize: 40)),
                const SizedBox(width: 12),
                Text(
                  widget.playerName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(widget.isSpeedRun ? '⚡' : '🏆', style: const TextStyle(fontSize: 50)),
            const SizedBox(height: 8),
            Text(
              widget.isSpeedRun ? 'SPEED RUN COMPLETE!' : 'HUNT COMPLETE!', 
              style: const TextStyle(color: Colors.amber, fontSize: 26, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Text('$score', style: const TextStyle(color: Colors.amber, fontSize: 50, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (widget.isSpeedRun)
              Text(
                'Time: ${_formatTime(timeElapsed)} • $hits birds',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              )
            else
              Text(
                '$hits hits • ${shots > 0 ? ((hits / shots) * 100).round() : 0}% accuracy',
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 14),
              ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
              ),
              child: const Text('PLAY AGAIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

// Stars painter
class StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    for (int i = 0; i < 50; i++) {
      final x = (i * 47 + 13) % size.width;
      final y = (i * 31 + 7) % (size.height * 0.6);
      final radius = 0.5 + (i % 3) * 0.3;
      paint.color = Colors.white.withOpacity(0.3 + (i % 4) * 0.12);
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom bird with flapping wings
class BirdPainter extends CustomPainter {
  final double wingPhase;
  final Color color;

  BirdPainter({required this.wingPhase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final wingAngle = sin(wingPhase) * 0.8;
    
    final bodyPaint = Paint()..color = color;
    final whitePaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final beakPaint = Paint()..color = Colors.orange.shade700;
    
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    
    // Body
    final bodyPath = Path();
    bodyPath.addOval(Rect.fromCenter(center: Offset.zero, width: 40, height: 28));
    canvas.drawPath(bodyPath, bodyPaint);
    
    // White belly
    final bellyPath = Path();
    bellyPath.addOval(Rect.fromCenter(center: const Offset(0, 4), width: 30, height: 16));
    canvas.drawPath(bellyPath, whitePaint);
    
    // Head
    canvas.drawCircle(const Offset(22, -8), 12, bodyPaint);
    
    // Eye
    canvas.drawCircle(const Offset(26, -10), 4, whitePaint);
    canvas.drawCircle(const Offset(27, -10), 2, blackPaint);
    
    // Beak
    final beakPath = Path();
    beakPath.moveTo(32, -6);
    beakPath.lineTo(45, -4);
    beakPath.lineTo(32, -2);
    beakPath.close();
    canvas.drawPath(beakPath, beakPaint);
    
    // Wings - ANIMATED FLAPPING
    canvas.save();
    canvas.translate(-5, 0);
    canvas.rotate(wingAngle);
    
    final wingPath = Path();
    wingPath.moveTo(0, 0);
    wingPath.lineTo(-30, -20);
    wingPath.lineTo(-35, -15);
    wingPath.lineTo(-25, -5);
    wingPath.lineTo(-35, 0);
    wingPath.lineTo(-25, 5);
    wingPath.lineTo(0, 5);
    wingPath.close();
    canvas.drawPath(wingPath, bodyPaint);
    
    // Wing feather details
    final wingDetailPaint = Paint()
      ..color = color.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(const Offset(-5, 0), const Offset(-28, -12), wingDetailPaint);
    canvas.drawLine(const Offset(-5, 2), const Offset(-30, -5), wingDetailPaint);
    
    canvas.restore();
    
    // Tail feathers
    final tailPath = Path();
    tailPath.moveTo(-20, 0);
    tailPath.lineTo(-35, -5);
    tailPath.lineTo(-32, 0);
    tailPath.lineTo(-35, 5);
    tailPath.close();
    canvas.drawPath(tailPath, bodyPaint);
    
    // Feet
    final footPaint = Paint()
      ..color = Colors.orange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(5, 14), const Offset(5, 22), footPaint);
    canvas.drawLine(const Offset(10, 14), const Offset(10, 22), footPaint);
    canvas.drawLine(const Offset(2, 22), const Offset(8, 22), footPaint);
    canvas.drawLine(const Offset(7, 22), const Offset(13, 22), footPaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BirdPainter oldDelegate) {
    return oldDelegate.wingPhase != wingPhase;
  }
}

// Swan - white with long neck, orange beak
class SwanPainter extends CustomPainter {
  final double wingPhase;

  SwanPainter({required this.wingPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final wingAngle = sin(wingPhase) * 0.7;
    
    final whitePaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final orangePaint = Paint()..color = Colors.orange.shade700;
    final grayPaint = Paint()..color = Colors.grey.shade300;
    
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    
    // Body - large white oval
    canvas.drawOval(Rect.fromCenter(center: const Offset(-5, 5), width: 45, height: 30), whitePaint);
    
    // Long curved neck
    final neckPath = Path();
    neckPath.moveTo(15, 5);
    neckPath.quadraticBezierTo(25, -20, 20, -30);
    neckPath.quadraticBezierTo(18, -35, 22, -38);
    canvas.drawPath(neckPath, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round);
    
    // Head
    canvas.drawCircle(const Offset(22, -38), 8, whitePaint);
    
    // Eye
    canvas.drawCircle(const Offset(25, -40), 2, blackPaint);
    
    // Orange beak
    final beakPath = Path();
    beakPath.moveTo(28, -38);
    beakPath.lineTo(40, -36);
    beakPath.lineTo(28, -34);
    beakPath.close();
    canvas.drawPath(beakPath, orangePaint);
    
    // Black patch on beak
    canvas.drawCircle(const Offset(29, -37), 3, blackPaint);
    
    // Wings - ANIMATED
    canvas.save();
    canvas.translate(-10, 0);
    canvas.rotate(wingAngle);
    
    final wingPath = Path();
    wingPath.moveTo(0, 0);
    wingPath.lineTo(-25, -18);
    wingPath.lineTo(-30, -12);
    wingPath.lineTo(-20, -3);
    wingPath.lineTo(-28, 3);
    wingPath.lineTo(0, 5);
    wingPath.close();
    canvas.drawPath(wingPath, whitePaint);
    canvas.drawPath(wingPath, Paint()
      ..color = Colors.grey.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);
    
    canvas.restore();
    
    // Tail
    final tailPath = Path();
    tailPath.moveTo(-28, 5);
    tailPath.lineTo(-40, 0);
    tailPath.lineTo(-38, 8);
    tailPath.close();
    canvas.drawPath(tailPath, whitePaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant SwanPainter oldDelegate) {
    return oldDelegate.wingPhase != wingPhase;
  }
}

// Coot - black bird with white face/beak
class CootPainter extends CustomPainter {
  final double wingPhase;

  CootPainter({required this.wingPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final wingAngle = sin(wingPhase) * 0.8;
    
    final blackPaint = Paint()..color = const Color(0xFF1a1a1a);
    final whitePaint = Paint()..color = Colors.white;
    final darkGrayPaint = Paint()..color = Colors.grey.shade800;
    
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    
    // Body - round black
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 38, height: 28), blackPaint);
    
    // Head
    canvas.drawCircle(const Offset(20, -6), 11, blackPaint);
    
    // White face shield
    final shieldPath = Path();
    shieldPath.addOval(Rect.fromCenter(center: const Offset(26, -12), width: 10, height: 14));
    canvas.drawPath(shieldPath, whitePaint);
    
    // White beak
    final beakPath = Path();
    beakPath.moveTo(28, -6);
    beakPath.lineTo(42, -5);
    beakPath.lineTo(28, -3);
    beakPath.close();
    canvas.drawPath(beakPath, whitePaint);
    
    // Eye
    canvas.drawCircle(const Offset(24, -8), 2, Paint()..color = Colors.red.shade900);
    
    // Wings - ANIMATED
    canvas.save();
    canvas.translate(-5, 0);
    canvas.rotate(wingAngle);
    
    final wingPath = Path();
    wingPath.moveTo(0, 0);
    wingPath.lineTo(-28, -18);
    wingPath.lineTo(-32, -12);
    wingPath.lineTo(-22, -4);
    wingPath.lineTo(-30, 2);
    wingPath.lineTo(0, 5);
    wingPath.close();
    canvas.drawPath(wingPath, darkGrayPaint);
    
    canvas.restore();
    
    // Tail
    canvas.drawOval(Rect.fromCenter(center: const Offset(-22, 2), width: 15, height: 8), blackPaint);
    
    // Feet (greenish)
    final footPaint = Paint()
      ..color = Colors.green.shade700
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(5, 14), const Offset(5, 22), footPaint);
    canvas.drawLine(const Offset(10, 14), const Offset(10, 22), footPaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CootPainter oldDelegate) {
    return oldDelegate.wingPhase != wingPhase;
  }
}

// Moorhen - dark bird with red/yellow beak
class MoorhenPainter extends CustomPainter {
  final double wingPhase;

  MoorhenPainter({required this.wingPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final wingAngle = sin(wingPhase) * 0.8;
    
    final bodyPaint = Paint()..color = const Color(0xFF2a2a35);
    final blackPaint = Paint()..color = Colors.black;
    final redPaint = Paint()..color = Colors.red.shade700;
    final yellowPaint = Paint()..color = Colors.yellow.shade600;
    
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    
    // Body - dark bluish black
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 40, height: 28), bodyPaint);
    
    // White flank stripe
    canvas.drawLine(
      const Offset(-15, 8), 
      const Offset(10, 8), 
      Paint()..color = Colors.white..strokeWidth = 2
    );
    
    // Head
    canvas.drawCircle(const Offset(22, -6), 11, blackPaint);
    
    // Red face shield
    final shieldPath = Path();
    shieldPath.addOval(Rect.fromCenter(center: const Offset(26, -14), width: 8, height: 10));
    canvas.drawPath(shieldPath, redPaint);
    
    // Yellow-tipped red beak
    final beakPath = Path();
    beakPath.moveTo(28, -6);
    beakPath.lineTo(38, -5);
    beakPath.lineTo(28, -3);
    beakPath.close();
    canvas.drawPath(beakPath, redPaint);
    canvas.drawCircle(const Offset(37, -5), 2, yellowPaint);
    
    // Eye
    canvas.drawCircle(const Offset(24, -7), 2, Paint()..color = Colors.red.shade300);
    
    // Wings - ANIMATED
    canvas.save();
    canvas.translate(-5, 0);
    canvas.rotate(wingAngle);
    
    final wingPath = Path();
    wingPath.moveTo(0, 0);
    wingPath.lineTo(-28, -18);
    wingPath.lineTo(-33, -12);
    wingPath.lineTo(-23, -4);
    wingPath.lineTo(-30, 3);
    wingPath.lineTo(0, 5);
    wingPath.close();
    canvas.drawPath(wingPath, Paint()..color = const Color(0xFF3a3a45));
    
    canvas.restore();
    
    // White undertail
    final tailPath = Path();
    tailPath.moveTo(-20, 5);
    tailPath.lineTo(-32, 2);
    tailPath.lineTo(-30, 10);
    tailPath.close();
    canvas.drawPath(tailPath, blackPaint);
    canvas.drawCircle(const Offset(-28, 8), 4, Paint()..color = Colors.white);
    
    // Green feet
    final footPaint = Paint()
      ..color = Colors.green.shade600
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(5, 14), const Offset(5, 22), footPaint);
    canvas.drawLine(const Offset(10, 14), const Offset(10, 22), footPaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant MoorhenPainter oldDelegate) {
    return oldDelegate.wingPhase != wingPhase;
  }
}

// Heron - tall gray bird with long neck and yellow beak
class HeronPainter extends CustomPainter {
  final double wingPhase;

  HeronPainter({required this.wingPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final wingAngle = sin(wingPhase) * 0.6;
    
    final grayPaint = Paint()..color = Colors.grey.shade500;
    final darkGrayPaint = Paint()..color = Colors.grey.shade700;
    final whitePaint = Paint()..color = Colors.white;
    final blackPaint = Paint()..color = Colors.black;
    final yellowPaint = Paint()..color = Colors.yellow.shade700;
    
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    
    // Body - gray oval (positioned lower for tall bird)
    canvas.drawOval(Rect.fromCenter(center: const Offset(-5, 15), width: 35, height: 25), grayPaint);
    
    // White chest
    canvas.drawOval(Rect.fromCenter(center: const Offset(5, 18), width: 18, height: 20), whitePaint);
    
    // Black streaks on chest
    for (int i = 0; i < 3; i++) {
      canvas.drawLine(
        Offset(3, 12.0 + i * 5),
        Offset(8, 14.0 + i * 5),
        Paint()..color = Colors.black..strokeWidth = 1
      );
    }
    
    // Long S-curved neck
    final neckPath = Path();
    neckPath.moveTo(10, 10);
    neckPath.quadraticBezierTo(20, -5, 12, -20);
    neckPath.quadraticBezierTo(8, -30, 15, -35);
    canvas.drawPath(neckPath, Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round);
    
    // Head
    canvas.drawOval(Rect.fromCenter(center: const Offset(15, -38), width: 14, height: 10), whitePaint);
    
    // Black crown/crest
    final crestPath = Path();
    crestPath.moveTo(10, -42);
    crestPath.lineTo(5, -48);
    crestPath.lineTo(15, -44);
    crestPath.close();
    canvas.drawPath(crestPath, blackPaint);
    canvas.drawLine(const Offset(8, -44), const Offset(-5, -50), Paint()
      ..color = Colors.black
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round);
    
    // Eye stripe
    canvas.drawLine(const Offset(12, -40), const Offset(5, -42), Paint()
      ..color = Colors.black
      ..strokeWidth = 3);
    
    // Eye
    canvas.drawCircle(const Offset(17, -39), 2, Paint()..color = Colors.yellow.shade600);
    canvas.drawCircle(const Offset(17, -39), 1, blackPaint);
    
    // Long yellow beak
    final beakPath = Path();
    beakPath.moveTo(22, -38);
    beakPath.lineTo(45, -36);
    beakPath.lineTo(22, -35);
    beakPath.close();
    canvas.drawPath(beakPath, yellowPaint);
    
    // Wings - ANIMATED
    canvas.save();
    canvas.translate(-10, 15);
    canvas.rotate(wingAngle);
    
    final wingPath = Path();
    wingPath.moveTo(0, 0);
    wingPath.lineTo(-22, -15);
    wingPath.lineTo(-28, -10);
    wingPath.lineTo(-18, -2);
    wingPath.lineTo(-25, 5);
    wingPath.lineTo(0, 5);
    wingPath.close();
    canvas.drawPath(wingPath, grayPaint);
    
    // Wing feather details
    canvas.drawLine(const Offset(-5, 0), const Offset(-20, -8), Paint()
      ..color = darkGrayPaint.color
      ..strokeWidth = 1);
    
    canvas.restore();
    
    // Tail
    canvas.drawOval(Rect.fromCenter(center: const Offset(-22, 18), width: 12, height: 8), grayPaint);
    
    // Long legs
    final legPaint = Paint()
      ..color = Colors.yellow.shade800
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(0, 28), const Offset(-2, 45), legPaint);
    canvas.drawLine(const Offset(8, 28), const Offset(10, 45), legPaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HeronPainter oldDelegate) {
    return oldDelegate.wingPhase != wingPhase;
  }
}

// Shotgun pointing up with optional scope
class ShotgunPainter extends CustomPainter {
  final bool hasScope;
  
  ShotgunPainter({this.hasScope = false});

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    
    // Main barrel (double barrel)
    final barrelPaint = Paint()..color = const Color(0xFF1a1a1a);
    final barrelHighlight = Paint()..color = const Color(0xFF2a2a2a);
    
    // Left barrel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 12, 20, 10, 180),
        const Radius.circular(2),
      ),
      barrelPaint,
    );
    
    // Right barrel  
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX + 2, 20, 10, 180),
        const Radius.circular(2),
      ),
      barrelPaint,
    );
    
    // Barrel highlights
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 10, 30, 3, 160),
        const Radius.circular(1),
      ),
      barrelHighlight,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX + 4, 30, 3, 160),
        const Radius.circular(1),
      ),
      barrelHighlight,
    );
    
    // SCOPE (only from level 2)
    if (hasScope) {
      final scopeBodyPaint = Paint()..color = const Color(0xFF111111);
      final scopeLensPaint = Paint()..color = const Color(0xFF1a3a5a);
      final scopeRingPaint = Paint()..color = const Color(0xFF333333);
      
      // Scope mount
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - 8, 100, 16, 20),
          const Radius.circular(2),
        ),
        scopeRingPaint,
      );
      
      // Scope body (tube)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(centerX - 10, 40, 20, 80),
          const Radius.circular(10),
        ),
        scopeBodyPaint,
      );
      
      // Scope front lens
      canvas.drawCircle(Offset(centerX, 45), 8, scopeLensPaint);
      canvas.drawCircle(Offset(centerX, 45), 9, Paint()
        ..color = const Color(0xFF222222)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      
      // Scope rear lens
      canvas.drawCircle(Offset(centerX, 115), 7, scopeLensPaint);
      canvas.drawCircle(Offset(centerX, 115), 8, Paint()
        ..color = const Color(0xFF222222)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2);
      
      // Scope adjustment knob
      canvas.drawCircle(Offset(centerX + 12, 80), 5, scopeRingPaint);
    }
    
    // Barrel band
    final bandPaint = Paint()..color = const Color(0xFF333333);
    canvas.drawRect(Rect.fromLTWH(centerX - 14, 180, 28, 8), bandPaint);
    
    // Front sight (only if no scope)
    if (!hasScope) {
      final sightPaint = Paint()..color = const Color(0xFF444444);
      canvas.drawRect(Rect.fromLTWH(centerX - 2, 20, 4, 10), sightPaint);
    }
    
    // Receiver
    final receiverPaint = Paint()..color = const Color(0xFF222222);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 20, 188, 40, 35),
        const Radius.circular(4),
      ),
      receiverPaint,
    );
    
    // Trigger guard
    final triggerPaint = Paint()
      ..color = const Color(0xFF1a1a1a)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawArc(
      Rect.fromLTWH(centerX - 10, 205, 20, 20),
      0, 3.14, false, triggerPaint,
    );
    
    // Wooden forend
    final woodPaint = Paint()..color = const Color(0xFF5D4037);
    final woodDark = Paint()..color = const Color(0xFF3E2723);
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 18, 130, 36, 55),
        const Radius.circular(4),
      ),
      woodPaint,
    );
    
    // Wood grain
    woodDark.strokeWidth = 1;
    woodDark.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(centerX - 12, 135), Offset(centerX - 10, 180), woodDark);
    canvas.drawLine(Offset(centerX + 10, 138), Offset(centerX + 12, 178), woodDark);
    
    // Stock
    final stockPath = Path()
      ..moveTo(centerX - 25, 223)
      ..lineTo(centerX - 45, 260)
      ..lineTo(centerX + 45, 260)
      ..lineTo(centerX + 25, 223)
      ..close();
    canvas.drawPath(stockPath, woodPaint);
    
    // Stock grip
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(centerX - 15, 215, 30, 30),
        const Radius.circular(6),
      ),
      woodPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ShotgunPainter oldDelegate) {
    return oldDelegate.hasScope != hasScope;
  }
}

class Bird {
  double x, y, targetY, speed, wobble, wobblePhase, wingPhase;
  bool facingRight, dead;
  int deadTime;
  Color color;
  int birdStyle;
  bool isBoss;
  int health;

  Bird({
    required this.x,
    required this.y,
    required this.targetY,
    required this.speed,
    required this.wobble,
    required this.wobblePhase,
    required this.wingPhase,
    required this.facingRight,
    required this.color,
    this.birdStyle = 0,
    this.dead = false,
    this.deadTime = 0,
    this.isBoss = false,
    this.health = 1,
  });
}

class HitIndicator {
  final double x, y;
  final int points;
  final String type;
  final DateTime createdAt;

  HitIndicator({required this.x, required this.y, required this.points, required this.type, required this.createdAt});
}

// Boss bird - larger menacing bird
class BossBirdPainter extends CustomPainter {
  final double wingPhase;

  BossBirdPainter({required this.wingPhase});

  @override
  void paint(Canvas canvas, Size size) {
    final wingAngle = sin(wingPhase) * 0.6;
    
    final bodyPaint = Paint()..color = const Color(0xFF8B0000); // Dark red
    final blackPaint = Paint()..color = Colors.black;
    final yellowPaint = Paint()..color = Colors.amber;
    final whitePaint = Paint()..color = Colors.white;
    
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    
    // Large body
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 70, height: 50), bodyPaint);
    
    // Darker belly
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 5), width: 50, height: 30), 
      Paint()..color = const Color(0xFF5C0000)
    );
    
    // Head
    canvas.drawCircle(const Offset(35, -10), 20, bodyPaint);
    
    // Angry eyes
    canvas.drawCircle(const Offset(40, -15), 7, whitePaint);
    canvas.drawCircle(const Offset(42, -14), 4, blackPaint);
    
    // Eyebrow (angry)
    canvas.drawLine(
      const Offset(33, -22),
      const Offset(47, -18),
      Paint()..color = Colors.black..strokeWidth = 3..strokeCap = StrokeCap.round,
    );
    
    // Sharp beak
    final beakPath = Path();
    beakPath.moveTo(50, -10);
    beakPath.lineTo(75, -5);
    beakPath.lineTo(50, 0);
    beakPath.close();
    canvas.drawPath(beakPath, yellowPaint);
    
    // Crown/crest
    final crownPath = Path();
    crownPath.moveTo(30, -28);
    crownPath.lineTo(25, -40);
    crownPath.lineTo(35, -32);
    crownPath.lineTo(40, -42);
    crownPath.lineTo(45, -30);
    canvas.drawPath(crownPath, Paint()..color = Colors.red.shade900);
    
    // Wings - ANIMATED
    canvas.save();
    canvas.translate(-10, 0);
    canvas.rotate(wingAngle);
    
    final wingPath = Path();
    wingPath.moveTo(0, 0);
    wingPath.lineTo(-50, -30);
    wingPath.lineTo(-60, -20);
    wingPath.lineTo(-45, -5);
    wingPath.lineTo(-55, 10);
    wingPath.lineTo(0, 10);
    wingPath.close();
    canvas.drawPath(wingPath, Paint()..color = const Color(0xFF6B0000));
    
    canvas.restore();
    
    // Tail
    final tailPath = Path();
    tailPath.moveTo(-35, 0);
    tailPath.lineTo(-60, -10);
    tailPath.lineTo(-55, 5);
    tailPath.lineTo(-60, 15);
    tailPath.lineTo(-35, 10);
    tailPath.close();
    canvas.drawPath(tailPath, bodyPaint);
    
    // Talons
    final talonPaint = Paint()
      ..color = Colors.grey.shade800
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(10, 25), const Offset(5, 40), talonPaint);
    canvas.drawLine(const Offset(20, 25), const Offset(25, 40), talonPaint);
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant BossBirdPainter oldDelegate) {
    return oldDelegate.wingPhase != wingPhase;
  }
}
