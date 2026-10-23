# M-Audio Fast Track Ultra 8R — Linux / Omarchy setup

Reproducible ALSA hardware mixer configuration for the **M-Audio Fast Track Ultra 8R**, tested with **Omarchy 4, PipeWire 1.6.9, PipeWire JACK, and Renoise 3.5.4** in October 2026.

## What the script does

- Routes host digital playback channels **1–8 to hardware outputs 1–8 one-to-one**, eliminating unwanted crossfeeds.
- Mutes all 64 analog-input-to-output hardware monitor routes (`AIn* - Out* Capture Volume`). The name `Capture` is misleading: these controls belong to the internal monitoring mixer, not Renoise's USB recording channels.
- Mutes DSP effects sends and returns; in the tested setup these had caused input audio to remain audible through outputs 1–4 even after direct monitoring was disabled.
- **Does not** disable USB recording inputs, set Renoise's monitoring mode, change PipeWire profiles, or save JACK port links.
- Checks for the expected ALSA controls and creates a timestamped backup **before** changing any routes.

**Safety:** Turn down speakers/headphones or monitor amp before running the script. Hardware routing changes may cause sudden level changes. You can restore your previous state using the backup.

## Requirements

On Arch Linux / Omarchy:

```bash
sudo pacman -S --needed alsa-utils pipewire-jack qpwgraph
```

If `jack2` is installed, pacman may ask to replace it with `pipewire-jack`. For an existing PipeWire setup, use its JACK compatibility library rather than running a separate JACK server.

Check the hardware:

```bash
aplay -l
arecord -l
cat /proc/asound/cards
wpctl status
```

The tested unit had the ALSA card ID `F8R`, shown as `Fast Track Ultra 8R`. In your sound profile utility (`pavucontrol`, if installed) select **Pro Audio** for the device if available.

## Apply hardware routing

```bash
git clone https://github.com/VertexBeatz/M-Audio-Fast-Track-Ultra-8R-Linux-Setup-Script.git
cd M-Audio-Fast-Track-Ultra-8R-Linux-Setup-Script
chmod +x scripts/setup-fasttrack.sh
./scripts/setup-fasttrack.sh
```

Default ALSA card ID: `F8R`. If the identifier differs, get it from `cat /proc/asound/cards` and set:

```bash
FASTTRACK_CARD=<card-id-or-number> ./scripts/setup-fasttrack.sh
```

The script saves the prior state under `~/.local/share/fasttrack-ultra-8r/backups/`. It prompts before applying changes. `--yes` skips the confirmation for controlled/unattended use, but **do not use it before confirming safe monitor levels**.

If control-device access is denied, check the logged-in user's audio permissions before running the entire script as root; using sudo also changes the backup location to root's home unless `FASTTRACK_BACKUP_DIR` is set.

## Configure Renoise and JACK

1. Launch Renoise using `pw-jack renoise` (or `pw-jack /path/to/renoise`).
2. In **Edit → Preferences → Audio**, select **JACK**, not direct ALSA `hw:` (which may be busy because PipeWire controls the interface).
3. Run `qpwgraph` and connect the JACK ports:

| Renoise ports | Fast Track PipeWire ports |
| --- | --- |
| `output_01_left/right` | `playback_AUX0/AUX1` |
| `output_02_left/right` | `playback_AUX2/AUX3` |
| `output_03_left/right` | `playback_AUX4/AUX5` |
| `output_04_left/right` | `playback_AUX6/AUX7` |
| `input_01_left/right` | `capture_AUX0/AUX1` |
| `input_02_left/right` | `capture_AUX2/AUX3` |
| `input_03_left/right` | `capture_AUX4/AUX5` |
| `input_04_left/right` | `capture_AUX6/AUX7` |

View active links with `pw-link -l`. JACK connections must be configured/preserved separately from ALSA mixer state; a qpwgraph patchbay is one way to maintain them.

## Validate

1. In Renoise, route the Master to output 01/02 and confirm that physical outputs 3–8 remain silent.
2. Route test tracks to output 02/03/04 pairs and confirm isolated physical outputs 3/4, 5/6 and 7/8.
3. Connect a low-level source to physical input 1. In **Sampler → Record**, select the appropriate input and verify its **recording meter moves**.
4. Check other inputs individually to verify channel numbering.
5. **Hearing silence while the recording meter moves is expected:** internal direct monitoring is disabled. Enable the Sampler monitor speaker or add Renoise's `#Line Input` device to a track to monitor through Renoise.
6. If you disconnect all eight JACK capture links from Renoise, analog sources should no longer be heard through the hardware outputs as a result of Renoise monitoring. If any remain audible, inspect hardware mixer and effects settings.

## Make configuration survive reboots

After verifying the routing works:

```bash
sudo alsactl store
systemctl status alsa-restore.service
```

Arch systems normally use ALSA restore functionality to reload saved mixer controls from `/var/lib/alsa/asound.state`, but startup/hotplug behavior can vary. **Reboot and verify**. If settings reset after reconnecting or rebooting, run the script again; a device-triggered systemd/udev setup may be needed for your machine.

For an optional portable snapshot of a known-good live setup:

```bash
alsactl -f "$HOME/fasttrack-working.state" store F8R
```

State files can be machine/driver-specific and are ignored by Git. Keep your actual working state backup privately and use the script as your portable source of truth.

## Rollback

The script prints the exact path to its timestamped backup. To restore that snapshot:

```bash
alsactl -f "$HOME/.local/share/fasttrack-ultra-8r/backups/REPLACE-WITH-BACKUP.state" restore F8R
```

If you want the reverted values to survive restart, run `sudo alsactl store` after restoring. Remember this restores the hardware mixer, not JACK links.

## On a new computer

Install `alsa-utils`, `pipewire-jack`, and `qpwgraph`; connect the Fast Track; select its Pro Audio profile; clone this repository; run the setup script; establish the JACK input/output links; and verify Renoise monitoring. Once everything is correct, `sudo alsactl store`, reboot, and check again.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Renoise says `Device or resource busy` with ALSA | Use JACK with PipeWire, not direct ALSA hardware access |
| Stereo master appears on all eight outputs | `pw-link -l` connections, then `DIn* - Out* Playback Volume` matrix |
| Can hear every analog input regardless of selected input | `AIn* - Out* Capture Volume` matrix and DSP effects sends/returns |
| Meter moves but can't hear recorded input live | Enable monitoring in Renoise |
| Script reports missing controls | Confirm card ID and supported ALSA mixer controls with `amixer -c F8R contents` |

## References

- [ArchWiki ALSA](https://wiki.archlinux.org/title/Advanced_Linux_Sound_Architecture)
- [alsactl manual](https://man.archlinux.org/man/alsactl.1)
- [FTU-Mixer — Fast Track Ultra series mixer](https://github.com/JonasSC/FTU-Mixer)

The project configures mixer controls available through Linux's ALSA driver. It does not install or replace firmware or drivers, and complete factory defaults were not established during testing.
