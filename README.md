# Particle Smog — a live sound-to-particle painting

An awareness piece: the room's ambient sound is captured, analyzed, and
rendered as a live particle swarm. **Pitch sets the hue, volume sets how
much of the canvas is "polluted."** The render always reflects the
*current* state of the space — quiet rooms stay calm and sparse; loud,
harsh environments fill the screen with dense, fast, saturated particles.
Nothing accumulates; it's a live meter, not an archive.

## Architecture

```
 microphone
     |
     v
 Pure Data (pd/particle_smog.pd)
     |  env~        -> volume (0-1, normalized RMS)
     |  fiddle~     -> pitch (MIDI, raw, continuous) -> mtof -> Hz
     v
 plain UDP text, localhost:12000
     |  "volume 0.42"
     |  "pitch 220.5"
     v
 Processing (processing/ParticleSmog/)
     -> particle swarm: hue = f(pitch), density/speed/size = f(volume)
```

Both halves use **only what ships in the box** — vanilla Pd objects
(`env~`, `fiddle~`, `mtof`, `netsend`) and Java's built-in
`DatagramSocket` in Processing. No Deken externals, no `oscP5`. This is
deliberate: compiled binary externals (mrpeach's `oscformat`/`packOSC`,
iemnet's `udpsend`) frequently fail to load if they weren't built for
your Pd version/CPU architecture, which is exactly what happened during
development of this piece — so the pipeline was simplified to plain UDP
text instead of binary OSC to guarantee it works anywhere.

## Technologies used

- **[Pure Data (Pd)](https://puredata.info/)** (vanilla, no externals) —
  microphone capture and audio analysis: `env~` for volume, `fiddle~` +
  `mtof` for pitch, `netsend` to stream results out over UDP.
- **[Processing](https://processing.org/)** (Java-based, core library
  only) — receives the UDP stream via `java.net.DatagramSocket` and
  renders the live particle swarm.
- Plain **UDP text** as the wire protocol between the two (no OSC
  library on either side — see *Architecture* above for why).

## Run it locally

Requires [Pd](https://puredata.info/downloads) and
[Processing](https://processing.org/download) installed — both free,
no other dependencies or libraries needed.

1. **Start Pure Data first**: open `pd/particle_smog.pd`.
   - Enable audio: menu → *Media → DSP On* (or ⌘/Ctrl+/).
   - On macOS, grant Pd microphone access if prompted (System Settings →
     Privacy & Security → Microphone).
   - It streams to `localhost:12000` automatically on load.

2. **Then start Processing**: open
   `processing/ParticleSmog/ParticleSmog.pde` and press Run. Press
   `h` in the sketch window to toggle the on-screen pitch/volume readout.

Pd must be running (with DSP on) before or as Processing starts, so a
sender is live when Processing's socket starts listening on port 12000
— if you start Processing first, it just sits idle at 0/0 until Pd
comes online.

## Mapping design

- **Hue** — pitch is mapped on a *log* scale from 60 Hz–4000 Hz onto a
  0–300° hue sweep (red → violet), because pitch perception itself is
  logarithmic. Low rumble reads warm/red, sharp high-pitched sound reads
  violet/blue.
- **Density / speed / size / saturation** — all scale with the normalized
  volume envelope: quiet = few, slow, small, pale particles; loud = many,
  fast, large, saturated ones.
- **High-noise readout** — above a volume threshold (tunable via
  `ALERT_VOLUME` in the sketch) the HUD flags "-- high noise level --",
  echoing WHO guidance that sustained loud exposure is harmful — the
  piece's explicit awareness beat.

## Known limitation, on purpose

`fiddle~` is a *pitch* tracker built for tonal/monophonic sound. Real
environmental noise pollution — traffic, HVAC, construction — is mostly
broadband/non-tonal, so the pitch reading will often be jumpy or low. That's
expected: the piece still communicates the point (loud, chaotic sound also
becomes visually chaotic and colorful) even when the "pitch" itself is a
rough source of color rather than a precise sung note.

If you want a steadier color signal, swap in a **spectral centroid**
("brightness") measurement instead of pitch tracking — it's more robust
for broadband noise. That's a bigger Pd rework (FFT-based, not a drop-in
replacement for `fiddle~`), so it isn't included here.

## Tuning

- `pd/particle_smog.pd`: `+ 60 / 60` normalizes `env~`'s dB output
  assuming ambient levels roughly -60 dB to 0 dB; adjust the `60` to
  taste for your mic's gain/sensitivity.
- `ParticleSmog.pde`: `MIN_FREQ`/`MAX_FREQ`/`HUE_RANGE` for the color
  mapping, `ALERT_VOLUME` for the warning threshold, and the `map(...)`
  calls in `Particle`'s constructor for how aggressively volume affects
  particle count/speed/size.
- For a gallery install, change `size(1000, 700)` in `settings()` to
  `fullScreen()`.
