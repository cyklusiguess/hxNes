<p align="center">
  <img width="128" height="128" alt="flxhaxe logo" src="https://github.com/user-attachments/assets/2fdd19e8-2354-4db2-9c0a-2a90ead3e371" />
</p>

# hxNes
an NES emulator written in haxe, handled with haxeflixel, which is based on smolnes (https://github.com/binji/smolnes), but with extra features

## features
 
- 6502 CPU with cycle counting, page-cross and branch penalties and NMI/IRQ/BRK handling
- PPU stepped dot by dot. background shift registers, fine scrolling, 8x8 and 8x16 sprites, flipping priority and sprite-0 hit
- APU with two pulse channels (sweep and envelope), triangle, noise and DMC mixed with the standard non-linear NES formula
- mappers, NROM (0), MMC1 (1), UxROM (2), CNROM (3), MMC3 (4) and AxROM (7)
- two audio modes: "authentic" and "perfect sound chip"
- a built-in debugger (press F3)

# how do i build this?
install haxe, then run
```
haxelib install flixel
```
after that, run
```
lime test cpp
```
# important:
cpp is recommended because in other targets it's buggy or very slow. cpp works best.

# controls:
the same as in smolnes, they're documented in the code

# license:
- MIT
# credits:
- loltisticz: created the logo
