"""Subset only generated build font; retains every source UI glyph plus ASCII."""
from pathlib import Path
from fontTools import subset
p=Path(__file__).resolve().parents[1]
text=''.join(f.read_text() for f in (p/'scripts').glob('*.gd'))+''.join(chr(i) for i in range(32,127))
font=p/'fonts/NotoSansTC-Riftforged.ttf'
options=subset.Options();options.layout_features=['*'];options.notdef_glyph=True;options.recommended_glyphs=True
f=subset.load_font(str(font),options);s=subset.Subsetter(options=options);s.populate(text=text);s.subset(f);subset.save_font(f,str(font),options)
print('UI font bytes',font.stat().st_size)
