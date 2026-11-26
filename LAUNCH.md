# Block Boom launch checklist

Everything below happens in your Google accounts; the code side is ready.
Work top to bottom. Items marked **→ send** are IDs to put in the secrets
files (or send to whoever builds the release).

| Thing | Value |
|---|---|
| Package name | `com.kodexsolutions.blockboom` |
| Privacy policy URL | https://huzaifali24.github.io/block-blast-boom/block-boom/ |
| Support email | info@kodexsolution.com |
| Upload key SHA-1 | `95:85:CB:8D:67:5B:25:C7:5A:67:4D:D4:A3:A3:10:00:41:85:6B:A1` |
| Upload key SHA-256 | `C8:C9:90:C6:4E:DD:88:53:03:AE:4C:37:1F:06:11:C2:60:A3:FD:82:3C:7C:BD:C8:8B:9A:F7:02:2F:61:19:AC` |
| Version | 1.0.0 (build 1) |
| Store art and text | `store/listing/en/` and `store/listing/ur/` |

## 0. Back up the upload key (do this first)

Copy `android/upload-keystore.jks` and `android/key.properties` to a safe
place (password manager or private cloud drive). They are not in git. If you
lose them, Play App Signing lets you request a new upload key, but it takes
days.

## 1. Create the app in Play Console

1. Play Console → **Create app**: name *Block Boom*, default language
   *English (United States)*, **Game**, **Free**. Accept the declarations.
2. **Store settings** → category *Puzzle*, contact email
   info@kodexsolution.com.
3. **Main store listing**: paste the text from `store/listing/en/listing.md`;
   upload `store/icon_512.png`, `store/listing/en/feature_graphic.png` and
   `screenshot_1.png` … `screenshot_7.png`.
4. **Add translation → Urdu (ur)**: text from `store/listing/ur/listing.md`
   and the art in `store/listing/ur/`.

## 2. App content (Policy → App content)

- **Privacy policy**: the URL above.
- **Ads**: *Yes, my app contains ads*.
- **App access**: all functionality is available without special access.
- **Content rating**: questionnaire → category *Game*; answer **No** to
  violence, sexuality, language, controlled substances, gambling (the Lucky
  Spin uses only free in-game rewards, no real money, so it is *not*
  gambling), user interaction/chat, sharing location. Expect *Everyone / 3+*.
- **Target audience**: 13+ (choosing under-13 groups triggers the Families
  policy, which needs extra ad settings).
- **Data safety** (matches the privacy policy):
  - Data collected: **Yes**. Data shared: **Yes** (with Google for ads).
  - *Device or other IDs* (advertising ID): collected and shared, for
    *Advertising or marketing* and *Analytics*, not optional (but the user
    can reset it).
  - *App activity → App interactions* (ad interactions): collected and
    shared, for advertising.
  - *App info and performance → Diagnostics*: collected by AdMob.
  - *Location → Approximate location* (from IP, by AdMob): collected and
    shared, for advertising.
  - *App activity → Other user-generated content / In-game progress*: only
    when signed in to Play Games (cloud save), stored in the user's Google
    account, optional.
  - Data is **encrypted in transit**. Users can **request deletion** (by
    email; Play Games data from their Google account).
  - Purchase history is handled by Google Play (declare *Purchase history*
    if Play Console asks).
- **Government apps / financial features / health**: not applicable.

## 3. AdMob → send IDs

1. AdMob → **Apps → Add app** → Android, *not yet listed* (link it to the
   store listing after launch) → name *Block Boom*.
2. Create two ad units: **Rewarded** ("Block Boom rewarded") and
   **Interstitial** ("Block Boom between games").
3. **→ send**: the *App ID* (`ca-app-pub-…~…`) and both *ad unit IDs*
   (`ca-app-pub-…/…`).
4. AdMob → **Privacy & messaging**: create a **GDPR** message and a
   **US states** message for this app (the app already shows Google's
   consent form and has *Profile → Privacy preferences*).
5. Add an `app-ads.txt` to your website (Kodex site) with the line AdMob
   gives you, and put your website in the Play store listing.

## 4. Play Games Services → send IDs

1. Play Console → your app → **Play Games Services → Setup and management →
   Configuration** → *Create new Play Games Services project*.
2. **Credentials → Add credential → Android**: package
   `com.kodexsolutions.blockboom`, SHA-1 **of the Play App Signing key**
   (Play Console → *Test and release → App integrity* shows it after your
   first upload) and also one for the **upload key SHA-1** above (for
   testing builds you sideload).
3. Turn on **Saved Games** (cloud save).
4. **Leaderboards** (all *Higher is better*, numeric):
   *Classic best score*, *Daily challenge score*, *Adventure stars*.
   **→ send** their IDs.
5. **Achievements**: create the 24 from `lib/app/achievements.dart` (title
   + description; points are up to you, e.g. 10–100). **→ send** each ID
   next to its code name (`first_clear`, `combo_3`, …).
6. **→ send** the Play Games *project ID* (a number, shown on the
   Configuration page).
7. Add your Google account (and testers) under **Testers**, then
   **Publish** the Play Games configuration.

## 5. In-app products

Play Console → **Monetize → Products → In-app products** (needs a payments
profile; products can only be created after an AAB with billing is
uploaded, so do this after step 7):

| Product ID | Type | Suggested price |
|---|---|---|
| `remove_ads` | One-time (non-consumable) | US$2.99 |
| `coins_500` | Consumable | US$1.99 |
| `coins_1500` | Consumable | US$4.99 |

Activate all three.

## 6. Fill the secrets and build

`android/secrets.properties`:

```properties
admobAppId=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY
playGamesProjectId=123456789012
```

`secrets.json` (copy of `secrets.example.json` with values filled in):
`ADMOB_REWARDED`, `ADMOB_INTERSTITIAL`, `PGS_LB_CLASSIC`, `PGS_LB_DAILY`,
`PGS_LB_STARS`, and each `PGS_ACH_*`.

```sh
flutter build appbundle --release --dart-define-from-file=secrets.json
```

The build refuses to produce the upload bundle if any of these are missing
or still Google's test IDs. Output:
`build/app/outputs/bundle/release/app-release.aab`.

## 7. Testing track (required for new personal accounts)

Google requires new **personal** developer accounts to run a **closed test
with at least 12 testers for 14 continuous days** before production access
(organisation accounts skip this).

1. **Test and release → Testing → Closed testing** → create a track, upload
   the AAB, add testers (a Google Group or email list), publish.
2. Share the opt-in link; testers install from Play and keep it installed
   for 14 days.
3. Meanwhile: create the in-app products (step 5), link AdMob to the Play
   listing, and check that sign-in, leaderboards, cloud save, purchases
   (use *license testers* for free test purchases) and real ads all work.
4. After 14 days: **Apply for production**, then roll out.

## 8. After launch

- Link the AdMob app to the Play listing.
- Watch **Android vitals** (crashes/ANRs) and reviews the first week.
- Bump `version:` in `pubspec.yaml` (e.g. `1.0.1+2`) for every update.
