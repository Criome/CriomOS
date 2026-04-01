use std::env;
use std::fmt;
use std::fs;
use std::io;
use std::process::Command;

// --- Domain objects ---

struct Backlight {
    brightness: u64,
    max: u64,
    sysfs: &'static str,
}

struct GammaBrightness(f64);

struct EffectiveBrightness {
    hardware_pct: f64,
    gamma: f64,
}

struct Arc {
    degrees: f64,
}

enum Direction {
    Up,
    Down,
}

// --- Error ---

enum Error {
    Io(io::Error),
    Parse(String),
    Dbus(String),
}

impl fmt::Debug for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Io(e) => write!(f, "io: {e}"),
            Self::Parse(s) => write!(f, "parse: {s}"),
            Self::Dbus(s) => write!(f, "dbus: {s}"),
        }
    }
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        fmt::Debug::fmt(self, f)
    }
}

impl std::error::Error for Error {}

impl From<io::Error> for Error {
    fn from(e: io::Error) -> Self {
        Self::Io(e)
    }
}

// --- Constants ---

const SYSFS_PATH: &str = "/sys/class/backlight/intel_backlight";
const DBUS_DEST: &str = "rs.wl-gammarelay";
const DBUS_PATH: &str = "/";
const DBUS_IFACE: &str = "rs.wl.gammarelay";

/// Perceptual step fraction: each key press shifts 15% of current brightness.
const STEP_NUM: u64 = 15;
const STEP_DEN: u64 = 100;

/// Software gamma tiers below hardware minimum. Linearly spaced with 7 steps
/// from full gamma down to effectively off.
const GAMMA_LEVELS: [f64; 8] = [1.0, 0.875, 0.75, 0.625, 0.5, 0.375, 0.25, 0.125];

// --- Backlight ---

impl Backlight {
    fn from_sysfs() -> Result<Self, Error> {
        let max = read_sysfs_u64(SYSFS_PATH, "max_brightness")?;
        let brightness = read_sysfs_u64(SYSFS_PATH, "brightness")?;
        Ok(Self {
            brightness,
            max,
            sysfs: SYSFS_PATH,
        })
    }

    /// Smallest hardware brightness value — the floor before gamma takes over.
    fn min_hw(&self) -> u64 {
        (self.max / 500).max(1)
    }

    /// Perceptual step proportional to current level, floored at min_hw.
    fn step(&self) -> u64 {
        (self.brightness * STEP_NUM / STEP_DEN).max(self.min_hw())
    }

    fn set(&mut self, value: u64) -> Result<(), Error> {
        let clamped = value.clamp(self.min_hw(), self.max);
        fs::write(format!("{}/brightness", self.sysfs), clamped.to_string())?;
        self.brightness = clamped;
        Ok(())
    }

    fn at_minimum(&self) -> bool {
        self.brightness <= self.min_hw()
    }

    fn hardware_pct(&self) -> f64 {
        (self.brightness as f64 / self.max as f64) * 100.0
    }
}

// --- GammaBrightness ---

impl GammaBrightness {
    fn from_dbus() -> Result<Self, Error> {
        let output = busctl_cmd(&[
            "--user", "get-property", DBUS_DEST, DBUS_PATH, DBUS_IFACE, "Brightness",
        ])?;
        let val = output
            .split_whitespace()
            .nth(1)
            .ok_or_else(|| Error::Parse(output.clone()))?
            .parse::<f64>()
            .map_err(|e| Error::Parse(e.to_string()))?;
        Ok(Self(val))
    }

    fn set(&mut self, value: f64) -> Result<(), Error> {
        let floor = GAMMA_LEVELS[GAMMA_LEVELS.len() - 1];
        let clamped = value.clamp(floor, 1.0);
        busctl_cmd(&[
            "--user", "set-property", DBUS_DEST, DBUS_PATH, DBUS_IFACE,
            "Brightness", "d", &clamped.to_string(),
        ])?;
        self.0 = clamped;
        Ok(())
    }

    fn below_full(&self) -> bool {
        self.0 < 1.0 - f64::EPSILON
    }

    /// Index of the nearest matching tier in GAMMA_LEVELS.
    fn level_index(&self) -> usize {
        GAMMA_LEVELS
            .iter()
            .enumerate()
            .min_by(|(_, a), (_, b)| {
                (self.0 - *a).abs().partial_cmp(&(self.0 - *b).abs()).unwrap()
            })
            .map(|(i, _)| i)
            .unwrap_or(0)
    }

    /// Step toward darker: advance to the next lower gamma tier.
    fn step_down(&mut self) -> Result<(), Error> {
        let idx = self.level_index();
        let next = (idx + 1).min(GAMMA_LEVELS.len() - 1);
        self.set(GAMMA_LEVELS[next])
    }

    /// Step toward brighter: advance to the next higher gamma tier.
    fn step_up(&mut self) -> Result<(), Error> {
        let idx = self.level_index();
        if idx == 0 {
            self.set(1.0)
        } else {
            self.set(GAMMA_LEVELS[idx - 1])
        }
    }
}

// --- EffectiveBrightness ---

impl EffectiveBrightness {
    fn from_state(backlight: &Backlight, gamma: &GammaBrightness) -> Self {
        Self {
            hardware_pct: backlight.hardware_pct(),
            gamma: gamma.0,
        }
    }

    fn to_arc(&self) -> Arc {
        Arc {
            degrees: self.hardware_pct * self.gamma * 3.6,
        }
    }

    fn progress_bar(&self) -> u8 {
        let pct = self.hardware_pct * self.gamma;
        (pct.clamp(0.0, 100.0)) as u8
    }

    fn notify(&self) -> Result<(), Error> {
        let arc = self.to_arc();
        let sw_tag = if self.gamma < 1.0 - f64::EPSILON { " (sw)" } else { "" };
        let label = format!("{arc}{sw_tag}");
        let bar = self.progress_bar().to_string();

        run_as_user("notify-send", &[
            "-h", "string:x-canonical-private-synchronous:brightness",
            "-h", &format!("int:value:{bar}"),
            "-t", "1500",
            "Brightness",
            &label,
        ])?;
        Ok(())
    }
}

// --- Arc ---

impl fmt::Display for Arc {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        let d = self.degrees;
        if d >= 1.0 {
            write!(f, "{:.0}°", d)
        } else {
            let arcmin = d * 60.0;
            if arcmin >= 1.0 {
                write!(f, "{:.0}′", arcmin)
            } else {
                let arcsec = d * 3600.0;
                write!(f, "{:.0}″", arcsec.max(1.0))
            }
        }
    }
}

// --- Direction ---

impl Direction {
    fn from_arg(arg: &str) -> Result<Self, Error> {
        match arg {
            "up" => Ok(Self::Up),
            "down" => Ok(Self::Down),
            other => Err(Error::Parse(format!("expected up|down, got: {other}"))),
        }
    }

    fn apply(&self, backlight: &mut Backlight, gamma: &mut GammaBrightness) -> Result<(), Error> {
        match self {
            Self::Up => {
                if gamma.below_full() {
                    gamma.step_up()?;
                } else {
                    let step = backlight.step();
                    backlight.set(backlight.brightness + step)?;
                }
            }
            Self::Down => {
                if backlight.at_minimum() {
                    gamma.step_down()?;
                } else {
                    let step = backlight.step();
                    backlight.set(backlight.brightness.saturating_sub(step))?;
                }
            }
        }
        Ok(())
    }
}

// --- Helpers ---

fn read_sysfs_u64(base: &str, name: &str) -> Result<u64, Error> {
    let content = fs::read_to_string(format!("{base}/{name}"))?;
    content
        .trim()
        .parse::<u64>()
        .map_err(|e| Error::Parse(e.to_string()))
}

fn run_as_user(cmd: &str, args: &[&str]) -> Result<String, Error> {
    let uid = 1001u32;
    let addr = format!("unix:path=/run/user/{uid}/bus");
    let output = Command::new("runuser")
        .args(["-u", "li", "--"])
        .arg("env")
        .arg(format!("DBUS_SESSION_BUS_ADDRESS={addr}"))
        .arg(cmd)
        .args(args)
        .output()?;
    if output.status.success() {
        Ok(String::from_utf8_lossy(&output.stdout).trim().to_string())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_string();
        Err(Error::Dbus(stderr))
    }
}

fn busctl_cmd(args: &[&str]) -> Result<String, Error> {
    run_as_user("busctl", args)
}

fn main() {
    let args: Vec<String> = env::args().collect();
    let direction = args.get(1).map(|s| s.as_str()).unwrap_or("down");

    if let Err(e) = run(direction) {
        eprintln!("brightness-ctl: {e}");
        std::process::exit(1);
    }
}

fn run(direction_arg: &str) -> Result<(), Error> {
    let direction = Direction::from_arg(direction_arg)?;
    let mut backlight = Backlight::from_sysfs()?;
    let mut gamma = GammaBrightness::from_dbus()?;

    direction.apply(&mut backlight, &mut gamma)?;

    let effective = EffectiveBrightness::from_state(&backlight, &gamma);
    effective.notify()?;

    Ok(())
}
