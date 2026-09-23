# Keytest icon

Created with the built-in imagegen tool. `keytest.png` is the original transparent
artwork; `keytest.ico` contains uncompressed 32-bit DIB frames at 16, 24, 32 and
48 pixels, with alpha and explicit AND masks for Windows XP. Normal builds use
the checked-in ICO and do not require an image-generation tool or Pillow.

Regenerate the ICO from the PNG using Python with Pillow installed:

```sh
python3 apps/keytest/scripts/export_icon.py
```

Generation prompt:

> Use case: logo-brand. Create a cute application icon for a small Windows XP
> keyboard testing app named Keytest. A single chunky rounded blue keyboard
> keycap, slightly viewed from above, with a large crisp white capital K on the
> top face and a tiny friendly smiling face on its front lip. Cheerful, polished
> Windows XP era desktop icon illustration, clean bold silhouette, gentle cyan
> highlight, subtle dimensional shading. One simple keycap only, centered with
> generous transparent padding, readable when reduced to 16, 32 and 48 pixels.
> Square canvas. Truly transparent background, no surrounding tile, no background
> scene, no extra text, no watermark. Save a PNG with alpha suitable for conversion
> into a Windows ICO.
