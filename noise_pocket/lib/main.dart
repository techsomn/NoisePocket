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

class Sound {
  const Sound(this.title, this.file, this.padTitle, this.color,
      {this.darkText = false});
  final String title;
  final String file;
  final String padTitle;
  final Color color;
  final bool darkText;
}

const sounds = <Sound>[
  Sound('Air horn', 'air_horn.wav', 'AIR\nHORN', Color(0xFFFF5B3D)),
  Sound('Fart', 'fart.wav', 'FART', Color(0xFFB45DF5)),
  Sound('Sad trombone', 'sad_trombone.wav', 'SAD\nTROMBONE', Color(0xFF2E7DF2)),
  Sound('Ba dum tss', 'ba_dum_tss.wav', 'BA DUM\nTSS',
      Color(0xFFFFC94F), darkText: true),
  Sound('Crickets', 'crickets.wav', 'CRICKETS', Color(0xFF29C586)),
  Sound('Laser / pew pew', 'laser.wav', 'LASER', Color(0xFFF53C8B)),
];

enum PlaybackSpeed {
  slow(.75, 'Slow'),
  normal(1, 'Normal'),
  fast(1.4, 'Fast');

  const PlaybackSpeed(this.rate, this.label);
  final double rate;
  final String label;
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
  SharedPreferences? _prefs;
  StreamSubscription<void>? _completion;
  Future<void> _audioQueue = Future.value();
  int _request = 0;
  int? _playing;
  double _volume = .7;
  PlaybackSpeed _speed = PlaybackSpeed.normal;
  bool _settingsTouched = false;
  bool _mayRequestAds = false;
  bool _adsInitializing = false;
  bool _showPrivacyOptions = false;
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _completion = _player.onPlayerComplete.listen((_) {
      if (mounted && _player.state == PlayerState.completed) {
        setState(() => _playing = null);
      }
    });
    _loadSettings();
    // AudioCache prepares local files for the first tap. Playback also works if preload fails.
    unawaited(
      _player.audioCache
          .loadAll([for (final sound in sounds) 'sounds/${sound.file}'])
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

  void _play(int index) {
    HapticFeedback.selectionClick();
    if (_showHint) setState(() => _showHint = false);
    final request = ++_request;
    _audioQueue = _audioQueue
        .catchError((Object e) {
          debugPrint('Audio operation: $e');
        })
        .then((_) async {
          if (!mounted || request != _request) return;
          await _player.stop();
          if (!mounted || request != _request) return;
          await _player.play(
            AssetSource('sounds/${sounds[index].file}'),
            volume: _volume,
          );
          if (!mounted || request != _request) {
            await _player.stop();
            return;
          }
          await _player.setPlaybackRate(_speed.rate);
          if (!mounted || request != _request) {
            await _player.stop();
            return;
          }
          setState(() => _playing = index);
        })
        .catchError((Object e) {
          debugPrint('Could not play sound: $e');
          if (mounted && request == _request) {
            setState(() => _playing = null);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not play that sound. Please try again.'),
              ),
            );
          }
        });
  }

  void _stop() {
    ++_request;
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
                                if (_playing != null) {
                                  unawaited(
                                    _player
                                        .setPlaybackRate(speed.rate)
                                        .catchError((Object e) {
                                      debugPrint('Speed update: $e');
                                    }),
                                  );
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        ((constraints.maxHeight - (_showHint ? 250 : 205)) / 3)
                            .clamp(112.0, 132.0)
                            .toDouble();
                    return SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(side, 24, side, 16),
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
                              color: Color(0xFFAAAAB0),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 13),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            child: _showHint
                                ? Container(
                                    height: 46,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF303136),
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Row(
                                      children: [
                                        Text('👆',
                                            style: TextStyle(fontSize: 24)),
                                        SizedBox(width: 13),
                                        Expanded(
                                          child: Text(
                                            'Tap any pad to make some noise',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          ),
                          if (_showHint) const SizedBox(height: 9),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: sounds.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              mainAxisExtent: padHeight,
                            ),
                            itemBuilder: (context, index) => SoundPad(
                              sound: sounds[index],
                              active: _playing == index,
                              onTap: () => _play(index),
                            ),
                          ),
                          const SizedBox(height: 17),
                          Row(
                            children: [
                              Expanded(
                                child: _ActionButton(
                                  label: 'Surprise Me',
                                  icon: Icons.casino_rounded,
                                  filled: true,
                                  onTap: () =>
                                      _play(_random.nextInt(sounds.length)),
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
                        ],
                      ),
                    );
                  },
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
    return Semantics(
      button: true,
      selected: widget.active,
      label: '${sound.title}${widget.active ? ', playing' : ''}',
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: const Duration(milliseconds: 110),
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
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: widget.active
                  ? const Color(0xFFD4FF22)
                  : Colors.transparent,
              width: widget.active ? 3 : 1,
            ),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: const Color(0xFFD4FF22).withValues(alpha: .34),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(27),
              onHighlightChanged: (value) {
                if (mounted) setState(() => _pressed = value);
              },
              onTap: widget.onTap,
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      sound.padTitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: sound.darkText
                            ? const Color(0xFF25221E)
                            : Colors.white,
                        fontSize: sound.padTitle.contains('TROMBONE')
                            ? 19
                            : 23,
                        height: .98,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.4,
                      ),
                    ),
                  ),
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
