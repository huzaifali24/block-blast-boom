import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../app/store.dart';
import '../app/theme.dart';
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
                Text('Shop', style: t.title(26, weight: FontWeight.w800)),
                CoinPill(coins: app.coins, theme: t),
              ],
            ),
            const SizedBox(height: 24),
            Text('Board themes', style: t.title(16)),
            const SizedBox(height: 10),
            _ThemeGrid(theme: t, app: app),
            const SizedBox(height: 24),
            Text('Block skins', style: t.title(16)),
            const SizedBox(height: 10),
            _SkinGrid(theme: t, app: app),
            const SizedBox(height: 24),
            Text('Coins', style: t.title(16)),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _CoinPackCard(
                    theme: t,
                    label: '500 coins',
                    price: Store.instance.products[Store.coins500Id]
                            ?.price ??
                        '\$1.99',
                    onTap: () => Store.instance.buyCoins(Store.coins500Id),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _CoinPackCard(
                    theme: t,
                    label: '1,500 coins',
                    price: Store.instance.products[Store.coins1500Id]
                            ?.price ??
                        '\$4.99',
                    onTap: () => Store.instance.buyCoins(Store.coins1500Id),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (!app.adsRemoved) ...[
              Text('Support the game', style: t.title(16)),
              const SizedBox(height: 10),
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
                    Text(Store.instance.products[Store.removeAdsId]?.price ??
                        '\$2.99',
                        style: t.title(15, color: t.accent)),
                  ],
                ),
              ),
            ],
            if (Store.instance.message != null) ...[
              const SizedBox(height: 12),
              Text(Store.instance.message!,
                  style: t.body(12, color: t.danger)),
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
      childAspectRatio: 2.1,
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
      childAspectRatio: 2.1,
      children: [
        for (final s in Skins.all)
          _SwatchCard(
            selected: app.skin.id == s.id,
            owned: app.ownsSkin(s),
            price: s.priceCoins,
            label: s.name,
            theme: theme,
            colors: s.colors.take(3).toList(),
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
  });

  final bool selected;
  final bool owned;
  final int price;
  final String label;
  final AppTheme theme;
  final List<Color> colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      theme: theme,
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Row(
            children: [
              for (final c in colors)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 3),
                  decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: theme.body(13, weight: FontWeight.w700, color: theme.text),
                overflow: TextOverflow.ellipsis),
          ),
          if (selected)
            Icon(Icons.check_circle_rounded, color: theme.accent, size: 18)
          else if (!owned)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.monetization_on, color: theme.gold, size: 14),
                const SizedBox(width: 2),
                Text('$price',
                    style: TextStyle(color: theme.gold, fontSize: 12)),
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
          Icon(Icons.monetization_on, color: theme.gold, size: 28),
          const SizedBox(height: 8),
          Text(label, style: theme.title(14)),
          const SizedBox(height: 4),
          Text(price, style: theme.body(12)),
        ],
      ),
    );
  }
}
