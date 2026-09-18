# 2026.09-V5Styles

Three new tuning styles for BO7 V5, a new self gun level, and a change to how
your own footsteps and gunfire are handled on every style.

- **Classic, Classic+ and Open** are new. What they share is much slower
  leveller timing, and that is the biggest single change in how V5 feels: the
  processing stops drawing attention to itself and sits far closer to the old
  Loudness Equalization character, while keeping V5's footstep detail and
  gunfire control.
  - **Classic** is the calmest, and the least audible processing in the family.
    If V5 has ever felt like it was working on the sound, try this first.
  - **Classic+** is Classic with more footstep lift: distant steps come through
    louder, and close ones are no longer held back. File names spell it
    `ClassicPlus`.
  - **Open** is the least filtered, built on Balanced's more forward voicing
    rather than Competitive's, so mid-level sound comes up harder and less
    bright content is held back.
- **Ultra Low** is a new self gun level on every style (`UltraLoGun`). It sits
  below Low and pushes your own gunfire to the engine's limit. The room
  reflection after a shot is not ducked at this tier, so the ring-out can end
  up the loudest part of your own fire. If that bothers you, Low is unchanged.
- **Your own footsteps** are held down harder and for longer on every style and
  every level: the dip now covers the whole footfall, around two thirds of a
  second, and goes deeper. **Your own gunfire** comes back up more gradually to
  match on every level except Stock.
- **Capped, Immersive and Balanced are deprecated.** Nothing is removed: their
  files still ship and still work. The newer styles cover the same ground
  better.
- Full and Competitive are unchanged apart from the footstep change.
- New headphone measurements: Tipsy TG4 (both switch positions) and I/O Audio
  Cielo.
- All other games and versions are unchanged.

## If you use BO7 V5

Start with Classic+ at Ultra Low. Point the 16ch tune line in your
`config.txt` at:

```
Include: ArtTuneDB\library\BO7\V5\BO7_V5_16ch_ClassicPlus-UltraLoGun.txt
```

V5 now ships 40 configs, eight styles at five self gun levels.
`library/BO7/V5/Choose a 16ch Tune.txt` lists every one, marks the new,
experimental and deprecated styles, and names the exact file to use.

The V5 target curve is unchanged, so your existing squig.link EQ still applies.

See [2026.07.1-Overhaul](https://github.com/ArtIsWar/ArtTuneDB/releases/tag/2026.07.1-Overhaul)
for the release this builds on.
