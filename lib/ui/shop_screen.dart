import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/store.dart';
import '../app/theme.dart';
import '../game/board_painter.dart';
import '../game/skins.dart';
import 'widgets.dart';

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppState.instance;
    final t = app.theme;

    return ListenableBuilder(
      listenable: Listenable.merge([app, Store.instance]),
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const ScreenTitle('Shop'),
                CoinPill(coins: app.coins, theme: t),
              ],
            ),
            const SizedBox(height: 24),
            SectionLabel('Board themes', theme: t),
            _ThemeGrid(theme: t, app: app),
            const SizedBox(height: 24),
            SectionLabel('Block skins', theme: t),
            _SkinGrid(theme: t, app: app),
            const SizedBox(height: 24),
            SectionLabel('Coins', theme: t),
            Row(
              children: [
                Expanded(
                  child: _CoinPackCard(
                    theme: t,
                    label: '500 coins',
                    price: Store.instance.products[Store.coins500Id]?.price ??
                        '\$1.99',
                    onTap: () => Store.instance.buyCoins(Store.coins500Id),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CoinPackCard(
                    theme: t,
                    label: '1,500 coins',
                    price: Store.instance.products[Store.coins1500Id]?.price ??
                        '\$4.99',
                    onTap: () => Store.instance.buyCoins(Store.coins1500Id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!app.adsRemoved) ...[
              SectionLabel('Support the game', theme: t),
              SectionCard(
                theme: t,
                onTap: Store.instance.busy
                    ? null
                    : () => Store.instance.buyRemoveAds(),
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, color: t.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Remove ads', style: t.title(15)),
                          Text('One-time purchase, forever.',
                              style: t.body(12)),
                        ],
                      ),
                    ),
                    Text(
                        Store.instance.products[Store.removeAdsId]?.price ??
                            '\$2.99',
                        style: t.title(15, color: t.accent)),
                  ],
                ),
              ),
            ],
            if (Store.instance.message != null) ...[
              const SizedBox(height: 12),
              Text(Store.instance.message!, style: t.body(12, color: t.danger)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeGrid extends StatelessWidget {
  const _ThemeGrid({required this.theme, required this.app});
  final AppTheme theme;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      padding: EdgeInsets.zero,
      children: [
        for (final t in AppTheme.all)
          _SwatchCard(
            selected: app.theme.name == t.name,
            owned: app.ownsTheme(t),
            price: t.price,
            label: t.name,
            theme: theme,
            colors: [t.backgroundTop, t.background, t.boardCell],
            onTap: () => app.buyOrSelectTheme(t),
          ),
      ],
    );
  }
}

class _SkinGrid extends StatelessWidget {
  const _SkinGrid({required this.theme, required this.app});
  final AppTheme theme;
  final AppState app;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      padding: EdgeInsets.zero,
      children: [
        for (final s in Skins.all)
          _SwatchCard(
            selected: app.skin.id == s.id,
            owned: app.ownsSkin(s),
            price: s.priceCoins,
            label: s.name,
            theme: theme,
            colors: s.colors.take(3).toList(),
            blockStyle: s.style,
            onTap: () => app.buyOrSelectSkin(s),
          ),
      ],
    );
  }
}

class _SwatchCard extends StatelessWidget {
  const _SwatchCard({
    required this.selected,
    required this.owned,
    required this.price,
    required this.label,
    required this.theme,
    required this.colors,
    required this.onTap,
    this.blockStyle,
  });

  final bool selected;
  final bool owned;
  final int price;
  final String label;
  final AppTheme theme;
  final List<Color> colors;
  final VoidCallback onTap;

  /// Skins preview real blocks in their material; themes show swatches.
  final BlockStyle? blockStyle;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      theme: theme,
      onTap: onTap,
      glow: selected ? const Color(0xFFFFC93C) : null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (blockStyle != null)
                CustomPaint(
                  size: const Size(84, 28),
                  painter: _BlocksPreview(colors, blockStyle!),
                )
              else
                for (final c in colors)
                  Container(
                    width: 24,
                    height: 24,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color.lerp(c, Colors.white, .4)!, c],
                      ),
                      border: Border.all(
                          color: Color.lerp(c, Colors.black, .35)!, width: 1.4),
                    ),
                  ),
              const Spacer(),
              if (selected)
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF3FD16B), size: 24),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label,
                      style: theme.body(16,
                          weight: FontWeight.w800, color: theme.text)),
                ),
              ),
              if (selected)
                Text('IN USE',
                    style: theme.body(11,
                        weight: FontWeight.w800,
                        color: const Color(0xFF3FD16B)))
              else if (owned)
                Text('OWNED', style: theme.body(11, weight: FontWeight.w800))
              else
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CoinIcon(size: 18),
                    const SizedBox(width: 4),
                    Text('$price',
                        style: TextStyle(
                            fontFamily: kFont,
                            color: theme.gold,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoinPackCard extends StatelessWidget {
  const _CoinPackCard({
    required this.theme,
    required this.label,
    required this.price,
    required this.onTap,
  });

  final AppTheme theme;
  final String label;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      theme: theme,
      onTap: onTap,
      child: Column(
        children: [
          const CoinIcon(size: 34),
          const SizedBox(height: 8),
          Text(label, style: theme.title(14)),
          const SizedBox(height: 4),
          Text(price, style: theme.body(12)),
        ],
      ),
    );
  }
}

class _BlocksPreview extends CustomPainter {
  _BlocksPreview(this.colors, this.style);
  final List<Color> colors;
  final BlockStyle style;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.height;
    for (var i = 0; i < colors.length; i++) {
      BlockArt.block(canvas, Rect.fromLTWH(i * cell, 0, cell, cell), colors[i],
          as: style);
    }
  }

  @override
  bool shouldRepaint(covariant _BlocksPreview old) =>
      old.style != style || old.colors != colors;
}
