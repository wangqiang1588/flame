import 'package:meta/meta.dart';

import '../components/position_component.dart';
import 'effects.dart';

class SequenceEffect extends PositionComponentEffect {
  final List<PositionComponentEffect> effects;
  int _currentIndex;
  PositionComponentEffect currentEffect;
  bool _currentWasAlternating;
  double _driftModifier;

  SequenceEffect({
    @required this.effects,
    bool isInfinite = false,
    bool isAlternating = false,
    void Function() onComplete,
  }) : super(isInfinite, isAlternating, onComplete: onComplete) {
    assert(
      effects.every((effect) => effect.component == null),
      'Each effect can only be added once',
    );
    assert(
      effects.every((effect) => !effect.isInfinite),
      'No effects added to the sequence can be infinite',
    );
  }

  @override
  void initialize(PositionComponent component) {
    super.initialize(component);
    _currentIndex = 0;
    _driftModifier = 0.0;

    effects.forEach((effect) {
      effect.reset();
      component.position.setFrom(endPosition);
      component.angle = endAngle;
      component.size.setFrom(endSize);
      effect.initialize(component);
      endPosition = effect.endPosition;
      endAngle = effect.endAngle;
      endSize = effect.endSize;
    });
    // Add all the effects iteration time since they can alternate within the
    // sequence effect
    peakTime = effects.fold(
      0,
      (time, effect) => time + effect.iterationTime,
    );
    if (isAlternating) {
      endPosition = originalPosition;
      endAngle = originalAngle;
      endSize = originalSize;
    }
    component.position.setFrom(originalPosition);
    component.angle = originalAngle;
    component.size.setFrom(originalSize);
    currentEffect = effects.first;
    _currentWasAlternating = currentEffect.isAlternating;
  }

  @override
  void update(double dt) {
    super.update(dt);

    // If the last effect's time to completion overshot its total time, add that
    // time to the first time step of the next effect.
    currentEffect.update(dt + _driftModifier);
    _driftModifier = 0.0;
    if (currentEffect.hasCompleted()) {
      currentEffect.setComponentToEndState();
      _driftModifier = currentEffect.driftTime;
      _currentIndex++;
      final orderedEffects =
          curveDirection.isNegative ? effects.reversed.toList() : effects;
      // Make sure the current effect has the `isAlternating` value it
      // initially started with
      currentEffect.isAlternating = _currentWasAlternating;
      // Get the next effect that should be executed
      currentEffect = orderedEffects[_currentIndex % effects.length];
      // Keep track of what value of `isAlternating` the effect had from the
      // start
      _currentWasAlternating = currentEffect.isAlternating;
      if (isAlternating &&
          !currentEffect.isAlternating &&
          curveDirection.isNegative) {
        // Make the effect go in reverse
        currentEffect.isAlternating = true;
      }
    }
  }

  @override
  void reset() {
    super.reset();
    effects.forEach((e) => e.reset());
    if (component != null) {
      initialize(component);
    }
  }
}
