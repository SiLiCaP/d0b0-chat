// SPDX-FileCopyrightText: 2026 Contributors to d0b0 chat
//
// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:math';
import 'dart:ui' show BoxHeightStyle;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Lays out a message and its time and status the way Telegram does.
///
/// The [children] are the content and the meta, in that order. If the last
/// line of the content's last text leaves room for the meta, the meta sits
/// at the bottom right of that line and the bubble grows only if the line
/// and the meta together are wider than the content. Otherwise the meta
/// gets a row of its own below.
class BubbleMetaLayout extends MultiChildRenderObjectWidget {
  const BubbleMetaLayout({required super.children, super.key});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderBubbleMetaLayout();
}

class _MetaParentData extends ContainerBoxParentData<RenderBox> {}

class _RenderBubbleMetaLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _MetaParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _MetaParentData> {
  RenderBox get _content => firstChild!;
  RenderBox get _meta => childAfter(firstChild!)!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _MetaParentData) {
      child.parentData = _MetaParentData();
    }
  }

  /// Right edge of the last line and bottom of the content's last text, in
  /// the content's coordinates, or null for content that is not text and
  /// right-to-left text. The line boxes use the full line height, so leading
  /// under the last line does not count as content below it.
  Offset? _lastLineEnd() {
    RenderParagraph? last;
    void visit(RenderObject object) {
      if (object is RenderParagraph) {
        // Not its inline widgets: they come after it in tree order.
        last = object;
        return;
      }
      object.visitChildren(visit);
    }

    visit(_content);
    final paragraph = last;
    if (paragraph == null || paragraph.textDirection != TextDirection.ltr) {
      return null;
    }
    final length = paragraph.text.toPlainText(includeSemanticsLabels: false);
    final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: length.length),
      boxHeightStyle: BoxHeightStyle.max,
    );
    if (boxes.isEmpty) return null;
    final bottom = boxes.map((b) => b.bottom).reduce(max);
    final right = boxes
        .where((b) => b.bottom >= bottom - 0.5)
        .map((b) => b.right)
        .reduce(max);
    final toContent = paragraph.getTransformTo(_content);
    return MatrixUtils.transformPoint(toContent, Offset(right, bottom));
  }

  @override
  void performLayout() {
    final loose = constraints.loosen();
    _content.layout(loose, parentUsesSize: true);
    _meta.layout(loose, parentUsesSize: true);
    final content = _content.size;
    final meta = _meta.size;

    // Nothing but the content's own padding may lie below the last line.
    const bottomPadding = 12.0;
    final end = _lastLineEnd();
    final inline =
        end != null &&
        content.height - end.dy <= bottomPadding &&
        end.dx + meta.width <= loose.maxWidth;

    final double width;
    final double height;
    if (inline) {
      width = max(content.width, end.dx + meta.width);
      height = content.height;
    } else {
      width = max(content.width, meta.width);
      height = content.height + meta.height;
    }
    size = constraints.constrain(Size(width, height));

    (_content.parentData! as _MetaParentData).offset = Offset.zero;
    (_meta.parentData! as _MetaParentData).offset = Offset(
      size.width - meta.width,
      size.height - meta.height,
    );
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final loose = constraints.loosen();
    final content = _content.getDryLayout(loose);
    final meta = _meta.getDryLayout(loose);
    return constraints.constrain(
      Size(max(content.width, meta.width), content.height + meta.height),
    );
  }

  @override
  double computeMinIntrinsicWidth(double height) => max(
    _content.getMinIntrinsicWidth(height),
    _meta.getMinIntrinsicWidth(height),
  );

  @override
  double computeMaxIntrinsicWidth(double height) => max(
    _content.getMaxIntrinsicWidth(height),
    _meta.getMaxIntrinsicWidth(height),
  );

  @override
  double computeMinIntrinsicHeight(double width) =>
      _content.getMinIntrinsicHeight(width) +
      _meta.getMinIntrinsicHeight(width);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _content.getMaxIntrinsicHeight(width) +
      _meta.getMaxIntrinsicHeight(width);

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
