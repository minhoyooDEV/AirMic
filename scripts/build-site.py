#!/usr/bin/env python3
"""Build dependency-free, crawlable landing pages from reviewed translations."""
import json
import sys
from html import escape as e
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BASE = 'https://minhoyoodev.github.io/AirMic/'
REPO = 'https://github.com/minhoyooDEV/AirMic'
RELEASE = REPO + '/releases/tag/v0.1.0-beta.1'
CONTENT = json.loads((ROOT / 'site/content.json').read_text())


def write(path, content):
    if '--check' in sys.argv:
        if not path.exists() or path.read_text() != content:
            raise SystemExit(f'Stale site file: {path.relative_to(ROOT)}. Run python3 scripts/build-site.py')
    else:
        path.write_text(content)


def url(lang):
    return BASE + ('' if lang == 'en' else lang + '/')


for lang, c in CONTENT.items():
    target = ROOT / 'docs' / ('' if lang == 'en' else lang)
    target.mkdir(parents=True, exist_ok=True)
    alternates = '\n'.join(f'<link rel="alternate" hreflang="{key}" href="{url(key)}">' for key in CONTENT)
    languages = ' · '.join(f'<a href="{url(key)}" hreflang="{key}" lang="{key}"' + (' aria-current="page"' if key == lang else '') + f'>{value["name"]}</a>' for key, value in CONTENT.items())
    preview_language = lang if lang in ('en', 'ko') else 'en'
    schema = {
        '@context': 'https://schema.org', '@type': 'SoftwareApplication',
        '@id': BASE + '#app', 'name': 'AirMic', 'url': url(lang),
        'description': c['description'], 'applicationCategory': 'UtilitiesApplication',
        'operatingSystem': 'macOS 14 or later', 'softwareVersion': '0.1.0-beta.1',
        'license': REPO + '/blob/main/LICENSE', 'isAccessibleForFree': True,
        'offers': {'@type': 'Offer', 'price': '0', 'priceCurrency': 'USD'},
        'inLanguage': list(CONTENT), 'downloadUrl': RELEASE,
        'sameAs': REPO, 'screenshot': BASE + 'images/airmic-' + preview_language + '-ready.png',
    }
    steps = ''.join(f'<li>{e(step)}</li>' for step in c['steps'])
    facts = ''.join(f'<li>{e(fact)}</li>' for fact in c['facts'])
    faq = ''.join(f'<article><h3>{e(q)}</h3><p>{e(a)}</p></article>' for q, a in c['faq'])
    html = f'''<!doctype html>
<html lang="{lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{e(c['title'])}</title>
<meta name="description" content="{e(c['description'], quote=True)}">
<meta name="robots" content="index, follow, max-image-preview:large">
<link rel="canonical" href="{url(lang)}">
{alternates}
<link rel="alternate" hreflang="x-default" href="{BASE}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="AirMic">
<meta property="og:title" content="{e(c['title'], quote=True)}">
<meta property="og:description" content="{e(c['description'], quote=True)}">
<meta property="og:url" content="{url(lang)}">
<meta name="twitter:card" content="summary">
<meta property="og:image" content="{BASE}images/airmic-{preview_language}-ready.png">
<meta property="og:image:alt" content="{e(c['preview'], quote=True)}">
<link rel="stylesheet" href="{BASE}style.css">
<script type="application/ld+json">{json.dumps(schema, ensure_ascii=False).replace('<', chr(92)+'u003c')}</script>
</head>
<body>
<header><a class="brand" href="{url(lang)}">AirMic<span class="dot" aria-hidden="true"></span></a><nav aria-label="Language">{languages}</nav></header>
<main>
<section class="hero" aria-labelledby="headline"><div class="glass-mark" aria-hidden="true"><svg viewBox="0 0 64 64" fill="none" stroke="currentColor" stroke-width="3.5" stroke-linecap="round"><rect x="24" y="8" width="16" height="30" rx="8"/><path d="M16 29v3a16 16 0 0 0 32 0v-3M32 48v9m-10 0h20"/></svg></div><p class="eyebrow">AirMic · macOS</p><h1 id="headline">{e(c['headline'])}</h1><p class="intro">{e(c['intro'])}</p><div class="actions"><a class="button primary" href="{RELEASE}">{e(c['download'])} <span aria-hidden="true">↗</span></a><a class="button" href="{REPO}">{e(c['source'])}</a></div><p class="notice">{e(c['notice'])}</p></section>
<figure class="preview"><img src="{BASE}images/airmic-{preview_language}-ready.png" width="336" height="390" alt="{e(c['preview'], quote=True)}" loading="lazy"><figcaption>{e(c['preview'])}</figcaption></figure>
<div class="columns"><section class="panel"><h2>{e(c['factsTitle'])}</h2><ul>{facts}</ul></section><section class="panel"><h2>{e(c['install'])}</h2><ol>{steps}</ol><a href="https://support.apple.com/102445">{e(c['apple'])} ↗</a></section></div>
<section class="faq"><h2>{e(c['faqTitle'])}</h2>{faq}</section>
</main>
<footer><p>{e(c['footer'])}</p><a href="{REPO}/blob/main/docs/TROUBLESHOOTING.md">{e(c['help'])}</a> · <a href="{REPO}/blob/main/docs/TESTING.md">{e(c['testing'])}</a> · <a href="{REPO}/issues">Issues</a> · <a href="{BASE}sitemap.xml">Sitemap</a></footer>
</body></html>
'''
    write(target / 'index.html', html)
write(ROOT / 'docs/.nojekyll', '')
items = ''.join('<url><loc>' + url(lang) + '</loc></url>\n' for lang in CONTENT)
write(ROOT / 'docs/sitemap.xml', '<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + items + '</urlset>\n')
print('PASS: localized site matches source' if '--check' in sys.argv else 'Built 5 localized pages and sitemap in docs/')
