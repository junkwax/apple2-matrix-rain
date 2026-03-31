# Apple ][ Matrix Rain Screensaver

A faithful recreation of the iconic Matrix "digital rain" effect, running natively on Apple II hardware in 6502 assembly. Renders in real-time on the Hi-Res Graphics page using custom Katakana-inspired glyphs, sine-wave column offsets, and a shadow-buffered dirty-rect engine for smooth animation.

```
    ╔══════════════════════════════════════╗
    ║  ░▒█   ░   █▒░   ▒   ░▒█   ░   █▒  ║
    ║  ░ ▒   █   ░▒█   ░   ▒ █   ░   ▒█  ║
    ║    ░   ▒   ░ █   ▒   ░ ▒       ░█  ║
    ║        ░     ▒   ░     ░        ▒   ║
    ║              ░                  ░   ║
    ║ --- MATRIX SETTINGS ------------- ║
    ║  SPEED:3/5  DIM:$55  SHIMMER:$07  ║
    ║  +/- Speed  D Dim  B Shimmer  R.. ║
    ║  ESC Close            Q Quit      ║
    ╚══════════════════════════════════════╝
```

## Features

- **Pure 6502 assembly** — no ProDOS or DOS dependency, runs on bare metal
- **Hi-Res Graphics (HGR) rendering** — 280×192 monochrome, full-screen
- **Custom glyph set** — 16 Katakana-inspired 7×8 pixel characters
- **Organic rain motion** — sine-wave phase offsets per column for natural-looking cascades
- **4-level brightness pipeline** — head (solid white) → body (shimmer) → dim (bit-masked) → erase
- **Body glyph shimmer** — body cells slowly cycle glyphs for a subtle living-trail effect
- **Shadow buffer optimization** — only redraws cells whose brightness changed since last frame
- **LFSR-seeded column density** — 16-bit Galois LFSR generates a unique rain pattern every launch
- **Interactive settings menu** — press ESC to open a mixed-mode overlay; adjust speed, dim pattern, shimmer rate, and re-randomize rain while it keeps falling
- **Runtime-adjustable everything** — speed, dim mask, body shimmer, and rain density all changeable without rebuilding
- **RTS-trick dispatch** — fully relocatable draw dispatch
- **Clean exit** — Q key restores text mode and returns to the Apple II monitor

## Requirements

- **Hardware:** Apple II, II+, IIe, or IIgs (48K+ RAM)
- **Assembler:** [ca65](https://cc65.github.io/doc/ca65.html) (part of the cc65 suite)
- **Linker:** [ld65](https://cc65.github.io/doc/ld65.html) (part of the cc65 suite)
- **Emulator (optional):** [AppleWin](https://github.com/AppleWin/AppleWin), [MicroM8](https://paleotronic.com/software/microm8/), or [Virtual II](https://virtualii.com/)

## Building

```bash
# Assemble
ca65 matrix_screensaver.s -o matrix.o

# Link (using the included config)
ld65 -C matrix.cfg matrix.o -o MATRIX.BIN
```

This produces `MATRIX.BIN`, a raw binary loadable at `$0800`.

## Running

### On an emulator

Load `MATRIX.BIN` at address `$0800` and execute:

```
BLOAD MATRIX.BIN,A$0800
CALL 2048
```

Or from the monitor:

```
*0800.XXXXR
```

### On real hardware

Transfer `MATRIX.BIN` to a ProDOS or DOS 3.3 disk image using [ADTPro](https://adtpro.com/), [CiderPress](https://a2ciderpress.com/), or similar tool. Then `BLOAD` and `CALL 2048` from BASIC.

## Controls

**Always active:**

| Key | Action |
|-----|--------|
| `ESC` | Toggle settings menu |
| `Q` | Quit — exit to Apple II monitor |
| `+` / `=` | Increase rain speed |
| `-` | Decrease rain speed |

**Settings menu only** (press `ESC` to open):

| Key | Action |
|-----|--------|
| `D` | Cycle dim pattern (`$55` → `$AA` → `$33` → `$11`) |
| `B` | Cycle body shimmer rate (`$00` → `$07` → `$03` → `$0F`) |
| `R` | Re-randomize rain pattern (uses current frame as LFSR seed) |
| `ESC` | Close menu and return to full-screen rain |

When the menu is open, rain continues falling on the top 20 rows while a 4-line settings panel displays at the bottom using Apple II mixed mode. Current values are shown as live hex readouts. Key labels appear in inverse video.

## Configuration

Default values are set as constants at the top of `matrix_screensaver.s`. All are adjustable at runtime through the settings menu:

| Constant | Default | Description |
|----------|---------|-------------|
| `INIT_SPEED` | `3` | Starting rain speed (1–5) |
| `INIT_DIM` | `0` | Starting dim mask index (0=`$55`, 1=`$AA`, 2=`$33`, 3=`$11`) |
| `INIT_BODY` | `1` | Starting shimmer rate index (0=every frame, 1=every 8, 2=every 4, 3=every 16) |
| `LFSR_SEED_LO/HI` | `$B4/$37` | LFSR seed — change for a different startup rain pattern |

### Column Density

The `TAIL_LEN_TBL` is seeded at startup by a 16-bit Galois LFSR, so every launch produces a unique rain pattern. Press `R` in the settings menu to re-randomize at any time. Values below 100 become blank columns (~40% density). To get a fixed pattern instead, remove the `SEED_TAILS` call from `INIT_ALL` — the hardcoded fallback table will be used.

## How It Works

### Rendering Pipeline

Each frame walks a 40×N grid (N=24 full-screen, or 20 when the menu is open). For every cell:

1. **Phase calculation** — A sine-wave lookup offsets each column's rain position, creating the organic "falling at different speeds" effect
2. **Brightness classification** — The distance from the wave head determines one of four states: head (3), body (2), dim (1), or empty (0)
3. **Glyph animation** — Head cells cycle glyphs every frame; body cells shimmer on a configurable slow cycle; dim/erased cells stay static
4. **Shadow buffer check** — If the brightness hasn't changed since last frame, skip the draw entirely
5. **Dispatch** — RTS-trick jump to the appropriate draw routine (fully relocatable)

### Settings Menu Architecture

The settings menu uses Apple II mixed mode (`$C053`), which composites HGR on the top 160 scanlines and text page 1 on the bottom 32 scanlines (text lines 21–24). When the menu opens, `GRID_ROWS` drops from 24 to 20 so the rain loop doesn't overwrite the text area. When it closes, `GRID_ROWS` returns to 24 and `INVALIDATE_BOTTOM` forces the bottom rows to redraw. Runtime parameters like `DIM_MASK` are stored in zero page for fast access in the hot loop; the body shimmer mask uses a single self-modified operand byte.

### Memory Map

| Address | Usage |
|---------|-------|
| `$00–$1E` | Zero page working registers, LFSR state, menu state |
| `$0400–$07FF` | Text page 1 (used for settings menu in mixed mode) |
| `$0800+` | Program code and data |
| `$2000–$3FFF` | HGR Page 1 (video output) |
| `$6000–$63FF` | Shadow brightness buffer (40×24 bytes) |

### Draw Routines

| Routine | Effect |
|---------|--------|
| `DRAW_HEAD` | Solid white block (`$7F` across all 8 scanlines) |
| `DRAW_MED` | Full glyph render from `FONT_DATA` |
| `DRAW_DIM` | Glyph ANDed with runtime `DIM_MASK_ZP` for a faded look |
| `DRAW_ERASE` | Zeros out all 8 scanlines |

## Project Structure

```
├── README.md
├── LICENSE
├── matrix_screensaver.s    # Complete source (single-file, self-contained)
├── matrix.cfg              # ld65 linker config (raw binary at $0800)
└── .gitignore
```

## License

MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

Inspired by the digital rain effect from *The Matrix* (1999). Built for the love of 6502 assembly and the Apple II.