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
  const Sound(this.title, this.file, this.icon, this.color, this.subtitle);
  final String title;
  final String file;
  final IconData icon;
  final Color color;
  final String subtitle;
}

const sounds = <Sound>[
  Sound(
    'Air horn',
    'air_horn.wav',
    Icons.campaign_rounded,
    Color(0xFFFBBE62),
    'MAKE AN ENTRANCE',
  ),
  Sound(
    'Fart',
    'fart.wav',
    Icons.air_rounded,
    Color(0xFFB8F679),
    'CLASSIC COMEDY',
  ),
  Sound(
    'Sad trombone',
    'sad_trombone.wav',
    Icons.music_note_rounded,
    Color(0xFF8BA9FF),
    'WOMP WOMP',
  ),
  Sound(
    'Ba dum tss',
    'ba_dum_tss.wav',
    Icons.album_rounded,
    Color(0xFFFF9296),
    'NICE ONE',
  ),
  Sound(
    'Crickets',
    'crickets.wav',
    Icons.nights_stay_rounded,
    Color(0xFFC6A8FF),
    'TOUGH CROWD',
  ),
  Sound(
    'Laser / pew pew',
    'laser.wav',
    Icons.bolt_rounded,
    Color(0xFF70DCE1),
    'PEW PEW',
  ),
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
  double _volume = .8;
  PlaybackSpeed _speed = PlaybackSpeed.normal;
  bool _settingsTouched = false;
  bool _mayRequestAds = false;
  bool _adsInitializing = false;
  bool _showPrivacyOptions = false;

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
        _volume = (prefs.getDouble('volume') ?? .8).clamp(0, 1);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final side = width < 370 ? 16.0 : 24.0;
                  final padHeight = width < 370 ? 128.0 : 144.0;
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(side, 18, side, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'noise',
                              style: TextStyle(
                                fontSize: 27,
                                letterSpacing: -1.8,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              '.',
                              style: TextStyle(
                                fontSize: 30,
                                height: .8,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFBBF553),
                              ),
                            ),
                            const Spacer(),
                            if (_showPrivacyOptions)
                              TextButton.icon(
                                onPressed: _openPrivacyOptions,
                                icon: const Icon(
                                  Icons.shield_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Privacy choices',
                                  style: TextStyle(fontSize: 12),
                                ),
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFFBBF553),
                                ),
                              ),
                            const Icon(
                              Icons.graphic_eq_rounded,
                              color: Color(0xFFBBF553),
                              size: 23,
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Small app.\nBig reactions.',
                          style: TextStyle(
                            fontSize: 36,
                            height: 1.02,
                            letterSpacing: -1.5,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 9),
                        const Text(
                          'Tap a sound. Set the mood.',
                          style: TextStyle(
                            color: Color(0xFF98A1A1),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 24),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: sounds.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 12,
                                crossAxisSpacing: 12,
                                mainAxisExtent: padHeight,
                              ),
                          itemBuilder: (context, index) => SoundPad(
                            sound: sounds[index],
                            active: _playing == index,
                            onTap: () => _play(index),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ActionButton(
                                label: 'Surprise me',
                                icon: Icons.shuffle_rounded,
                                filled: true,
                                onTap: () =>
                                    _play(_random.nextInt(sounds.length)),
                              ),
                            ),
                            const SizedBox(width: 12),
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
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D2324),
                            borderRadius: BorderRadius.circular(23),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.volume_up_rounded,
                                    color: Color(0xFFBBF553),
                                    size: 21,
                                  ),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Volume',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${(_volume * 100).round()}%',
                                    style: const TextStyle(
                                      color: Color(0xFFB8C1BE),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: const Color(0xFFBBF553),
                                  inactiveTrackColor: const Color(0xFF394140),
                                  thumbColor: const Color(0xFFBBF553),
                                  overlayColor: const Color(0x33BBF553),
                                  trackHeight: 5,
                                ),
                                child: Slider(
                                  value: _volume,
                                  label: '${(_volume * 100).round()}%',
                                  onChanged: (value) {
                                    _settingsTouched = true;
                                    setState(() => _volume = value);
                                    if (_playing != null) {
                                      unawaited(
                                        _player.setVolume(value).catchError((
                                          Object e,
                                        ) {
                                          debugPrint('Volume update: $e');
                                        }),
                                      );
                                    }
                                  },
                                  onChangeEnd: (value) => unawaited(
                                    _prefs?.setDouble('volume', value) ??
                                        Future.value(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'PLAYBACK SPEED',
                                style: TextStyle(
                                  color: Color(0xFF98A1A1),
                                  fontSize: 11,
                                  letterSpacing: 1.3,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  for (final speed in PlaybackSpeed.values)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(
                                          right: speed == PlaybackSpeed.fast
                                              ? 0
                                              : 8,
                                        ),
                                        child: ChoiceChip(
                                          label: SizedBox(
                                            width: double.infinity,
                                            child: Text(
                                              speed.label,
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                          selected: _speed == speed,
                                          onSelected: (_) {
                                            _settingsTouched = true;
                                            setState(() => _speed = speed);
                                            if (_playing != null) {
                                              unawaited(
                                                _player
                                                    .setPlaybackRate(speed.rate)
                                                    .catchError((Object e) {
                                                      debugPrint(
                                                        'Speed update: $e',
                                                      );
                                                    }),
                                              );
                                            }
                                            unawaited(
                                              _prefs?.setString(
                                                    'speed',
                                                    speed.name,
                                                  ) ??
                                                  Future.value(),
                                            );
                                          },
                                          showCheckmark: false,
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 7,
                                          ),
                                          labelPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 0,
                                              ),
                                          backgroundColor: const Color(
                                            0xFF303838,
                                          ),
                                          selectedColor: const Color(
                                            0xFFBBF553,
                                          ),
                                          side: BorderSide.none,
                                          labelStyle: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: _speed == speed
                                                ? const Color(0xFF14200D)
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Center(
                          child: Text(
                            'MADE FOR REACTIONS  •  WORKS OFFLINE',
                            style: TextStyle(
                              color: Color(0xFF6E7977),
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (_mayRequestAds && MediaQuery.sizeOf(context).width >= 320)
              const _BannerSlot(),
          ],
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
    final accent = widget.sound.color;
    return Semantics(
      button: true,
      selected: widget.active,
      label: '${widget.sound.title}${widget.active ? ', playing' : ''}',
      child: AnimatedScale(
        scale: _pressed ? .96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          decoration: BoxDecoration(
            color: widget.active
                ? accent.withValues(alpha: .30)
                : accent.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: widget.active ? accent : accent.withValues(alpha: .24),
              width: widget.active ? 2 : 1,
            ),
            boxShadow: widget.active
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: .2),
                      blurRadius: 20,
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(23),
              onHighlightChanged: (value) => setState(() => _pressed = value),
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 43,
                          height: 43,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: .22),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.sound.icon,
                            color: accent,
                            size: 26,
                          ),
                        ),
                        const Spacer(),
                        if (widget.active)
                          Icon(
                            Icons.graphic_eq_rounded,
                            color: accent,
                            size: 22,
                          ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.sound.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.sound.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            letterSpacing: .55,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
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
    height: 53,
    child: FilledButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        maxLines: 1,
        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: filled
            ? const Color(0xFFBBF553)
            : const Color(0xFF282E2E),
        foregroundColor: filled ? const Color(0xFF14200D) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        padding: const EdgeInsets.symmetric(horizontal: 5),
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
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: const BoxDecoration(
        color: Color(0xFF1D2324),
        border: Border(top: BorderSide(color: Color(0xFF353E3D))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'ADVERTISEMENT',
            style: TextStyle(
              color: Color(0xFF89918E),
              fontSize: 9,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        ],
      ),
    );
  }
}
