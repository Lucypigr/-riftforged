# Platforms

PC: Godot 4.7.2 Compatibility source project, WASD/mouse/keyboard inputs. Desktop binary packaging not performed.
Web: single-thread Godot WASM + PCK, static export; gzip fetched/decompressed before Godot reads bytes. Modern WebGL2 + DecompressionStream browser required. UI source glyph subsetting reduces the font from 11.9 MB to 0.375 MB without removing in-game text. Preserve full downloadable font source and OFL license.
iOS/Android: existing native feature detection, portrait/landscape and independent touch IDs retained. This delivery targets browser play; no IPA/APK, signing or app-store submission performed. Physical-device behavior and safe-area layout remain to be checked.
Save format: no persistent expedition save/load is added in this experiment. Separate user directory prevents future experiment saves from colliding with the original.
