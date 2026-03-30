import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// 连续液面位移场。
///
/// 这里不再保存一组“扩散中的波纹对象”，而是维护一张低分辨率高度图和速度图。
/// 这样每次交互都只是向场里注入扰动，后续扩散、干涉和衰减统一交给场本身推进，
/// 折射边界会比离散波纹列表更连贯，也更接近后续 shader 方案的思路。
class LiquidDisplacementField {
  LiquidDisplacementField({
    required this.cellSize,
    required this.stiffness,
    required this.damping,
  });

  final double cellSize;
  final double stiffness;
  final double damping;

  Size _size = Size.zero;
  int _columns = 0;
  int _rows = 0;
  List<double> _height = <double>[];
  List<double> _velocity = <double>[];
  List<double> _nextHeight = <double>[];
  double _peakEnergy = 0.0;
  int _revision = 0;

  Size get size => _size;
  int get columns => _columns;
  int get rows => _rows;
  bool get isReady => _columns > 0 && _rows > 0;
  int get revision => _revision;

  /// 动画继续播放的最小能量阈值。
  ///
  /// 这个值不能只看某一帧的视觉强弱，还要兼顾 ticker 什么时候该停。
  /// 阈值太低，液面明明已经回到静止，动画还会多跑不少空帧；
  /// 阈值太高，细小波纹刚扩开就会被当成“已经结束”。
  ///
  /// 这里按刚度和阻尼做一个很轻的动态收口：
  /// - 刚度高时，波峰回弹更快，能量衰减阶段更尖，需要略高一点阈值避免尾巴拖太久
  /// - 阻尼低时，场会保留更多余波，也需要略高一点阈值防止 ticker 长时间空转
  ///
  /// 范围仍然收在接近原来 `0.0008` 的附近，目的是保留既有手感，只把极端配置下的停表时机收得更稳。
  double get _activityThreshold {
    final normalizedStiffness = stiffness.clamp(0.0, 1.0);
    final retainedEnergy = (1.0 - damping).clamp(0.0, 1.0);
    return (0.00055 +
            (normalizedStiffness * 0.0011) +
            (retainedEnergy * 0.012))
        .clamp(0.0007, 0.0014);
  }

  /// 当前场里是否还有足够明显的扰动。
  ///
  /// 这里不直接遍历整张图判断，而是复用每次更新过程里记录的峰值。
  /// 这样动画是否继续播放可以更轻地决策，避免为了停表反复全量扫描。
  bool get hasActivity => _peakEnergy > _activityThreshold;

  void resize(Size size) {
    if (!size.isFinite || size.isEmpty) {
      _size = Size.zero;
      _columns = 0;
      _rows = 0;
      _height = <double>[];
      _velocity = <double>[];
      _nextHeight = <double>[];
      _peakEnergy = 0.0;
      _revision++;
      return;
    }

    final nextColumns = math.max(2, (size.width / cellSize).ceil() + 1);
    final nextRows = math.max(2, (size.height / cellSize).ceil() + 1);
    if (_size == size && nextColumns == _columns && nextRows == _rows) {
      return;
    }

    _size = size;
    _columns = nextColumns;
    _rows = nextRows;
    final total = _columns * _rows;
    _height = List<double>.filled(total, 0.0, growable: false);
    _velocity = List<double>.filled(total, 0.0, growable: false);
    _nextHeight = List<double>.filled(total, 0.0, growable: false);
    _peakEnergy = 0.0;
    _revision++;
  }

  void clear() {
    for (var index = 0; index < _height.length; index++) {
      _height[index] = 0.0;
      _velocity[index] = 0.0;
      _nextHeight[index] = 0.0;
    }
    _peakEnergy = 0.0;
    _revision++;
  }

  /// 在液面上注入一个局部扰动。
  ///
  /// 首次交互更适合直接改速度而不是硬改高度。
  /// 这样波峰不会像贴图那样瞬间鼓起一块，而是先受到冲击，再自然往外扩散。
  void addImpulse(
    Offset point, {
    required double radius,
    required double strength,
  }) {
    if (!isReady || radius <= 0 || strength == 0) {
      return;
    }

    _applyImpulse(
      point,
      radius: radius,
      strength: strength,
      direction: Offset.zero,
    );
    _peakEnergy = math.max(_peakEnergy, strength.abs());
    _revision++;
  }

  /// 注入更像雨滴落水的扰动。
  ///
  /// 手势更适合“连续推一把”的能量分布，雨滴则相反，
  /// 它需要一个更尖的落点和更明确的外扩波圈。
  /// 这里不新建独立的雨滴对象，而是直接往同一张位移场里压入几道同心环，
  /// 这样自动雨滴和手势波纹还能自然叠加，不会出现两套系统互相打架的问题。
  void addRaindrop(
    Offset point, {
    required double radius,
    required double strength,
    required int rippleCount,
    required double travelFactor,
  }) {
    if (!isReady || radius <= 0 || strength == 0) {
      return;
    }

    final resolvedRippleCount = math.max(1, rippleCount);
    final resolvedTravelFactor = math.max(0.4, travelFactor);

    // 雨滴落下时，中心区域会先被砸出一个短促的凹陷，
    // 紧接着第一圈回弹才会最明显。
    // 如果这里只有单峰包络，画面会更像轻微鼓包，不像“砸到水面”的感觉。
    _applyRingImpulse(
      point,
      targetRadius: 0,
      bandWidth: radius * 0.2,
      strength: -strength * 0.38,
    );
    _applyRingImpulse(
      point,
      targetRadius: radius * 0.34,
      bandWidth: radius * 0.18,
      strength: strength,
    );

    for (var ringIndex = 0; ringIndex < resolvedRippleCount; ringIndex++) {
      final progress = ringIndex / resolvedRippleCount;
      final ringRadius =
          radius * (0.72 + (resolvedTravelFactor * progress));
      final bandWidth = radius * (0.14 + (progress * 0.08));
      final ringStrength = strength * math.pow(0.72, ringIndex + 1).toDouble();

      _applyRingImpulse(
        point,
        targetRadius: ringRadius,
        bandWidth: bandWidth,
        strength: ringStrength,
      );
      _applyRingImpulse(
        point,
        targetRadius: ringRadius + (bandWidth * 0.72),
        bandWidth: bandWidth * 0.86,
        strength: -ringStrength * 0.42,
      );
    }

    _peakEnergy = math.max(_peakEnergy, strength.abs());
    _revision++;
  }

  /// 沿拖动路径连续注入扰动。
  ///
  /// 拖动时如果只在当前指针位置打一针，液面会表现成一串离散鼓包，
  /// 视觉上更像“点按很多次”，不像真实表面被手势拖拽后的连续牵引。
  /// 这里把一段移动拆成多次低强度注入，让能量沿路径铺开，波纹会顺很多。
  void addImpulseTrail(
    Offset from,
    Offset to, {
    required double radius,
    required double strength,
  }) {
    if (!isReady || radius <= 0 || strength == 0) {
      return;
    }

    final delta = to - from;
    final distance = delta.distance;
    if (distance <= 0.001) {
      addImpulse(to, radius: radius, strength: strength);
      return;
    }

    final stepDistance = math.max(cellSize * 0.55, radius * 0.22);
    final steps = math.max(1, (distance / stepDistance).ceil());
    final direction = delta / distance;
    final sampleStrength = strength / math.sqrt(steps);

    for (var step = 0; step <= steps; step++) {
      final t = step / steps;
      final position = Offset.lerp(from, to, t)!;
      final envelope = 0.78 + ((1.0 - ((t - 0.5).abs() * 2.0)) * 0.22);
      _applyImpulse(
        position,
        radius: radius,
        strength: sampleStrength * envelope,
        direction: direction,
      );
    }

    _peakEnergy = math.max(_peakEnergy, strength.abs());
    _revision++;
  }

  void _applyImpulse(
    Offset point, {
    required double radius,
    required double strength,
    required Offset direction,
  }) {
    final radiusInCells = math.max(1.0, radius / cellSize);
    final centerColumn = point.dx / cellSize;
    final centerRow = point.dy / cellSize;
    final minColumn = math.max(0, (centerColumn - radiusInCells).floor());
    final maxColumn = math.min(
      _columns - 1,
      (centerColumn + radiusInCells).ceil(),
    );
    final minRow = math.max(0, (centerRow - radiusInCells).floor());
    final maxRow = math.min(_rows - 1, (centerRow + radiusInCells).ceil());

    for (var row = minRow; row <= maxRow; row++) {
      for (var column = minColumn; column <= maxColumn; column++) {
        final cellCenter = Offset(column * cellSize, row * cellSize);
        final distance = (cellCenter - point).distance;
        if (distance > radius) {
          continue;
        }

        final normalizedDistance = (distance / radius).clamp(0.0, 1.0);
        final core = (1.0 - (normalizedDistance / 0.42)).clamp(0.0, 1.0);
        final coreEnvelope = core * core * (3 - (2 * core));
        final ringDistance = ((normalizedDistance - 0.64).abs() / 0.24).clamp(
          0.0,
          1.0,
        );
        final ring = 1.0 - ringDistance;
        final ringEnvelope = ring * ring * (3 - (2 * ring));
        // 纯正向包络很容易把液面推成“鼓起来的一团”，视觉会偏黏稠。
        // 这里改成“中心抬起、外圈轻微回拉”的轮廓，让第一圈波纹更快成形，
        // 手感会更接近水面被点到或掠过后的回弹，而不是糖浆被搅动。
        var envelope = (coreEnvelope * 1.12) - (ringEnvelope * 0.26);
        if (direction != Offset.zero && distance > 0.001) {
          final radialDirection = (cellCenter - point) / distance;
          final directionalBias =
              (radialDirection.dx * direction.dx) +
              (radialDirection.dy * direction.dy);
          // 拖动时让运动方向前方略强、后方略弱。
          // 偏置幅度控制得比较小，目的是打破“圆章一样往外盖”的机械感，
          // 而不是把液面推成明显单向流体。
          envelope *= (1.0 + (directionalBias * 0.18)).clamp(0.82, 1.18);
        }
        final index = _indexOf(column, row);
        _velocity[index] += strength * envelope;
      }
    }
  }

  /// 沿指定半径打出一圈环形能量。
  ///
  /// 雨滴的关键不是只有“中心有动静”，而是外圈能不能干净地扩开。
  /// 这里单独做环形注入，是为了让第一圈、第二圈在初始阶段就有清楚的轮廓，
  /// 不必完全等场自己慢慢推出来，画面会更接近“滴在水面上”的第一反应。
  void _applyRingImpulse(
    Offset point, {
    required double targetRadius,
    required double bandWidth,
    required double strength,
  }) {
    final safeBandWidth = math.max(cellSize * 0.45, bandWidth);
    final extent = targetRadius + safeBandWidth;
    final extentInCells = math.max(1.0, extent / cellSize);
    final centerColumn = point.dx / cellSize;
    final centerRow = point.dy / cellSize;
    final minColumn = math.max(0, (centerColumn - extentInCells).floor());
    final maxColumn = math.min(
      _columns - 1,
      (centerColumn + extentInCells).ceil(),
    );
    final minRow = math.max(0, (centerRow - extentInCells).floor());
    final maxRow = math.min(_rows - 1, (centerRow + extentInCells).ceil());

    for (var row = minRow; row <= maxRow; row++) {
      for (var column = minColumn; column <= maxColumn; column++) {
        final cellCenter = Offset(column * cellSize, row * cellSize);
        final distance = (cellCenter - point).distance;
        if (distance > extent) {
          continue;
        }

        final bandDistance = ((distance - targetRadius).abs() / safeBandWidth)
            .clamp(0.0, 1.0);
        final ring = 1.0 - bandDistance;
        final envelope = ring * ring * (3 - (2 * ring));
        final index = _indexOf(column, row);
        _velocity[index] += strength * envelope;
      }
    }
  }

  void update(double dt) {
    if (!isReady || dt <= 0) {
      return;
    }

    final step = dt * 60.0;
    var nextPeakEnergy = 0.0;

    for (var row = 0; row < _rows; row++) {
      for (var column = 0; column < _columns; column++) {
        final index = _indexOf(column, row);
        final currentHeight = _height[index];

        if (_isEdge(column, row)) {
          _velocity[index] *= damping;
          _nextHeight[index] = currentHeight * damping;
          nextPeakEnergy = math.max(
            nextPeakEnergy,
            math.max(_nextHeight[index].abs(), _velocity[index].abs()),
          );
          continue;
        }

        final left = _height[_indexOf(column - 1, row)];
        final right = _height[_indexOf(column + 1, row)];
        final top = _height[_indexOf(column, row - 1)];
        final bottom = _height[_indexOf(column, row + 1)];
        final topLeft = _height[_indexOf(column - 1, row - 1)];
        final topRight = _height[_indexOf(column + 1, row - 1)];
        final bottomLeft = _height[_indexOf(column - 1, row + 1)];
        final bottomRight = _height[_indexOf(column + 1, row + 1)];
        final averageNeighbor =
            ((left + right + top + bottom) * 0.18) +
            ((topLeft + topRight + bottomLeft + bottomRight) * 0.07);
        final acceleration = (averageNeighbor - currentHeight) * stiffness;
        final edgeAbsorption = _edgeAbsorption(column, row);

        final nextVelocity =
            (_velocity[index] + (acceleration * step)) *
            damping *
            edgeAbsorption;
        final nextHeight = currentHeight + (nextVelocity * step);

        _velocity[index] = nextVelocity;
        _nextHeight[index] = nextHeight;
        nextPeakEnergy = math.max(
          nextPeakEnergy,
          math.max(nextHeight.abs(), nextVelocity.abs()),
        );
      }
    }

    final current = _height;
    _height = _nextHeight;
    _nextHeight = current;
    _peakEnergy = nextPeakEnergy;
    _revision++;
  }

  LiquidFieldSample sample(Offset point) {
    if (!isReady) {
      return const LiquidFieldSample(
        offset: Offset.zero,
        energy: 0.0,
        height: 0.0,
        speed: 0.0,
      );
    }

    final normalizedColumn = (point.dx / cellSize).clamp(0.0, _columns - 1.001);
    final normalizedRow = (point.dy / cellSize).clamp(0.0, _rows - 1.001);
    final baseColumn = normalizedColumn.floor();
    final baseRow = normalizedRow.floor();
    final nextColumn = math.min(baseColumn + 1, _columns - 1);
    final nextRow = math.min(baseRow + 1, _rows - 1);
    final tx = normalizedColumn - baseColumn;
    final ty = normalizedRow - baseRow;

    final h00 = _height[_indexOf(baseColumn, baseRow)];
    final h10 = _height[_indexOf(nextColumn, baseRow)];
    final h01 = _height[_indexOf(baseColumn, nextRow)];
    final h11 = _height[_indexOf(nextColumn, nextRow)];
    final centerHeight = _bilinear(h00, h10, h01, h11, tx, ty);
    final v00 = _velocity[_indexOf(baseColumn, baseRow)];
    final v10 = _velocity[_indexOf(nextColumn, baseRow)];
    final v01 = _velocity[_indexOf(baseColumn, nextRow)];
    final v11 = _velocity[_indexOf(nextColumn, nextRow)];
    final centerVelocity = _bilinear(v00, v10, v01, v11, tx, ty);

    final sampleColumn = baseColumn.clamp(1, _columns - 2);
    final sampleRow = baseRow.clamp(1, _rows - 2);
    final left = _height[_indexOf(sampleColumn - 1, sampleRow)];
    final right = _height[_indexOf(sampleColumn + 1, sampleRow)];
    final top = _height[_indexOf(sampleColumn, sampleRow - 1)];
    final bottom = _height[_indexOf(sampleColumn, sampleRow + 1)];
    final gradientX = (right - left) * 0.5;
    final gradientY = (bottom - top) * 0.5;
    final energy = (gradientX.abs() + gradientY.abs() + centerHeight.abs())
        .clamp(0.0, 1.0);

    return LiquidFieldSample(
      offset: Offset(gradientX, gradientY),
      energy: energy,
      height: centerHeight.clamp(-1.0, 1.0),
      speed: centerVelocity.abs().clamp(0.0, 1.0),
    );
  }

  LiquidFieldSample sampleAtCell(int column, int row) {
    if (!isReady) {
      return const LiquidFieldSample(
        offset: Offset.zero,
        energy: 0.0,
        height: 0.0,
        speed: 0.0,
      );
    }

    final sampleColumn = column.clamp(1, _columns - 2);
    final sampleRow = row.clamp(1, _rows - 2);
    final centerHeight = _height[_indexOf(sampleColumn, sampleRow)];
    final centerVelocity = _velocity[_indexOf(sampleColumn, sampleRow)];
    final left = _height[_indexOf(sampleColumn - 1, sampleRow)];
    final right = _height[_indexOf(sampleColumn + 1, sampleRow)];
    final top = _height[_indexOf(sampleColumn, sampleRow - 1)];
    final bottom = _height[_indexOf(sampleColumn, sampleRow + 1)];
    final gradientX = (right - left) * 0.5;
    final gradientY = (bottom - top) * 0.5;
    final energy = (gradientX.abs() + gradientY.abs() + centerHeight.abs())
        .clamp(0.0, 1.0);

    return LiquidFieldSample(
      offset: Offset(gradientX, gradientY),
      energy: energy,
      height: centerHeight.clamp(-1.0, 1.0),
      speed: centerVelocity.abs().clamp(0.0, 1.0),
    );
  }

  int _indexOf(int column, int row) => (row * _columns) + column;

  bool _isEdge(int column, int row) {
    return column == 0 ||
        row == 0 ||
        column == _columns - 1 ||
        row == _rows - 1;
  }

  double _edgeAbsorption(int column, int row) {
    final edgeDistance = math.min(
      math.min(column, _columns - 1 - column),
      math.min(row, _rows - 1 - row),
    );
    const edgeBand = 4;
    if (edgeDistance >= edgeBand) {
      return 1.0;
    }

    final normalized = edgeDistance / edgeBand;
    // 边缘附近额外增加一点吸收，减少波纹撞边后整排反弹的生硬感。
    // 这里不直接把边缘钉死为 0，是为了保留一点自然回弹，避免液面像被硬裁切。
    return 0.86 + (normalized * 0.14);
  }

  double _bilinear(
    double h00,
    double h10,
    double h01,
    double h11,
    double tx,
    double ty,
  ) {
    final top = h00 + ((h10 - h00) * tx);
    final bottom = h01 + ((h11 - h01) * tx);
    return top + ((bottom - top) * ty);
  }
}

class LiquidFieldSample {
  const LiquidFieldSample({
    required this.offset,
    required this.energy,
    required this.height,
    required this.speed,
  });

  final Offset offset;
  final double energy;
  final double height;
  final double speed;
}
