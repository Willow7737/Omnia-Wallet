import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/errors.dart';
import '../../core/haptics.dart';
import '../../core/theme.dart';
import '../../core/ui/press.dart';
import '../../core/ui/sheet.dart';
import '../../data/link_preview.dart';

final linkPreviewServiceProvider =
    Provider<LinkPreviewService>((ref) => LinkPreviewService());

/// Metadata for one link. Family-keyed on the URL so two posts sharing a link
/// resolve it once, and the service's own cache makes a repeat free.
final linkPreviewProvider =
    FutureProvider.family<LinkPreview?, String>((ref, url) async {
  return ref.watch(linkPreviewServiceProvider).fetch(url);
});

/// The preview card under a post that contains a link.
///
/// Nothing is shown until the metadata arrives and turns out to be worth
/// showing: no skeleton, no empty frame. A card that pops into existence a
/// second later is a smaller disruption than a placeholder that reserves
/// space for something that may never come — most links in a wallet's news
/// feed resolve, but the ones that do not would otherwise leave a hole.
class LinkPreviewCard extends ConsumerWidget {
  const LinkPreviewCard({super.key, required this.url});

  final String url;

  Future<void> _open(BuildContext context) async {
    Haptics.selection();
    try {
      final uri = Uri.parse(url);
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        showOmniaToast(context,
            message: 'Could not open the link', error: true);
      }
    } catch (e) {
      if (context.mounted) {
        showOmniaToast(context, message: friendlyError(e).message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = context.omnia;
    final preview = ref.watch(linkPreviewProvider(url)).valueOrNull;
    if (preview == null || !preview.isUseful) return const SizedBox.shrink();

    return Pressable(
      onTap: () => _open(context),
      feel: PressFeel.subtle,
      semanticLabel: 'Open ${preview.title} on ${preview.host}',
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: Radii.rMd,
          border: Border.all(color: o.borderLow),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (preview.imageUrl case final image?)
              Image.network(
                image,
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                // No progress spinner: the card only exists once the metadata
                // resolved, and a second loading state inside it reads as the
                // card being broken.
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : Container(height: 160, color: o.bg50),
                // A dead image must collapse the slot rather than leave a grey
                // brick where a picture was promised.
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(Space.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Iconsax.link_copy, size: 12, color: o.textLow),
                      const SizedBox(width: Space.xs),
                      Expanded(
                        child: Text(
                          // The host, not the full URL. It is the part that
                          // says who is really being visited, and the part a
                          // page's own title cannot fake.
                          preview.siteName ?? preview.host,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: FontSizes.xs,
                            color: o.textLow,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xs),
                  Text(
                    preview.title!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: FontSizes.sm,
                      fontWeight: Weights.semiBold,
                      height: LineHeights.snug,
                      color: o.text,
                    ),
                  ),
                  if (preview.description case final description?
                      when description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: FontSizes.xs,
                        height: LineHeights.snug,
                        color: o.textMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
