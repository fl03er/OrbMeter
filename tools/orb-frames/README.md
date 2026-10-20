# orb-frames

Regenerates the runner frames in `LocalPackage/Sources/UserInterface/Resources/Media.xcassets/Runners/` from the [thinking-orbs](https://www.npmjs.com/package/thinking-orbs) engine.

```bash
cd tools/orb-frames
npm install
npm run render                                                     # writes out/<state>/frame-N.png and out/frames.json
python3 install_assets.py out ../../LocalPackage/Sources/UserInterface/Resources
python3 gifs.py out ../../docs/orbs                                # README GIFs (needs Pillow)
```

If a state's frame count changes, update `numberOfResources` in `LocalPackage/Sources/DataSource/Entities/Runner/RunnerKind.swift`.

Knobs at the top of `render.mjs`:

| Constant | Meaning |
|---|---|
| `PX` | Frame size in pixels. 44 = 22 pt at 2x, the full status item height. |
| `PRESET` | thinking-orbs size preset whose dot count and radii are used (20, 32 or 64). |
| `RADIUS` | Extra dot radius multiplier. |
| `GLOW` | Alpha boost so dots stay legible on light and dark menu bars. |
| `BREATH` | How much brightness swings over one loop. |
| `FILL` | How far the farthest dot may reach toward the frame edge. |
| `CONFIG[state].period` | Loop length in seconds at the orb's natural speed. |

`FRAMES_PER_SEC` is 8 because the app plays frames at 2 x speed per second and the speed is CPU% / 5, so an orb moves at its natural pace around 20% CPU.
