"""Generate ARC climbing-wall pixel assets; Pillow, 256x144 at 5x nearest."""
from pathlib import Path
from PIL import Image, ImageDraw
OUT = Path(__file__).resolve().parents[2] / "assets/art/microgames/rock_climbing"
OUT.mkdir(parents=True, exist_ok=True)
im=Image.new("RGB", (256,144), "#25394b"); d=ImageDraw.Draw(im)
d.rectangle((14,17,242,130), fill="#a38e75")
for x in range(14,242,38):
 d.line((x,17,x+20,130),fill="#736656",width=1)
for y in (40,75,110): d.line((14,y,242,y),fill="#736656")
for x in range(25,240,28):
 for y in range(30,125,23):
  d.ellipse((x,y,x+3,y+2),fill="#6d786c")
d.rectangle((0,131,255,143),fill="#243f65")
for x in range(0,256,32): d.rectangle((x,133,x+29,141),fill="#385985")
d.rectangle((88,3,168,14),fill="#173253"); d.text((94,3),"UC DAVIS ARC",fill="#ffcf4b")
im.save(OUT/'wall.png')
im=Image.new('RGBA',(12,22)); d=ImageDraw.Draw(im)
d.rectangle((3,5,8,13),fill='#d9ac32');d.rectangle((4,2,7,5),fill='#edbb8d')
d.line((3,7,1,0),fill='#edbb8d',width=2);d.line((8,7,10,0),fill='#edbb8d',width=2)
d.line((4,14,2,20),fill='#173253',width=3);d.line((7,14,10,20),fill='#173253',width=3)
d.rectangle((3,12,8,14),fill='#e56a48');im.save(OUT/'climber.png')
im=Image.new('RGBA',(12,12));d=ImageDraw.Draw(im);d.polygon([(1,7),(3,2),(9,1),(11,6),(8,10),(2,10)],fill='white');d.line((3,8,8,8),fill='#8e9b9e',width=2);im.save(OUT/'hold.png')
