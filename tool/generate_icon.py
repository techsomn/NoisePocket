"""Original launcher icon for Noise Pocket, drawn in Pillow."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[1]
size = 1024
im = Image.new('RGB', (size, size), '#111417')
d = ImageDraw.Draw(im)
d.rounded_rectangle((65,65,959,959), radius=226, fill='#1D2523', outline='#BBF553', width=28)
d.rounded_rectangle((205,205,819,819), radius=165, fill='#BBF553')
# Two small outer signal waves and a compact central waveform.
d.line([(287,513),(365,513),(405,382),(466,650),(521,428),(555,513),(738,513)], fill='#15201A', width=48, joint='curve')
d.ellipse((671,447,804,580), fill='#17221A')
d.ellipse((707,483,768,544), fill='#BBF553')
icon = root / 'assets' / 'launcher_icon.png'
im.save(icon)
for folder, px in [('mipmap-mdpi',48),('mipmap-hdpi',72),('mipmap-xhdpi',96),('mipmap-xxhdpi',144),('mipmap-xxxhdpi',192)]:
    target = root / 'android' / 'app' / 'src' / 'main' / 'res' / folder
    target.mkdir(parents=True, exist_ok=True)
    im.resize((px,px), Image.Resampling.LANCZOS).save(target/'ic_launcher.png')
print(icon)
