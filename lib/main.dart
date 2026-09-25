import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NoisePocketApp());
}

class AdConfig {
  // Keep these fallbacks as Google's official Android test IDs.
  // For production, edit config/admob.json and build with --dart-define-from-file.
  static const bannerUnitId = String.fromEnvironment(
    'ADMOB_BANNER_ID',
    defaultValue: 'ca-app-pub-3940256099942544/6300978111',
  );
}

class NoisePocketApp extends StatelessWidget {
  const NoisePocketApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Noise Pocket',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFF111417),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFFBBF553),
        brightness: Brightness.dark,
        surface: const Color(0xFF111417),
      ),
      fontFamily: 'Roboto',
    ),
    home: const SoundboardScreen(),
  );
}

enum SoundCategory {
  all('All'),
  reactions('Reactions'),
  cartoon('Cartoon'),
  arcade('Arcade'),
  world('World');

  const SoundCategory(this.label);
  final String label;
}

class Sound {
  const Sound(this.title, this.file, this.padTitle, this.color,
      {required this.icon,
      this.category = SoundCategory.reactions,
      this.darkText = false});
  final String title;
  final String file;
  final String padTitle;
  final Color color;
  final IconData icon;
  final SoundCategory category;
  final bool darkText;
}

const sounds = <Sound>[
  Sound('Air horn', 'air_horn.wav', 'AIR\nHORN', Color(0xFFFF5B3D),
      icon: Icons.campaign_rounded),
  Sound('Fart', 'fart.wav', 'FART', Color(0xFFB45DF5),
      icon: Icons.air_rounded),
  Sound('Sad trombone', 'sad_trombone.wav', 'SAD\nTROMBONE', Color(0xFF2E7DF2),
      icon: Icons.music_note_rounded),
  Sound('Ba dum tss', 'ba_dum_tss.wav', 'BA DUM\nTSS',
      Color(0xFFFFC94F), icon: Icons.graphic_eq_rounded, darkText: true),
  Sound('Crickets', 'crickets.wav', 'CRICKETS', Color(0xFF29C586),
      icon: Icons.bug_report_rounded),
  Sound('Laser / pew pew', 'laser.wav', 'LASER', Color(0xFFF53C8B),
      icon: Icons.bolt_rounded, category: SoundCategory.arcade),
  Sound('Applause', 'applause.wav', 'APPLAUSE', Color(0xFFFF5B3D),
      icon: Icons.celebration_rounded),
  Sound('Boo', 'boo.wav', 'BOO', Color(0xFFB45DF5),
      icon: Icons.sentiment_dissatisfied_rounded),
  Sound('Whistle', 'whistle.wav', 'WHISTLE', Color(0xFF29C586),
      icon: Icons.music_note_rounded),
  Sound('Boing', 'boing.wav', 'BOING', Color(0xFFFFC94F),
      icon: Icons.sports_tennis_rounded,
      category: SoundCategory.cartoon, darkText: true),
  Sound('Squeak', 'squeak.wav', 'SQUEAK', Color(0xFFF53C8B),
      icon: Icons.pets_rounded, category: SoundCategory.cartoon),
  Sound('Pop', 'pop.wav', 'POP', Color(0xFF2E7DF2),
      icon: Icons.bubble_chart_rounded, category: SoundCategory.cartoon),
  Sound('Record scratch', 'record_scratch.wav', 'RECORD\nSCRATCH',
      Color(0xFFFF5B3D), icon: Icons.album_rounded,
      category: SoundCategory.cartoon),
  Sound('Whoosh', 'whoosh.wav', 'WHOOSH', Color(0xFF29C586),
      icon: Icons.air_rounded, category: SoundCategory.cartoon),
  Sound('Splash', 'splash.wav', 'SPLASH', Color(0xFF2E7DF2),
      icon: Icons.water_drop_rounded, category: SoundCategory.cartoon),
  Sound('Coin', 'coin.wav', 'COIN', Color(0xFFFFC94F),
      icon: Icons.monetization_on_rounded,
      category: SoundCategory.arcade, darkText: true),
  Sound('Power up', 'power_up.wav', 'POWER\nUP', Color(0xFFB45DF5),
      icon: Icons.trending_up_rounded, category: SoundCategory.arcade),
  Sound('Error buzz', 'error_buzz.wav', 'ERROR\nBUZZ', Color(0xFFFF5B3D),
      icon: Icons.error_outline_rounded, category: SoundCategory.arcade),
  Sound('Robot beep', 'robot_beep.wav', 'ROBOT\nBEEP', Color(0xFF29C586),
      icon: Icons.smart_toy_rounded, category: SoundCategory.arcade),
  Sound('Game over', 'game_over.wav', 'GAME\nOVER', Color(0xFF2E7DF2),
      icon: Icons.videogame_asset_rounded, category: SoundCategory.arcade),
  Sound('Doorbell', 'doorbell.wav', 'DOORBELL', Color(0xFFFFC94F),
      icon: Icons.doorbell_rounded,
      category: SoundCategory.world, darkText: true),
  Sound('Knock knock', 'knock.wav', 'KNOCK\nKNOCK', Color(0xFFB45DF5),
      icon: Icons.pan_tool_rounded, category: SoundCategory.world),
  Sound('Camera', 'camera.wav', 'CAMERA', Color(0xFFF53C8B),
      icon: Icons.camera_alt_rounded, category: SoundCategory.world),
  Sound('Thunder', 'thunder.wav', 'THUNDER', Color(0xFF2E7DF2),
      icon: Icons.flash_on_rounded, category: SoundCategory.world),
  Sound('Ghost', 'ghost.wav', 'GHOST', Color(0xFF29C586),
      icon: Icons.nights_stay_rounded, category: SoundCategory.world),
  Sound('Snore', 'snore.wav', 'SNORE', Color(0xFFFF5B3D),
      icon: Icons.bedtime_rounded, category: SoundCategory.world),
];

enum PlaybackSpeed {
  slow(.75, 'Slow'),
  normal(1, 'Normal'),
  fast(1.4, 'Fast');

  const PlaybackSpeed(this.rate, this.label);
  final double rate;
  final String label;
}

String soundAsset(Sound sound, PlaybackSpeed speed) {
  final name = sound.file.substring(0, sound.file.length - '.wav'.length);
  final suffix = switch (speed) {
    PlaybackSpeed.slow => '_slow',
    PlaybackSpeed.normal => '',
    PlaybackSpeed.fast => '_fast',
  };
  return 'sounds/$name$suffix.wav';
}

class SoundboardScreen extends StatefulWidget {
  const SoundboardScreen({super.key});

  @override
  State<SoundboardScreen> createState() => _SoundboardScreenState();
}

class _SoundboardScreenState extends State<SoundboardScreen>
    with WidgetsBindingObserver {
  final AudioPlayer _player = AudioPlayer();
  final Random _random = Random();
  final ScrollController _scrollController = ScrollController();
  SharedPreferences? _prefs;
  StreamSubscription<void>? _completion;
  Future<void> _audioQueue = Future.value();
  int _request = 0;
  int? _playing;
  bool _pendingPlay = false;
  double _volume = .7;
  PlaybackSpeed _speed = PlaybackSpeed.normal;
  SoundCategory _category = SoundCategory.all;
  bool _settingsTouched = false;
  bool _mayRequestAds = false;
  bool _adsInitializing = false;
  bool _showPrivacyOptions = false;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _completion = _player.onPlayerComplete.listen((_) {
      if (mounted && !_pendingPlay && _player.state == PlayerState.completed) {
        setState(() => _playing = null);
      }
    });
    _loadSettings();
    // Prepare normal files for instant taps. Other tempos load from bundled assets on demand.
    unawaited(
      _player.audioCache
          .loadAll([
            for (final sound in sounds)
              soundAsset(sound, PlaybackSpeed.normal),
          ])
          .then(
            (_) {},
            onError: (Object e) {
              debugPrint('Sound preload failed: $e');
            },
          ),
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _startConsent();
    }
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _prefs = prefs;
      if (!mounted) return;
      if (_settingsTouched) {
        await prefs.setDouble('volume', _volume);
        await prefs.setString('speed', _speed.name);
        return;
      }
      setState(() {
        _volume = (prefs.getDouble('volume') ?? .7).clamp(0, 1);
        _speed = PlaybackSpeed.values.firstWhere(
          (v) => v.name == prefs.getString('speed'),
          orElse: () => PlaybackSpeed.normal,
        );
      });
    } catch (e) {
      debugPrint('Settings unavailable: $e');
    }
  }

  Future<void> _startConsent() async {
    final consent = ConsentInformation.instance;
    consent.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        if (!mounted) return;
        await _updatePrivacyOption();
        // A prior valid decision can allow ads before the form callback.
        await _allowAdsIfPermitted();
        ConsentForm.loadAndShowConsentFormIfRequired((error) async {
          if (error != null) debugPrint('Consent form: ${error.message}');
          if (!mounted) return;
          await _updatePrivacyOption();
          await _allowAdsIfPermitted();
        });
      },
      (error) async {
        debugPrint('Consent update: ${error.message}');
        // UMP can use a valid previous decision when offline.
        if (mounted) await _allowAdsIfPermitted();
      },
    );
  }

  Future<void> _updatePrivacyOption() async {
    try {
      final required =
          await ConsentInformation.instance
              .getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
      if (mounted) setState(() => _showPrivacyOptions = required);
    } catch (e) {
      debugPrint('Privacy options status: $e');
    }
  }

  Future<void> _allowAdsIfPermitted() async {
    try {
      final allowed = await ConsentInformation.instance.canRequestAds();
      if (!mounted || !allowed || _mayRequestAds || _adsInitializing) return;
      _adsInitializing = true;
      await MobileAds.instance.initialize();
      // Privacy choices may change while the SDK is initializing.
      final stillAllowed = await ConsentInformation.instance.canRequestAds();
      if (mounted && stillAllowed) setState(() => _mayRequestAds = true);
    } catch (e) {
      debugPrint('Ads unavailable: $e');
    } finally {
      _adsInitializing = false;
    }
  }

  void _openPrivacyOptions() {
    ConsentForm.showPrivacyOptionsForm((error) async {
      if (error != null) debugPrint('Privacy options: ${error.message}');
      if (!mounted) return;
      final allowed = await ConsentInformation.instance.canRequestAds();
      if (!mounted) return;
      if (allowed) {
        await _allowAdsIfPermitted();
      } else {
        setState(() => _mayRequestAds = false);
      }
      await _updatePrivacyOption();
    });
  }

  void _play(int index, {bool haptic = true}) {
    if (haptic) HapticFeedback.selectionClick();
    final request = ++_request;
    final selectedSpeed = _speed;
    _pendingPlay = true;
    setState(() {
      _hasPlayed = true;
      _playing = index;
    });
    _audioQueue = _audioQueue
        .catchError((Object e) {
          debugPrint('Audio operation: $e');
        })
        .then((_) async {
          if (!mounted || request != _request) return;
          await _player.stop();
          if (!mounted || request != _request) return;
          await _player.play(
            AssetSource(soundAsset(sounds[index], selectedSpeed)),
            volume: _volume,
          );
          if (!mounted || request != _request) {
            await _player.stop();
            return;
          }
          _pendingPlay = false;
          if (_playing != index) setState(() => _playing = index);
        })
        .catchError((Object e) {
          debugPrint('Could not play sound: $e');
          if (mounted && request == _request) {
            _pendingPlay = false;
            setState(() => _playing = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not play that sound. Please try again.'),
              ),
            );
          }
        });
  }

  void _surprise() {
    final choices = _visibleIndices.where((index) => index != _playing).toList();
    if (choices.isEmpty) return;
    _play(choices[_random.nextInt(choices.length)]);
  }

  List<int> get _visibleIndices => [
        for (var i = 0; i < sounds.length; i++)
          if (_category == SoundCategory.all ||
              sounds[i].category == _category)
            i,
      ];

  void _selectCategory(SoundCategory category) {
    if (_category == category) return;
    setState(() => _category = category);
    if (_scrollController.hasClients) {
      unawaited(_scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      ));
    }
  }

  void _stop() {
    ++_request;
    _pendingPlay = false;
    if (mounted) setState(() => _playing = null);
    _audioQueue = _audioQueue
        .catchError((Object e) {
          debugPrint('Audio operation: $e');
        })
        .then((_) => _player.stop())
        .catchError((Object e) {
          debugPrint('Could not stop sound: $e');
        });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    ++_request;
    unawaited(_completion?.cancel() ?? Future.value());
    unawaited(
      _audioQueue.then((_) => _player.dispose()).catchError((Object e) {
        debugPrint('Audio cleanup: $e');
      }),
    );
    super.dispose();
  }

  void _showSettings() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: .64),
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, updateSheet) => SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF252629),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 29,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6F7074),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Playback Settings',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Volume',
                  style: TextStyle(color: Color(0xFFB4B5BA), fontSize: 12),
                ),
                Row(
                  children: [
                    const Icon(Icons.volume_up_rounded,
                        color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(sheetContext).copyWith(
                          activeTrackColor: const Color(0xFFD4FF22),
                          inactiveTrackColor: const Color(0xFF494B4F),
                          thumbColor: const Color(0xFFD4FF22),
                          overlayColor: const Color(0x33D4FF22),
                          trackHeight: 4,
                        ),
                        child: Slider(
                          value: _volume,
                          onChanged: (value) {
                            _settingsTouched = true;
                            updateSheet(() => setState(() => _volume = value));
                            if (_playing != null) {
                              unawaited(_player.setVolume(value).catchError(
                                (Object e) => debugPrint('Volume update: $e'),
                              ));
                            }
                          },
                          onChangeEnd: (value) => unawaited(
                            _prefs?.setDouble('volume', value) ??
                                Future.value(),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${(_volume * 100).round()}%',
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Playback Speed',
                  style: TextStyle(color: Color(0xFFB4B5BA), fontSize: 12),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 39,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF35363A),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFF55565A)),
                  ),
                  child: Row(
                    children: [
                      for (final speed in PlaybackSpeed.values)
                        Expanded(
                          child: Semantics(
                            button: true,
                            selected: _speed == speed,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(22),
                              onTap: () {
                                _settingsTouched = true;
                                updateSheet(
                                  () => setState(() => _speed = speed),
                                );
                                final playing = _playing;
                                if (playing != null) {
                                  _play(playing, haptic: false);
                                }
                                unawaited(
                                  _prefs?.setString('speed', speed.name) ??
                                      Future.value(),
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: _speed == speed
                                      ? const Color(0xFFD4FF22)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: Text(
                                  speed.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: _speed == speed
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: _speed == speed
                                        ? const Color(0xFF18191A)
                                        : Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 43,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFD4FF22),
                      foregroundColor: const Color(0xFF18191A),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Center(
                  child: Text(
                  'NOISE POCKET  •  V2.1',
                    style: TextStyle(
                      color: Color(0xFF929498),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSound = _playing == null ? null : sounds[_playing!];
    final visibleIndices = _visibleIndices;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF202123), Color(0xFF18191B)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final side = width < 370 ? 14.0 : 20.0;
                    final padHeight =
                        ((constraints.maxHeight - 285) / 3)
                            .clamp(128.0, 150.0)
                            .toDouble();
                    return SingleChildScrollView(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(side, 18, side, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'noise',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 27,
                                  letterSpacing: -1.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text(
                                '.',
                                style: TextStyle(
                                  color: Color(0xFFD4FF22),
                                  fontSize: 29,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Spacer(),
                              if (_showPrivacyOptions)
                                IconButton(
                                  onPressed: _openPrivacyOptions,
                                  tooltip: 'Privacy choices',
                                  icon: const Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFFB4B5BA),
                                  ),
                                ),
                              IconButton(
                                onPressed: _showSettings,
                                tooltip: 'Playback settings',
                                icon: const Icon(
                                  Icons.tune_rounded,
                                  color: Color(0xFFB4B5BA),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Small app. Big reactions.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              letterSpacing: -.6,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          const Text(
                            '26 sounds. Infinite bad timing.',
                            style: TextStyle(
                              color: Color(0xFFADAFB4),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            height: 60,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            decoration: BoxDecoration(
                              color: const Color(0xFF292C2E),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFF44494B)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4FF22)
                                        .withValues(alpha: .16),
                                    borderRadius: BorderRadius.circular(11),
                                  ),
                                  child: Icon(
                                    activeSound?.icon ?? Icons.touch_app_rounded,
                                    color: const Color(0xFFD4FF22),
                                    size: 21,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        activeSound == null
                                            ? 'READY WHEN YOU ARE'
                                            : 'NOW PLAYING',
                                        style: const TextStyle(
                                          color: Color(0xFFD4FF22),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        activeSound?.title ??
                                            (_hasPlayed
                                                ? 'Pick another reaction'
                                                : 'Tap any pad to make some noise'),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (activeSound != null)
                                  Text(
                                    _speed.label.toUpperCase(),
                                    style: const TextStyle(
                                      color: Color(0xFFB7BABE),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: .6,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 40,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: SoundCategory.values.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final category = SoundCategory.values[index];
                                final selected = _category == category;
                                return ChoiceChip(
                                  label: Text(category.label),
                                  selected: selected,
                                  onSelected: (_) => _selectCategory(category),
                                  showCheckmark: false,
                                  backgroundColor: const Color(0xFF303235),
                                  selectedColor: const Color(0xFFD4FF22),
                                  side: BorderSide(
                                    color: selected
                                        ? const Color(0xFFD4FF22)
                                        : const Color(0xFF55585B),
                                  ),
                                  shape: const StadiumBorder(),
                                  labelStyle: TextStyle(
                                    color: selected
                                        ? const Color(0xFF1B1D1F)
                                        : Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 13),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: visibleIndices.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: padHeight,
                            ),
                            itemBuilder: (context, index) {
                              final soundIndex = visibleIndices[index];
                              return SoundPad(
                                key: ValueKey(sounds[soundIndex].file),
                                sound: sounds[soundIndex],
                                active: _playing == soundIndex,
                                onTap: () => _play(soundIndex),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
                decoration: const BoxDecoration(
                  color: Color(0xFF1B1E20),
                  border: Border(top: BorderSide(color: Color(0xFF393D40))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'Surprise Me',
                        icon: Icons.casino_rounded,
                        filled: true,
                        onTap: _surprise,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _ActionButton(
                        label: 'Stop',
                        icon: Icons.stop_rounded,
                        filled: false,
                        onTap: _stop,
                      ),
                    ),
                  ],
                ),
              ),
              if (_mayRequestAds && MediaQuery.sizeOf(context).width >= 344)
                const _BannerSlot(),
            ],
          ),
        ),
      ),
    );
  }
}

class SoundPad extends StatefulWidget {
  const SoundPad({
    super.key,
    required this.sound,
    required this.active,
    required this.onTap,
  });
  final Sound sound;
  final bool active;
  final VoidCallback onTap;

  @override
  State<SoundPad> createState() => _SoundPadState();
}

class _SoundPadState extends State<SoundPad> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final sound = widget.sound;
    final ink = sound.darkText ? const Color(0xFF25221E) : Colors.white;
    return Semantics(
      button: true,
      selected: widget.active,
      label: '${sound.title}${widget.active ? ', playing' : ''}',
      child: AnimatedScale(
        scale: _pressed ? .95 : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(sound.color, Colors.white, .05)!,
                Color.lerp(sound.color, Colors.black, .04)!,
              ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: widget.active
                  ? const Color(0xFFD4FF22)
                  : Colors.white.withValues(alpha: .12),
              width: widget.active ? 2.5 : 1,
            ),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: const Color(0xFFD4FF22).withValues(alpha: .28),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 5),
                    ),
                  ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(26),
              onHighlightChanged: (value) {
                if (mounted) setState(() => _pressed = value);
              },
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: .17),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Icon(sound.icon, size: 20, color: ink),
                        ),
                        const Spacer(),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: widget.active
                              ? Text(
                                  'PLAYING',
                                  key: const ValueKey('playing'),
                                  style: TextStyle(
                                    color: ink,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: .6,
                                  ),
                                )
                              : Icon(
                                  Icons.north_east_rounded,
                                  key: const ValueKey('ready'),
                                  size: 18,
                                  color: ink.withValues(alpha: .7),
                                ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        sound.padTitle,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: ink,
                          fontSize: sound.padTitle.contains('TROMBONE')
                              ? 19
                              : 22,
                          height: .97,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.filled,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 50,
        child: FilledButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
          ),
          style: FilledButton.styleFrom(
            backgroundColor:
                filled ? const Color(0xFFD4FF22) : Colors.transparent,
            foregroundColor:
                filled ? const Color(0xFF1D1E20) : Colors.white,
            side: filled
                ? BorderSide.none
                : const BorderSide(color: Color(0xFF77787B)),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        ),
      );
}

class _BannerSlot extends StatefulWidget {
  const _BannerSlot();

  @override
  State<_BannerSlot> createState() => _BannerSlotState();
}

class _BannerSlotState extends State<_BannerSlot> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final banner = BannerAd(
      adUnitId: AdConfig.bannerUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner unavailable: $error');
          ad.dispose();
          if (mounted)
            setState(() {
              _loaded = false;
              _banner = null;
            });
        },
      ),
    );
    _banner = banner;
    banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _banner;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
      decoration: const BoxDecoration(
        color: Color(0xFF1B1C1E),
        border: Border(top: BorderSide(color: Color(0xFF38393C))),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ),
      ),
    );
  }
}
