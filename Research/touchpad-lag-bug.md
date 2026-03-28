# Touchpad Lag Bug — Intel ThinkPads

## Symptom
Cursor lags behind finger movement on touchpad for **minutes**, not
milliseconds. Intermittent — not always present. Clears on its own
without intervention. No CPU spike during the lag. Keyboard input
unaffected (needs confirmation).

## Affected Hardware
Multiple Intel ThinkPads (exact models TBD). Observed on localhost
(ouranos likely, running niri compositor).

## Ruled Out
- **CPU contention**: no spike during lag episodes.
- **PSR (Panel Self Refresh)**: PSR exit lag is ~50ms, not minutes.
  Still worth disabling (`i915.enable_psr=0`) as a compounding factor.

## Likely Causes (ranked)
1. **i2c-hid stuck in low report rate**: touchpad enters a degraded
   polling mode after power state transition, reporting at ~10Hz instead
   of 100Hz+. Recovers eventually when i2c bus re-negotiates normal
   clock speed.
2. **i2c bus clock stuck slow**: after a CPU package C-state exit or
   i2c controller runtime PM resume, the bus clock may not return to
   full speed immediately.
3. **Compositor frame scheduling stall**: niri (or Wayland compositor)
   stops rendering frames during some background operation, queuing
   input events without displaying them.

## Diagnostic — Run During Next Episode
```bash
# Kernel messages for i2c errors/timeouts
dmesg | tail -30

# Touchpad runtime PM state
cat /sys/bus/i2c/devices/*/power/runtime_status

# Live event rate — check for large gaps between timestamps
libinput debug-events 2>&1 | head -40

# Check if compositor is responsive (does keyboard input work?)
# Try switching workspace or opening a terminal with keybind
```

## Potential Fixes (untested)
```nix
# Disable i2c-hid runtime PM for touchpad
services.udev.extraRules = ''
  ACTION=="add", SUBSYSTEM=="i2c", DRIVERS=="i2c_hid_acpi", ATTR{power/control}="on"
'';

# Disable PSR (compounding factor)
boot.kernelParams = [ "i915.enable_psr=0" ];
```

## Status
Open — waiting for next occurrence to capture diagnostics.
