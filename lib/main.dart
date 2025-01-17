import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:soundpool/soundpool.dart';
import 'package:audio_session/audio_session.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TimerScreen(),
    );
  }
}

class TimerScreen extends StatefulWidget {
  @override
  _TimerScreenState createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> {
  int _secondsRemaining = 10;
  int _currentRound = 0;
  final int _totalRounds = 10;
  Timer? _timer;
  Soundpool? _pool;
  int? _beepShortId;
  int? _beepLongId;
  AudioSession? _session;
  bool _isRunning = false;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initAudio();
  }

  Future<void> _initAudio() async {
    _session = await AudioSession.instance;

    await _session!.configure(AudioSessionConfiguration(
      avAudioSessionCategory: AVAudioSessionCategory.playback,
      avAudioSessionCategoryOptions:
          AVAudioSessionCategoryOptions.mixWithOthers |
              AVAudioSessionCategoryOptions.duckOthers,
      avAudioSessionMode: AVAudioSessionMode.defaultMode,
      avAudioSessionRouteSharingPolicy:
          AVAudioSessionRouteSharingPolicy.defaultPolicy,
      avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      androidAudioAttributes: const AndroidAudioAttributes(
        contentType: AndroidAudioContentType.sonification,
        usage: AndroidAudioUsage.assistanceSonification,
        flags: AndroidAudioFlags.audibilityEnforced,
      ),
      androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      androidWillPauseWhenDucked: false,
    ));

    _pool = Soundpool.fromOptions(
        options: const SoundpoolOptions(
            streamType: StreamType.notification, maxStreams: 5));

    _beepShortId = await _pool!
        .load(await rootBundle.load('assets/audio/beep1_short.wav'));
    _beepLongId =
        await _pool!.load(await rootBundle.load('assets/audio/beep1_long.wav'));

    // The session starts for some reason when configured. Seems like a bug in the lib ... :shrug:
    // So, we deactivate it here so that it doesnt duck the audio of an existing running audio app yet (Spotify, etc)
    await _session!.setActive(false);
  }

  void startTimer() {
    setState(() {
      _currentRound = 1;
      _isRunning = true;
      _isPaused = false;
    });
    _runTimer();
  }

  void _runTimer() {
    _secondsRemaining = 10;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          if (_secondsRemaining > 0) {
            _secondsRemaining--;
            if (_secondsRemaining == 4) {
              _activateAudioSession();
            } else if (_secondsRemaining <= 3 && _secondsRemaining > 0) {
              _playBeep(_beepShortId!);
            } else if (_secondsRemaining == 0) {
              _playFinalBeep();
              if (_currentRound < _totalRounds) {
                _currentRound++;
                _runTimer();
              } else {
                _timer!.cancel();
                _endTimer();
              }
            }
          }
        });
      }
    });
  }

  Future<void> _activateAudioSession() async {
    await _session!.setActive(true);
  }

  Future<void> _playBeep(int soundId) async {
    await _pool!.play(soundId);
  }

  Future<void> _playFinalBeep() async {
    await _pool!.play(_beepLongId!);

    // HACK: Add a delay to ensure the long beep finishes playing before deactivating the session
    // Would love to play after the sounds is done playing, but not sure if we have access to that.
    // There is an AudioStreamControl, but it does not expose the playstate of the sound.
    // Might need to submit that as a PR to the Repo.
    await Future.delayed(const Duration(milliseconds: 1000));
    await _session!.setActive(false);
  }

  void _endTimer() async {
    setState(() {
      _isRunning = false;
      _currentRound = 0;
    });
  }

  void togglePauseResume() {
    setState(() {
      _isPaused = !_isPaused;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pool?.dispose();
    _session?.setActive(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Timer App')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Round: $_currentRound / $_totalRounds',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              '$_secondsRemaining',
              style: TextStyle(fontSize: 72, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: !_isRunning ? startTimer : null,
                  child: Text('Start Timer'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: _isRunning ? togglePauseResume : null,
                  child: Text(_isPaused ? 'Resume' : 'Pause'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
