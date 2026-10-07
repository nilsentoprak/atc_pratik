import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

void main() => runApp(const AtcApp());

class AtcApp extends StatelessWidget {
  const AtcApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'ATC Pratik',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        home: const FlightScreen(),
      );
}

class Step {
  final String phase; // uçuş evresi etiketi
  final String tower; // kulenin söylediği
  final String expected; // beklenen geri okuma
  const Step(this.phase, this.tower, this.expected);
}

const callsign = 'Cessna one two three';

const steps = <Step>[
  Step(
    'Taksi',
    '$callsign, taxi to holding point runway three six via Alpha, hold short runway three six.',
    'taxi to holding point runway three six via Alpha hold short runway three six $callsign',
  ),
  Step(
    'Kalkış',
    '$callsign, wind three five zero degrees eight knots, runway three six, cleared for takeoff.',
    'cleared for takeoff runway three six $callsign',
  ),
  Step(
    'Transponder',
    '$callsign, squawk four five two one.',
    'squawk four five two one $callsign',
  ),
  Step(
    'Tırmanış',
    '$callsign, climb and maintain flight level niner zero.',
    'climb and maintain flight level niner zero $callsign',
  ),
  Step(
    'İniş',
    '$callsign, runway three six, cleared to land.',
    'cleared to land runway three six $callsign',
  ),
];

const _numMap = {
  'zero': '0', 'one': '1', 'two': '2', 'three': '3', 'tree': '3',
  'four': '4', 'five': '5', 'fife': '5', 'six': '6', 'seven': '7',
  'eight': '8', 'nine': '9', 'niner': '9',
};

/// Sayıları ("four" / "4" / "45") tek tek rakamlara çevirir.
List<String> tokenize(String s) {
  final out = <String>[];
  final cleaned = s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  for (final w in cleaned.split(RegExp(r'\s+'))) {
    if (w.isEmpty) continue;
    if (_numMap.containsKey(w)) {
      out.add(_numMap[w]!);
    } else if (RegExp(r'^\d+$').hasMatch(w)) {
      out.addAll(w.split(''));
    } else {
      out.add(w);
    }
  }
  return out;
}

enum Phase { idle, tower, ready, listening, result, finished }

class FlightScreen extends StatefulWidget {
  const FlightScreen({super.key});

  @override
  State<FlightScreen> createState() => _FlightScreenState();
}

class _FlightScreenState extends State<FlightScreen> {
  final tts = FlutterTts();
  final stt = SpeechToText();
  bool sttReady = false;

  Phase phase = Phase.idle;
  int step = 0;
  String heard = '';
  List<String> expectedTokens = [];
  List<bool> matched = [];
  final List<double?> scores = List.filled(steps.length, null);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await tts.setLanguage('en-US');
    await tts.setSpeechRate(0.45);
    await tts.awaitSpeakCompletion(true);
    sttReady = await stt.initialize(
      onError: (e) => debugPrint('stt: $e'),
      onStatus: (s) {
        // Tanıyıcı kendiliğinden durursa (sessizlik vb.) sonucu göster.
        if ((s == 'done' || s == 'notListening') && phase == Phase.listening) {
          Future.delayed(const Duration(milliseconds: 400), finish);
        }
      },
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    tts.stop();
    stt.cancel();
    super.dispose();
  }

  // --- Akış ---------------------------------------------------------------

  Future<void> startStep() async {
    setState(() {
      phase = Phase.tower;
      heard = '';
    });
    await tts.speak(steps[step].tower);
    if (mounted && phase == Phase.tower) setState(() => phase = Phase.ready);
  }

  Future<void> onMicTap() async {
    switch (phase) {
      case Phase.tower:
        await tts.stop(); // kuleyi kes, hemen konuşmaya geç
        await startListening();
      case Phase.ready:
        await startListening();
      case Phase.listening:
        await stopListening();
      default:
        break;
    }
  }

  Future<void> startListening() async {
    if (!sttReady) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mikrofon / konuşma tanıma izni yok ya da desteklenmiyor.')));
      return;
    }
    setState(() {
      phase = Phase.listening;
      heard = '';
    });
    await stt.listen(
      localeId: 'en_US',
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 6),
      onResult: (r) {
        if (!mounted) return;
        setState(() => heard = r.recognizedWords);
        if (r.finalResult) finish();
      },
    );
  }

  Future<void> stopListening() async {
    await stt.stop();
    await Future.delayed(const Duration(milliseconds: 350));
    finish();
  }

  void finish() {
    if (!mounted || phase != Phase.listening) return;
    stt.stop();
    expectedTokens = tokenize(steps[step].expected);
    final pool = tokenize(heard);
    matched = [];
    for (final t in expectedTokens) {
      final i = pool.indexOf(t);
      if (i >= 0) {
        pool.removeAt(i);
        matched.add(true);
      } else {
        matched.add(false);
      }
    }
    scores[step] = matched.where((m) => m).length / expectedTokens.length;
    setState(() => phase = Phase.result);
  }

  void retry() {
    scores[step] = null;
    setState(() {
      heard = '';
      phase = Phase.ready;
    });
  }

  void next() {
    if (step == steps.length - 1) {
      setState(() => phase = Phase.finished);
    } else {
      step++;
      startStep();
    }
  }

  void restart() {
    for (var i = 0; i < scores.length; i++) {
      scores[i] = null;
    }
    step = 0;
    setState(() => phase = Phase.idle);
  }

  // --- Arayüz -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ATC Telsiz Pratiği')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (phase) {
          Phase.idle => idleView(),
          Phase.finished => finishedView(),
          _ => flightView(),
        },
      ),
    );
  }

  Widget idleView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.flight_takeoff, size: 72),
            const SizedBox(height: 16),
            Text('Çağrı adın: $callsign',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Kuleyi dinle, mikrofon düğmesine basıp geri okumayı söyle.\n'
              'Bitirince düğmeye tekrar bas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: startStep,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Uçuşa başla'),
            ),
          ],
        ),
      );

  Widget flightView() {
    final s = steps[step];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Evre ${step + 1}/${steps.length}: ${s.phase}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: (step + 1) / steps.length),
        const SizedBox(height: 16),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.cell_tower),
                    title: const Text('KULE'),
                    subtitle: Text(s.tower,
                        style: const TextStyle(fontSize: 18, height: 1.4)),
                    trailing: IconButton(
                      icon: const Icon(Icons.replay),
                      tooltip: 'Tekrar dinle',
                      onPressed: (phase == Phase.tower || phase == Phase.listening)
                          ? null
                          : () => tts.speak(s.tower),
                    ),
                  ),
                ),
                if (heard.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Senin söylediğin:'),
                  Text('"$heard"', style: const TextStyle(fontSize: 18)),
                ],
                if (phase == Phase.result) ...[
                  const SizedBox(height: 16),
                  const Text('Doğru geri okuma (yeşil = söyledin, kırmızı = eksik):'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var i = 0; i < expectedTokens.length; i++)
                        Chip(
                          label: Text(expectedTokens[i]),
                          backgroundColor: matched[i]
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Puan: %${((scores[step] ?? 0) * 100).round()}',
                      style: Theme.of(context).textTheme.titleLarge),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (phase == Phase.result)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: retry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar dene'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: next,
                  child: Text(step == steps.length - 1 ? 'Bitir' : 'Sonraki evre'),
                ),
              ),
            ],
          )
        else
          micButton(),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget micButton() {
    final listening = phase == Phase.listening;
    final label = switch (phase) {
      Phase.tower => 'Kule konuşuyor... (atlamak için mikrofona bas)',
      Phase.ready => 'Konuşmak için mikrofona bas',
      Phase.listening => 'Dinliyorum... bitirince tekrar bas',
      _ => '',
    };
    return Column(
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: FilledButton(
            style: FilledButton.styleFrom(
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              backgroundColor: listening ? Colors.redAccent : null,
            ),
            onPressed: onMicTap,
            child: Icon(listening ? Icons.stop : Icons.mic, size: 40),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, textAlign: TextAlign.center),
      ],
    );
  }

  Widget finishedView() {
    final done = scores.whereType<double>().toList();
    final avg = done.isEmpty ? 0.0 : done.reduce((a, b) => a + b) / done.length;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.flight_land, size: 72),
          const SizedBox(height: 16),
          Text('Uçuş tamamlandı',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('Ortalama doğruluk: %${(avg * 100).round()}',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            Text('${steps[i].phase}: %${((scores[i] ?? 0) * 100).round()}'),
          const SizedBox(height: 24),
          FilledButton(onPressed: restart, child: const Text('Yeni uçuş')),
        ],
      ),
    );
  }
}