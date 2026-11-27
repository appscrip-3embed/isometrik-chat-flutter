import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Stacks `media` above `caption` and caps the caption's width at the
/// media's laid-out width, so a long caption wraps at the image / video /
/// grid edge instead of stretching the bubble wider than the media.
///
/// The media width can change at runtime (e.g. an image's aspect ratio
/// resolves after load); the caption follows it on the next layout.
class IsmChatMediaCaptionLayout extends MultiChildRenderObjectWidget {
  IsmChatMediaCaptionLayout({
    super.key,
    required Widget media,
    Widget? caption,
  }) : super(children: [media, if (caption != null) caption]);

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMediaCaptionLayout();
}

class _MediaCaptionParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderMediaCaptionLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MediaCaptionParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MediaCaptionParentData> {
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MediaCaptionParentData) {
      child.parentData = _MediaCaptionParentData();
    }
  }

  RenderBox? get _media => firstChild;
  RenderBox? get _caption => childAfter(firstChild!);

  /// Media is laid out loosely; caption gets max width = media width.
  BoxConstraints _captionConstraints(double mediaWidth) =>
      BoxConstraints(maxWidth: mediaWidth);

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final media = _media;
    if (media == null) return constraints.smallest;
    final loose = constraints.loosen();
    final mediaSize =
        dry ? media.getDryLayout(loose) : _layoutChild(media, loose);
    final caption = childCount > 1 ? _caption : null;
    var captionHeight = 0.0;
    if (caption != null) {
      final c = _captionConstraints(mediaSize.width);
      final captionSize =
          dry ? caption.getDryLayout(c) : _layoutChild(caption, c);
      captionHeight = captionSize.height;
      if (!dry) {
        (caption.parentData! as _MediaCaptionParentData).offset =
            Offset(0, mediaSize.height);
      }
    }
    if (!dry) {
      (media.parentData! as _MediaCaptionParentData).offset = Offset.zero;
    }
    return constraints.constrain(
      Size(mediaSize.width, mediaSize.height + captionHeight),
    );
  }

  Size _layoutChild(RenderBox child, BoxConstraints c) {
    child.layout(c, parentUsesSize: true);
    return child.size;
  }

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  // Width comes from the media only; the caption never widens the layout.
  @override
  double computeMinIntrinsicWidth(double height) =>
      _media?.getMinIntrinsicWidth(height) ?? 0;

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _media?.getMaxIntrinsicWidth(height) ?? 0;

  @override
  double computeMinIntrinsicHeight(double width) => _intrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) => _intrinsicHeight(width);

  double _intrinsicHeight(double width) {
    final media = _media;
    if (media == null) return 0;
    final mediaHeight = media.getMaxIntrinsicHeight(width);
    final caption = childCount > 1 ? _caption : null;
    if (caption == null) return mediaHeight;
    final mediaWidth = math.min(width, media.getMaxIntrinsicWidth(mediaHeight));
    return mediaHeight + caption.getMaxIntrinsicHeight(mediaWidth);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) =>
      defaultComputeDistanceToFirstActualBaseline(baseline);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);
}
