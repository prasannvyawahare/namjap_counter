import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/mala_calculator.dart';
import '../../providers/counter_controller.dart';
import '../../providers/service_providers.dart';
import '../../providers/settings_controller.dart';
import '../../services/dnd_service.dart';
import '../../services/volume_button_service.dart';
import '../../services/wakelock_service.dart';
import 'widgets/focus_target_sheet.dart';

/// Distraction-free counting: one enormous number on a dim field, the whole
/// screen a tap target, nothing else competing for attention.
///
/// The dashboard is built for *glancing* — cards, totals, a goal bar, all
/// scaled to fit at once. That density is exactly wrong for a half-hour sitting
/// where the eyes should rest and the thumb should not have to aim. Focus mode
/// is the other half: it holds the screen awake and silences the phone for as
/// long as it is open, and can stop the session at a chosen number of Malas.
///
/// Counts go through the same [counterProvider] as everywhere else, so a Focus
/// session is not a separate tally — it feeds today's count, history and
/// statistics exactly as the dashboard buttons do.
class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key, this.targetMala = 0});

  /// Session target in Malas; `0` means count freely.
  final int targetMala;

  /// Ask for a target, then open the session. Does nothing if the sheet is
  /// dismissed without choosing.
  static Future<void> open(BuildContext context) async {
    final target = await FocusTargetSheet.show(context);
    if (target == null || !context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FocusScreen(targetMala: target)));
  }

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const Color _dim = Color(0xFF05070D);
  static const Duration _hintLinger = Duration(seconds: 6);

  late final AnimationController _pulse;
  late int _startCount;
  late int _targetMala;

  // Captured up front rather than read from `ref` during teardown. These are
  // plain Providers holding one instance for the app's life, so caching them
  // is free — and it means _disengage() cannot fail partway through and walk
  // away leaving the phone silenced or the volume keys pointed at a dead
  // screen, which is exactly what used to happen.
  late final WakelockService _wakelock;
  late final DndService _dnd;
  late final VolumeButtonService _volume;

  bool _targetMet = false;
  bool _showHint = true;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wakelock = ref.read(wakelockServiceProvider);
    _dnd = ref.read(dndServiceProvider);
    _volume = ref.read(volumeButtonServiceProvider);
    _targetMala = widget.targetMala;
    _startCount = ref.read(counterProvider).todayCount;
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    // Hide the status and navigation bars — "full screen" is the whole point.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _hintTimer = Timer(_hintLinger, () {
      if (mounted) setState(() => _showHint = false);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _engage());
  }

  /// Claim the screen and the phone's attention for the session. Unlike the
  /// dashboard, Focus mode does not consult the preferences — entering it *is*
  /// the request to stay lit and undisturbed.
  void _engage() {
    _wakelock.acquire(this);
    _dnd.acquire(this);
    // Take over the volume keys while we're on top. The dashboard is still
    // mounted underneath and its handlers would otherwise keep counting
    // straight through a completed session target.
    _volume.start(owner: this, onUp: _count, onDown: _undo);
  }

  /// Let go of everything this screen was holding — nothing more.
  ///
  /// It deliberately does not decide what the dashboard should get back. Each
  /// of these is held rather than switched, so releasing our claim is enough:
  /// the screen stays lit and the phone stays silent only for as long as
  /// somebody else still wants them. Restoring another screen's state from
  /// this one's teardown is what previously left the volume keys dead and the
  /// phone silenced with the Settings toggle insisting otherwise.
  void _disengage() {
    _wakelock.release(this);
    _dnd.release(this);
    _volume.stop(owner: this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      _engage();
    } else if (state == AppLifecycleState.paused) {
      _disengage();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hintTimer?.cancel();
    _disengage();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _pulse.dispose();
    super.dispose();
  }

  int get _targetCount => _targetMala * AppConstants.countsPerMala;

  int _sessionCount(int todayCount) {
    final done = todayCount - _startCount;
    return done < 0 ? 0 : done;
  }

  // Both guard on `mounted`: these are handed to the volume-key service, and a
  // stale reference reaching `ref` after teardown throws inside a stream
  // callback — invisible from the outside, and indistinguishable from the keys
  // simply not working.
  void _count() {
    if (_targetMet || !mounted) return;
    ref.read(counterProvider.notifier).increment();
  }

  void _undo() {
    if (_targetMet || !mounted) return;
    ref.read(counterProvider.notifier).decrement();
  }

  void _onCountChanged(int todayCount) {
    if (_targetMet || _targetMala <= 0) return;
    if (_sessionCount(todayCount) < _targetCount) return;
    setState(() => _targetMet = true);
    if (ref.read(settingsProvider).vibrationEnabled) {
      ref.read(hapticServiceProvider).celebrate();
    }
  }

  /// Dismiss the "target reached" pause and keep counting, now open-ended —
  /// the target has been served and re-arming it would just interrupt again a
  /// few beads later.
  void _continueFreely() {
    setState(() {
      _targetMet = false;
      _targetMala = 0;
    });
  }

  Future<void> _changeTarget() async {
    final picked = await FocusTargetSheet.show(
      context,
      initialMala: _targetMala,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _targetMala = picked;
      _targetMet = false;
      // Measure the new target from here, so switching mid-session doesn't
      // instantly complete (or silently swallow) what's already been counted.
      _startCount = ref.read(counterProvider).todayCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final counter = ref.watch(counterProvider);
    // Driven off the count rather than the tap handler, so a volume-key press
    // gets the same ripple and swell that a tap does.
    ref.listen<CounterState>(counterProvider, (prev, next) {
      if (prev?.todayCount == next.todayCount) return;
      if ((prev?.todayCount ?? 0) < next.todayCount) _pulse.forward(from: 0);
      _onCountChanged(next.todayCount);
    });

    final session = _sessionCount(counter.todayCount);
    final breakdown = MalaCalculator.breakdown(counter.todayCount);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _dim,
        body: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.0,
                    colors: [Color(0xFF18203A), _dim],
                  ),
                ),
              ),
            ),
            // The counting surface: everything that isn't an explicit control
            // is a tap target, so the thumb never has to find anything.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _count,
                onLongPress: _undo,
                child: _CountFace(
                  pulse: _pulse,
                  count: counter.todayCount,
                  malaText: breakdown.formatted,
                ),
              ),
            ),
            Positioned(
              left: 4,
              right: 4,
              top: 4,
              child: SafeArea(
                bottom: false,
                child: _TopBar(
                  targetMala: _targetMala,
                  sessionMala: MalaCalculator.malaCount(session),
                  onClose: () => Navigator.of(context).maybePop(),
                  onTapTarget: _changeTarget,
                ),
              ),
            ),
            Positioned(
              left: 32,
              right: 32,
              bottom: 28,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_targetMala > 0)
                      _SessionProgress(session: session, target: _targetCount),
                    AnimatedOpacity(
                      opacity: _showHint ? 1 : 0,
                      duration: const Duration(milliseconds: 800),
                      child: const Padding(
                        padding: EdgeInsets.only(top: 18),
                        child: Text(
                          'Tap anywhere to count · volume keys work too\n'
                          'Long-press to undo',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            color: Colors.white38,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_targetMet)
              Positioned.fill(
                child: _CompletionOverlay(
                  // Always the target that was actually met, which may not be
                  // the one the session opened with.
                  mala: _targetMala,
                  onContinue: _continueFreely,
                  onFinish: () => Navigator.of(context).maybePop(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The giant number, its Mala subtitle, and the ripple that answers each tap.
class _CountFace extends StatelessWidget {
  const _CountFace({
    required this.pulse,
    required this.count,
    required this.malaText,
  });

  final AnimationController pulse;
  final int count;
  final String malaText;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: pulse,
        builder: (context, child) {
          final t = pulse.value;
          // A half-sine so the number swells and settles back to exactly 1.0,
          // leaving no residual scale once the animation completes.
          final scale = 1 + 0.045 * math.sin(math.pi * t);
          return Stack(
            alignment: Alignment.center,
            children: [
              if (pulse.isAnimating)
                Container(
                  width: 160 + 260 * t,
                  height: 160 + 260 * t,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.saffron.withValues(alpha: 0.30 * (1 - t)),
                      width: 1.5,
                    ),
                  ),
                ),
              Transform.scale(scale: scale, child: child),
            ],
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              // A soft saffron bloom so the numeral sits in light rather than
              // floating on flat black.
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.saffron.withValues(alpha: 0.13),
                    blurRadius: 90,
                    spreadRadius: 30,
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      fontSize: 132,
                      height: 1.05,
                      fontWeight: FontWeight.w200,
                      letterSpacing: -4,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              malaText,
              style: const TextStyle(
                fontSize: 15,
                letterSpacing: 0.6,
                color: Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.targetMala,
    required this.sessionMala,
    required this.onClose,
    required this.onTapTarget,
  });

  final int targetMala;
  final int sessionMala;
  final VoidCallback onClose;
  final VoidCallback onTapTarget;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onClose,
          icon: const Icon(Icons.close, color: Colors.white38),
          tooltip: 'Leave focus mode',
        ),
        const Spacer(),
        TextButton.icon(
          onPressed: onTapTarget,
          icon: const Icon(
            Icons.flag_outlined,
            size: 16,
            color: Colors.white38,
          ),
          label: Text(
            targetMala > 0 ? '$sessionMala / $targetMala Mala' : 'No limit',
            style: const TextStyle(fontSize: 13, color: Colors.white38),
          ),
        ),
      ],
    );
  }
}

class _SessionProgress extends StatelessWidget {
  const _SessionProgress({required this.session, required this.target});

  final int session;
  final int target;

  @override
  Widget build(BuildContext context) {
    final value = target > 0 ? (session / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 3,
            backgroundColor: Colors.white12,
            valueColor: const AlwaysStoppedAnimation(AppTheme.saffron),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '$session / $target this session',
          style: const TextStyle(fontSize: 12, color: Colors.white38),
        ),
      ],
    );
  }
}

class _CompletionOverlay extends StatelessWidget {
  const _CompletionOverlay({
    required this.mala,
    required this.onContinue,
    required this.onFinish,
  });

  final int mala;
  final VoidCallback onContinue;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.self_improvement,
                size: 56,
                color: AppTheme.saffron,
              ),
              const SizedBox(height: 20),
              Text(
                '$mala Mala complete',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Your session target is done. Counting is paused.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white60),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onFinish,
                  child: const Text('Finish'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onContinue,
                  child: const Text(
                    'Keep chanting',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
