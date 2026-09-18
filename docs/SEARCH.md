# Search discovery maintenance

The public site is https://minhoyoodev.github.io/AirMic/ . GitHub Pages serves `main:/docs` without Jekyll. English lives at the root; Korean, Simplified Chinese, Japanese, and Spanish have stable language paths. There are no client-side redirects, scripts required to read content, third-party fonts, or analytics.

## Updating the site

1. Edit reviewed translations in `site/content.json`. Keep feature claims consistent with the released binary and `docs/TESTING.md`; distinguish the original prototype from the current Swift beta.
2. For releases, update the release URL/version in `scripts/build-site.py` and beta notices in all translations. Keep the download link pointing to release notes so users see signing and compatibility information before installation.
3. Run `python3 scripts/build-site.py`, then `python3 scripts/build-site.py --check`. The existing CI runs the freshness check. Commit source and generated HTML together. Python 3 standard library only.
4. Verify the five pages, mobile layout, language links, stylesheet, sitemap, and download target after deployment. Titles/descriptions must stay specific and natural, and structured application facts must match visible content. Do not invent reviews, ratings, hardware results, or contributor activity.

## Crawling and indexing

Each page has a self-referencing canonical URL, reciprocal `hreflang` links including `x-default`, visible text, semantic headings, and SoftwareApplication JSON-LD. The sitemap is https://minhoyoodev.github.io/AirMic/sitemap.xml . Structured data does not guarantee rich results.

`robots.txt` only applies at the **host root**: https://minhoyoodev.github.io/robots.txt . A file at `/AirMic/robots.txt` would not control crawlers. The host root returned 404 during setup, so no robots exclusion was found. Do not change a shared host’s crawler policy without reviewing other projects. On a future custom domain, check both Googlebot and OAI-SearchBot access at the new host root and update canonical URLs, language links, and the sitemap together. Search crawling and model-training controls are separate choices.

Once an owner has verified this URL-prefix property in Google Search Console and Bing Webmaster Tools, submit the sitemap and inspect the canonical landing pages. Verification requires the owner’s account; creating the site does not perform verification or guarantee indexing. Track indexing, real query impressions/clicks, and any AI search referrals before expanding content. Do not add visitor tracking without an explicit privacy decision.

There is no special AI ranking file or guaranteed placement. Clear first-party answers, working links, accessible HTML, honest compatibility evidence, and up-to-date release information are the foundation. `llms.txt` is not required by the cited Google guidance and is not a claimed ranking factor here.

References:
- [Google: AI features and your website](https://developers.google.com/search/docs/appearance/ai-features)
- [OpenAI: Publishers and Developers FAQ](https://help.openai.com/en/articles/12627856)

## README screenshots

`Tests/Screenshots.swift` renders production SwiftUI views with fixture states into PNG files without microphone I/O or screen capture. These are UI previews, not hardware evidence. After `bash scripts/check-localizations.sh`, regenerate English and Korean images with:

```sh
for language in en ko; do
  build/LocalizationChecks.app/Contents/MacOS/AirMic \
    -AppleLanguages "($language)" -ExpectedLanguage "$language" \
    -SourceDirectory "$PWD/Source" -ScreenshotDirectory "$PWD/docs/images"
done
```

Inspect both states visually before committing. Keep README alt text and the fixture-state caption. `docs/images/banner.svg` is original vector artwork, not an app screenshot.
