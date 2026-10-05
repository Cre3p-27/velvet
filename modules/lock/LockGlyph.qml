//  VELVET  ·  modules/lock/LockGlyph.qml
//  The lock's shape alphabet — the material-style glyphs: circle, arrow,
//  pill, burst, diamond, clam, pentagon, rect. One family, every size:
//  the 18px password dots, the editor's preview chips and the giant
//  background shape behind the lock are the same shapes, and because they
//  are canvas paths, a change of `kind` morphs cleanly from one form into
//  the next.
//
//  Colour comes in through `col`, so the same file doubles as the
//  wallpaper's mask (white) and as ink (palette colours).
MorphGlyph {}
