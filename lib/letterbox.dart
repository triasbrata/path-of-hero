// The game is landscape only (decisions-log 289; the owner, 2026-10-09: "game vertical di hapus saja, game force jadi
// horizontal"; of a view taller than wide: "Letterbox saja"). Wherever the view is taller than wide (a desktop window
// dragged tall, the web build on an upright phone) the landscape game shrinks to the view's width in a [letterboxAspect]
// rect, centred, with plain dark bars above and below it ([letterboxBar]); nothing of the game draws, takes a press or
// shows a tooltip in them. A phone itself is locked sideways (AndroidManifest.xml's sensorLandscape, main.dart's
// [landscapeOnly]). ui-hud.md "Layouts".
import 'dart:math' as math;

import 'package:flutter/services.dart' show PointerExitEventListener;
import 'package:flutter/widgets.dart';

/// The letterbox's width over its height: the tallest landscape size the game is laid out at, the owner's tablet's
/// 1164x777 (1.498).
const letterboxAspect = 1.5;

/// The narrowest the game is laid out at inside a letterbox, logical px: the phone's landscape width (915x412), the
/// narrowest landscape size the HUD is laid out and checked at. A narrower letterbox draws the game laid out at this width
/// (and [letterboxAspect]) scaled down to fit, so the HUD keeps its landscape layout: 915x610 at 0.45 on a 412-px phone.
const letterboxMinWidth = 915.0;

/// The bars' colour: the window's black.
const letterboxBar = Color(0xFF000000);

/// Where the game goes in a view of [view] logical px at [dpr] physical px each: the [rect] it fills on the view, the
/// [layout] size it is laid out at, and the [scale] from that to the rect (1: none). A view as wide as tall or wider is
/// the whole of it, unscaled. A taller one gets the view's full width and [letterboxAspect]'s height, centred, its edges
/// on whole physical px so the bars are crisp; laid out at its own size from [letterboxMinWidth] wide, else at that width,
/// scaled down.
({Rect rect, Size layout, double scale}) letterboxFit(Size view, [double dpr = 1]) {
  if (view.height <= view.width) return (rect: Offset.zero & view, layout: view, scale: 1.0);
  final h = math.min(view.height, (view.width * dpr / letterboxAspect).roundToDouble() / dpr);
  final top = ((view.height - h) * dpr / 2).roundToDouble() / dpr;
  final scale = math.min(1.0, view.width / letterboxMinWidth);
  return (rect: Rect.fromLTWH(0, top, view.width, h), layout: Size(view.width / scale, h / scale), scale: scale);
}

/// What a screen keeps at its edges ([insets], the view's logical px: a notch, the system bars) as the game in its
/// letterbox sees them ([letterboxFit]): in its laid-out px, and only where they reach into its rect (a bar covers the
/// rest). Outside a letterbox, [insets] as they are.
EdgeInsets letterboxInsets(Size view, double dpr, EdgeInsets insets) {
  final f = letterboxFit(view, dpr);
  if (f.scale == 1 && f.rect == Offset.zero & view) return insets;
  return EdgeInsets.fromLTRB(insets.left, math.max(0.0, insets.top - f.rect.top), insets.right,
          math.max(0.0, insets.bottom - (view.height - f.rect.bottom))) /
      f.scale;
}

/// The game's [child] (its GameWidget) in its letterbox: laid out at [letterboxFit]'s size and drawn scaled into its
/// rect, the rest of the view [letterboxBar]. The same widgets in every shape of the view (only their sizes change), so
/// the game is never rebuilt when the window turns. Flutter maps every press, drag, hover and wheel through the box's
/// offset and scale; [onExit]: the pointer left the game's box (into a bar, or out of the window).
class Letterbox extends StatelessWidget {
  const Letterbox({super.key, required this.child, this.onExit});

  final Widget child;
  final PointerExitEventListener? onExit;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, box) {
        final f = letterboxFit(box.biggest, MediaQuery.maybeDevicePixelRatioOf(context) ?? 1);
        final boxed = f.rect != Offset.zero & box.biggest;
        return ColoredBox(
          color: letterboxBar,
          child: Stack(textDirection: TextDirection.ltr, children: [ // the app's root: no Directionality over it
            Positioned.fromRect(
              rect: f.rect,
              child: ClipRect(
                clipBehavior: boxed ? Clip.hardEdge : Clip.none,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox.fromSize(size: f.layout, child: MouseRegion(onExit: onExit, child: child)),
                ),
              ),
            ),
          ]),
        );
      });
}
