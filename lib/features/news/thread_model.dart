/// Turns the flat reply list into the rows a thread actually renders.
///
/// Replies arrive as a flat list with a `parentId`, which says nothing about
/// how to *draw* them. Each rendered row needs three things the flat list does
/// not carry, and all three are about connectors:
///
///  * its **depth**, for the indent;
///  * whether it has replies rendered directly beneath it, so a row with no
///    replies does not trail a dangling rail into an unrelated comment;
///  * for every ancestor, whether that ancestor's thread continues past this
///    row, so the rail passing on the left is drawn only where a sibling is
///    still to come.
///
/// Keeping this out of the widget means it can be tested as a pure function —
/// which matters, because connector bugs are invisible to a smoke test.
library;

import '../../data/news.dart';

/// One rendered row of a thread.
class ThreadRow {
  const ThreadRow({
    required this.reply,
    required this.depth,
    required this.ancestorRails,
    required this.hasChildrenBelow,
    required this.isLastChild,
  });

  final NewsReply reply;

  /// 0 for a top-level comment, 1 for a reply to it, and so on.
  final int depth;

  /// For ancestor levels `0 … depth-1`: does that ancestor still have a later
  /// sibling, so its rail passes this row?
  final List<bool> ancestorRails;

  /// Whether replies to *this* row are rendered immediately below it. False
  /// for a childless comment — the case that was drawing a rail to nowhere.
  final bool hasChildrenBelow;

  /// Whether this is the final child of its parent, which is what tells the
  /// parent's rail to stop at this row's elbow.
  final bool isLastChild;
}

/// A node whose replies are collapsed behind a "show more" row.
class ThreadCollapsed {
  const ThreadCollapsed({
    required this.parentId,
    required this.depth,
    required this.hidden,
    required this.ancestorRails,
  });

  final String parentId;
  final int depth;
  final List<NewsReply> hidden;
  final List<bool> ancestorRails;
}

/// The flattened thread: rows in render order, with the collapsed runs that
/// sit between them.
class ThreadLayout {
  const ThreadLayout({required this.rows, required this.collapsed});

  /// Rows in the order they are drawn. A collapsed run's marker is keyed by
  /// the index it follows.
  final List<ThreadRow> rows;

  /// Collapsed runs, keyed by the index of the row they appear after.
  final Map<int, ThreadCollapsed> collapsed;
}

/// Build the render order for [replies].
///
/// [expanded] holds the parent ids whose collapsed runs the user has opened.
/// Children beyond [collapseAfter] are held back so one busy sub-thread cannot
/// bury the rest of the conversation.
ThreadLayout buildThreadLayout(
  List<NewsReply> replies, {
  Set<String> expanded = const {},
  int collapseAfter = 3,
}) {
  final byParent = <String?, List<NewsReply>>{};
  final ids = {for (final r in replies) r.id};

  for (final reply in replies) {
    // An orphan — its parent was deleted, or hidden by a block — is promoted
    // to top level rather than dropped, so nothing silently disappears. So is
    // a reply that claims itself as its own parent: it would otherwise be
    // filed under a node the walk can never reach, and vanish from the thread.
    final parentId = reply.parentId;
    final parent =
        (parentId != null && parentId != reply.id && ids.contains(parentId))
            ? parentId
            : null;
    byParent.putIfAbsent(parent, () => []).add(reply);
  }

  final rows = <ThreadRow>[];
  final collapsed = <int, ThreadCollapsed>{};
  // A cycle among parent ids would otherwise recurse until the stack gives
  // out. Server data should never contain one, but a thread renderer is not
  // the place to find out that it does.
  final walked = <String>{};

  void walk(String? parentId, int depth, List<bool> ancestorRails) {
    if (parentId != null && !walked.add(parentId)) return;
    final children = byParent[parentId] ?? const <NewsReply>[];
    // Only nested runs collapse. Top-level comments are the conversation
    // itself, and hiding them behind a tap would hide the whole feed.
    final shouldCollapse = depth > 0 &&
        parentId != null &&
        children.length > collapseAfter &&
        !expanded.contains(parentId);
    final shown =
        shouldCollapse ? children.take(collapseAfter).toList() : children;

    for (var i = 0; i < shown.length; i++) {
      final child = shown[i];
      final isLast = i == shown.length - 1;
      final grandChildren = byParent[child.id] ?? const <NewsReply>[];

      // A run that ends in a collapsed marker is not really finished, so the
      // parent's rail has to carry on to reach it.
      final moreAfterThis = !isLast || (shouldCollapse && isLast);

      rows.add(ThreadRow(
        reply: child,
        depth: depth,
        ancestorRails: List.unmodifiable(ancestorRails),
        hasChildrenBelow: grandChildren.isNotEmpty,
        isLastChild: !moreAfterThis,
      ));

      walk(child.id, depth + 1, [...ancestorRails, moreAfterThis]);
    }

    if (shouldCollapse) {
      collapsed[rows.length - 1] = ThreadCollapsed(
        parentId: parentId,
        depth: depth,
        hidden: children.skip(shown.length).toList(),
        ancestorRails: List.unmodifiable(ancestorRails),
      );
    }
  }

  walk(null, 0, const []);
  return ThreadLayout(rows: rows, collapsed: collapsed);
}
