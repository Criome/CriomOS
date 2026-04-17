# Adaptive Charging Daemon — Design

## Problem

Lithium-ion cells degrade fastest at high state of charge. At 4.20V (100% SOC),
parasitic SEI growth consumes cyclable lithium at ~20% capacity loss per year at
25C. At 40% SOC the loss drops to ~4%. A laptop perpetually plugged at 100% gets
the worst of calendar aging and micro-cycling near the voltage ceiling.

Static threshold capping (hold at 80%) solves most of the problem but leaves
charge on the table: a user departing for a flight wants 100%, not 80%. ChromeOS
solves this with ML-predicted unplug times — hold at 80%, then charge to 100%
two hours before the user typically leaves.

No upstream Linux equivalent exists outside ChromeOS. The kernel interfaces
(charge_control_start_threshold, charge_control_end_threshold, charge_behaviour)
are all present on ThinkPad via thinkpad_acpi. The intelligence layer is missing.

## Goal

A Rust daemon that learns plug/unplug patterns and writes to sysfs to hold
battery at a low-stress SOC, releasing to full charge only when departure is
predicted. Follows Mentci architecture: own CozoDB, own repo, relations as
source of truth, MCP tools for introspection.

## Name

criome-charger

## Kernel Interface (ThinkPad)

thinkpad_acpi (kernel >= 5.17) exposes on /sys/class/power_supply/BAT0/:

| sysfs path                       | range   | persist | purpose                    |
|----------------------------------|---------|---------|----------------------------|
| charge_control_start_threshold   | 0-99    | EC      | resume charging below this |
| charge_control_end_threshold     | 1-100   | EC      | stop charging above this   |
| charge_behaviour                 | enum    | no      | auto/inhibit-charge/force-discharge |
| capacity                         | 0-100   | n/a     | current SOC reading        |
| status                           | string  | n/a     | Charging/Discharging/Full/Not charging |

ThinkPad thresholds are written to EC registers and survive reboot. The daemon
writes them once and only changes them when predictions change. charge_behaviour
resets on reboot — needs systemd restoration.

For non-ThinkPad hardware (ASUS, Framework, Dell), the same sysfs paths exist
but behaviour varies (ASUS resets on power cycle, Dell enforces start=stop-5).
Phase 1 targets ThinkPad only. Abstraction layer for other vendors comes later.

## Architecture

```
                   +-----------------+
  udev events ---> |                 | ---> sysfs writes
  timerfd alarm -> | criome-charger  |      (charge_control_*_threshold)
  D-Bus suspend -> |                 |      (charge_behaviour)
                   |  +----------+   |
  MCP tools <----> |  | CozoDB   |   |
                   |  | world.db |   |
                   |  +----------+   |
                   +-----------------+
```

### Subsystems

1. **Monitor** — watches power_supply udev events, reads sysfs for SOC and
   charge status. Records plug/unplug sessions to CozoDB.

2. **Predictor** — given current time and historical sessions, produces a
   probability distribution over unplug time (9 buckets: hours 0-7, >8h).

3. **Controller** — consumes predictions, decides whether to hold or release,
   writes sysfs. Handles suspend/resume coordination.

4. **MCP interface** — query tools for introspection: current prediction,
   session history, model state, manual override ("charge now").

## RTC Wakeups and Suspend

The daemon must re-evaluate predictions while the system is suspended (the
laptop is closed, plugged in, held at 80%). If the predicted departure time
approaches, it must wake, release the charge hold, then re-suspend.

### Mechanism: CLOCK_BOOTTIME_ALARM timerfd

```rust
use nix::sys::timerfd::{ClockId, TimerFd, TimerFlags, TimerSetTimeFlags, Expiration};

let tfd = TimerFd::new(ClockId::CLOCK_BOOTTIME_ALARM, TimerFlags::TFD_NONBLOCK)?;
tfd.set(
    Expiration::IntervalDelayed(
        Duration::from_secs(30 * 60),  // repeat every 30 min
        Duration::from_secs(30 * 60),  // first fire in 30 min
    ),
    TimerSetTimeFlags::empty(),
)?;
```

CLOCK_BOOTTIME_ALARM is the correct clock:
- Monotonic — immune to NTP jumps and manual clock changes
- Advances through suspend — "every 30 minutes" means wall-clock time
- Kernel automatically programs the hardware RTC during suspend path
  (alarmtimer_suspend multiplexes all pending alarms onto one RTC)
- The timerfd becomes readable when the alarm fires, works with epoll/tokio

No manual RTC programming, no sysfs wakealarm, no rtcwake, no ioctls.

### Capability

Requires CAP_WAKE_ALARM. Granted via systemd unit:

```ini
[Service]
AmbientCapabilities=CAP_WAKE_ALARM
```

Since systemd v254, CAP_WAKE_ALARM is also passed to systemd --user.

### Suspend Coordination

The daemon takes a systemd delay inhibitor lock via D-Bus
(org.freedesktop.login1.Manager.Inhibit) so it gets time to finish its
evaluation before re-suspend. Listen for PrepareForSleep(true/false) signals.
Default delay timeout is 5 seconds — more than enough for a sysfs write.

### Power Cost

On s2idle (ThinkPad default): ~100ms wake latency. Each cycle takes <5 seconds
(read battery, run prediction, decide, write sysfs, re-suspend). Over 8 hours:
16 wakes, ~80 seconds total awake time. Negligible power impact. Display does
not turn on — compositors only unblank on input events (this is a dark wake).

### Alternative: Single Wake Alarm

Instead of polling every 30 minutes, compute the exact release time at suspend
and set a single alarm. Re-evaluate only on resume or AC state change. This is
simpler but less responsive to model updates — acceptable for phase 1.

## ML Prediction

### Phase 1: Bayesian Histogram (ship first, no dependencies)

No ML framework. Pure Rust, zero dependencies beyond std.

Structure:
- 56 time slots (7 days-of-week x 8 three-hour blocks)
- Each slot: [f64; 9] — histogram over 9 duration buckets
- Dirichlet prior: [1.0; 9] (uniform — no prediction until data accumulates)
- Exponential decay: 0.97 per observation (recent patterns weighted higher)

```
Prediction(day_of_week, hour):
    slot = slots[dow][hour / 3]
    neighbors = adjacent slots (same day prev/next block, same block prev/next day)
    prior = dirichlet + 0.3 * global_histogram
    posterior = prior + slot.histogram + 0.5 * sum(neighbor.histograms)
    probabilities = posterior / sum(posterior)
    return probabilities  // [f64; 9]
```

Update(session_duration):
    bucket = duration_to_bucket(session_duration)  // 0..8
    slot = slots[dow][hour / 3]
    slot.histogram[bucket] += 1.0
    slot.histogram *= 0.97  // decay

Properties:
- Works from day one with uniform prior (degenerates to static 80% hold)
- Adapts to user patterns within 2-3 weeks
- Trivially serializable to CozoDB relations
- ~150 lines of Rust
- No training pipeline, no model files, no two-language workflow

### Phase 2: Small MLP via ndarray (if histogram accuracy is insufficient)

Train offline in Python using collected session data, export weights:

- Architecture: Input(32) -> Dense(32, ReLU) -> Dense(16, ReLU) -> Dense(9, Softmax)
- 1,737 parameters total
- Features (32):
  - sin(2pi * hour/24), cos(2pi * hour/24) — cyclical time encoding
  - sin(2pi * dow/7), cos(2pi * dow/7) — cyclical day encoding
  - Last 10 session durations (minutes, normalized to [0,1] by /480)
  - Per-time-slot mean duration (8 three-hour windows)
  - Per-day-of-week mean duration (7 values)
  - Current session duration so far
  - Total: 32 features

Forward pass in ~200 lines of ndarray code. Weights stored as a binary blob
embedded in the binary or loaded from a CozoDB relation. No ML framework needed.

### Phase 3: tract ONNX (if complex patterns need a richer model)

Train in Python (PyTorch/sklearn), export to ONNX, infer via tract-onnx.
Pure Rust, no C deps, ~2 MB binary overhead. Only pursue if phase 2 proves
insufficient — unlikely for a single-user device.

### Why Not Other Frameworks

| Framework    | Verdict                                               |
|-------------|-------------------------------------------------------|
| candle       | Targets LLMs/diffusion. Massive overkill.            |
| burn         | Full training framework. Heavy for 1,737 parameters. |
| ort          | Links ONNX Runtime C++ (~100 MB). Absurd.            |
| tch-rs       | Links libtorch (~500 MB). Absurd.                    |
| linfa        | Classical ML. Viable but FTRL is binary-only.        |
| smartcore    | Viable. Multinomial NB could work. But ndarray is simpler. |

### Decision Logic

The controller uses ChromeOS-style cumulative probability:

```
probabilities = predictor.predict(now)
cumulative = 0.0
release_hour = 9  // default: never release (hold indefinitely)
for hour in 0..9:
    cumulative += probabilities[hour]
    if cumulative >= 0.35:
        release_hour = hour
        break

if release_hour <= 2:
    // Unplug predicted within 2 hours — release charge hold
    write_threshold(100)
    write_behaviour("auto")
else:
    // Still distant — maintain hold
    write_threshold(hold_percent)  // default 80
    write_behaviour("auto")
```

When no prediction exceeds the threshold, the system holds at 80% indefinitely
and re-evaluates every 30 minutes. This is the correct conservative default.

## CozoDB Relations

```cozoscript
:create charge_session {
    start_ts: String
    =>
    end_ts: String,
    duration_minutes: Int,
    start_soc: Int,
    end_soc: Int,
    day_of_week: Int,
    hour_of_day: Int,
    phase: String,
    dignity: String
}

:create charge_histogram {
    day_of_week: Int,
    time_block: Int
    =>
    bucket_0: Float,
    bucket_1: Float,
    bucket_2: Float,
    bucket_3: Float,
    bucket_4: Float,
    bucket_5: Float,
    bucket_6: Float,
    bucket_7: Float,
    bucket_8: Float,
    phase: String,
    dignity: String
}

:create charge_config {
    key: String
    =>
    value: String,
    phase: String,
    dignity: String
}

:create charge_state {
    key: String
    =>
    value: String
}
```

charge_session: each plug/unplug cycle as a record. Retained 30 days.
charge_histogram: the 56-slot Bayesian histogram, persisted for crash recovery.
charge_config: hold_percent, min_probability, evaluation_interval_minutes, etc.
charge_state: ephemeral runtime state (current_mode, last_prediction, etc.).

## MCP Tools

| Tool              | Description                                    |
|-------------------|------------------------------------------------|
| charge_status     | Current SOC, threshold, behaviour, hold state  |
| charge_predict    | Run prediction for current time, return probs  |
| charge_history    | Last N sessions with durations                 |
| charge_now        | Override: release hold, charge to 100% now     |
| charge_hold       | Override: force hold at configured percent     |
| charge_calibrate  | Force-discharge cycle for gauge recalibration  |
| charge_config     | Read/write configuration (hold%, threshold)    |

## systemd Integration (NixOS)

```nix
systemd.services.criome-charger = {
    description = "Adaptive battery charge management";
    after = [ "local-fs.target" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
        Type = "notify";
        ExecStart = "criome-charger --db /var/lib/criome-charger/world.db";
        StateDirectory = "criome-charger";
        AmbientCapabilities = "CAP_WAKE_ALARM";
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [
            "/sys/class/power_supply/BAT0"
            "/var/lib/criome-charger"
        ];
        Restart = "on-failure";
    };
};
```

## Async Architecture (tokio)

```rust
#[tokio::main]
async fn main() -> Result<()> {
    // 1. tracing to stderr
    // 2. CLI args (clap)
    // 3. CozoDB init + genesis
    // 4. spawn subsystems as tokio tasks

    let db = Arc::new(CriomeDb::open_sqlite(&args.db_path)?);

    // Monitor: udev power_supply events -> record sessions
    let monitor_handle = tokio::spawn(monitor::run(db.clone(), tx.clone()));

    // Controller: timerfd alarm loop -> predict -> write sysfs
    let controller_handle = tokio::spawn(controller::run(db.clone(), rx));

    // MCP: stdio JSON-RPC for introspection
    let mcp_handle = tokio::spawn(mcp::run(db.clone()));

    // Wait for any task to finish (shouldn't happen)
    tokio::select! {
        r = monitor_handle => r??,
        r = controller_handle => r??,
        r = mcp_handle => r??,
    }

    Ok(())
}
```

The timerfd with CLOCK_BOOTTIME_ALARM is wrapped in tokio::io::AsyncFd for
async integration:

```rust
use tokio::io::unix::AsyncFd;
use nix::sys::timerfd::TimerFd;

let tfd = TimerFd::new(ClockId::CLOCK_BOOTTIME_ALARM, TimerFlags::TFD_NONBLOCK)?;
// ... set interval ...
let async_tfd = AsyncFd::new(tfd)?;

loop {
    let mut guard = async_tfd.readable().await?;
    guard.get_inner().wait()?;  // consume the timerfd read
    guard.clear_ready();

    // Woke from suspend (or interval elapsed while awake)
    let prediction = predictor.predict(Utc::now(), &db)?;
    controller.evaluate(prediction, &db)?;
}
```

## Repo Structure

```
criome-charger/
    Cargo.toml
    flake.nix               # crane + fenix
    src/
        main.rs             # entry point: args, db init, spawn tasks
        lib.rs              # pub mod monitor, controller, predictor, mcp, error
        monitor.rs          # udev event listener, session recording
        predictor.rs        # Bayesian histogram + prediction
        controller.rs       # decision logic + sysfs writes + timerfd + suspend
        mcp.rs              # rmcp ServerHandler + tool definitions
        sysfs.rs            # typed sysfs read/write for power_supply
        error.rs            # Error enum
    schema/
        charger-init.cozo   # :create relations
        charger-seed.cozo   # :put defaults (hold_percent=80, etc.)
    tests/
        prediction_test.rs  # histogram accuracy with synthetic data
        controller_test.rs  # decision logic with mock sysfs
        integration_test.rs # MCP client round-trip
```

## Dependencies

```toml
[dependencies]
criome-cozo = { path = "flake-crates/criome-cozo" }
rmcp = { version = "0.16", features = ["server", "transport-io", "macros"] }
tokio = { version = "1", features = ["full"] }
nix = { version = "0.30", features = ["time", "poll"] }
tracing = "0.1"
tracing-subscriber = { version = "0.3", features = ["env-filter"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
schemars = "1.0"
clap = { version = "4", features = ["derive"] }
chrono = "0.4"

[dev-dependencies]
rmcp = { version = "0.16", features = ["client", "transport-io"] }
```

No ML framework. No BLAS. No C dependencies. Phase 2 adds ndarray (~200KB).

## Phasing

### Phase 1 — Static threshold + session recording
- Write thresholds to sysfs (configurable hold_percent, default 80)
- Record plug/unplug sessions to CozoDB
- MCP tools for status and manual override
- systemd service with CAP_WAKE_ALARM
- No prediction yet — just a smart threshold manager
- Ship when: builds, deploys, holds at 80%

### Phase 2 — Bayesian histogram prediction
- Implement 56-slot histogram predictor
- Add timerfd alarm loop for suspend re-evaluation
- Add D-Bus suspend inhibitor for coordination
- Controller uses prediction to release hold before departure
- Ship when: 2+ weeks of personal data validates predictions

### Phase 3 — MLP upgrade (if needed)
- Collect 30+ days of session data from phase 2
- Train small MLP in Python, export weights
- Implement ndarray forward pass
- A/B compare histogram vs MLP predictions in CozoDB
- Ship when: MLP measurably outperforms histogram

### Phase 4 — Multi-vendor support
- Abstract sysfs interface for ASUS, Framework, Dell
- Handle vendor quirks (ASUS resets on power cycle, Dell start=stop-5)
- Detect hardware via DMI or driver presence

## Open Questions

1. Should the daemon run as system service (root) or user service? System is
   simpler for sysfs access. User service would need udev rules granting write
   to power_supply. System service + MCP over socket lets user tools query it.

2. Should the 30-minute poll be configurable? ChromeOS uses fixed 30min.
   Shorter intervals waste power. Longer intervals miss departure windows.
   Default 30min, configurable via charge_config relation.

3. Force-discharge for gauge calibration: should the daemon auto-schedule this
   (e.g., every 90 days) or only on manual trigger? Auto-scheduling a full
   discharge cycle is aggressive. Manual via MCP tool is safer for phase 1.

4. Should the daemon integrate with darkman/noctalia for "leaving soon" UI
   hints? A shell widget showing "Holding at 80% — predicted departure in 3h"
   would be useful feedback. Phase 2+ concern.
