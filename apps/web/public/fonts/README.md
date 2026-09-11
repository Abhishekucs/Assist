# Hugeicons Free icon font

`hugeicons-refresh.woff2` is a one-glyph subset of the official Hugeicons Free
Stroke Rounded font. It renders the Fun mode Restart control using `hgi-refresh`
(U+F244E). The glyph's coordinates and metrics are preserved. The font is served
locally and is only requested when the icon is rendered.

- Documentation: https://hugeicons.com/docs/icons-for-web/quick-start
- Official CSS and glyph mapping: https://use.hugeicons.com/font/icons.css
- Source font: https://use.hugeicons.com/font/hgi-stroke-rounded.woff2?t=1788885671703
- Downloaded: September 11, 2026
- Source SHA-256: `6d4b0f95dc957971114ae325e3696e58d86ac693d7a1e30a02179576d8a8c76d`
- Subset SHA-256: `511133a29c61f3a1dfa73d4b60b68d5e233b3568701d9dc8fcdbb832a03fd625`
- License: MIT; see `HUGEICONS-LICENSE.md`, copied from
  https://github.com/hugeicons/hugeicons/blob/main/LICENSE.md

The subset was produced with FontTools 4.60.2 and WOFF2 compression. To regenerate
it from the source font (after verifying its hash):

```sh
python -m fontTools.subset hgi-stroke-rounded.woff2 \
  --unicodes=U+F244E --flavor=woff2 \
  --name-IDs='*' --name-languages='*' --name-legacy \
  --output-file=hugeicons-refresh.woff2
```

FontTools is only needed when updating this asset, not to build or run the site.
