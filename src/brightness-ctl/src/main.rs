use std::env;
use std::fmt;
use std::fs;
use std::io;
use std::process::Command;

// --- Domain objects ---

struct Backlight {
    brightness: u64,
    max: u64,
    step: u64,
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

// --- Backlight ---

const SYSFS_PATH: &str = "/sys/class/backlight/intel_backlight";
const GAMMA_STEP: f64 = 0.02;
const GAMMA_FLOOR: f64 = 0.02;
const DBUS_DEST: &str = "rs.wl-gammarelay";
const DBUS_PATH: &str = "/";
const DBUS_IFACE: &str = "rs.wl.gammarelay";

impl Backlight {
    fn from_sysfs() -> Result<Self, Error> {
        let max = read_sysfs_u64(SYSFS_PATH, "max_brightness")?;
        let brightness = read_sysfs_u64(SYSFS_PATH, "brightness")?;
        let step = max / 100;
        Ok(Self {
            brightness,
            max,
            step,
            sysfs: SYSFS_PATH,
        })
    }

    fn set(&mut self, value: u64) -> Result<(), Error> {
        let clamped = value.clamp(self.step, self.max);
        fs::write(format!("{}/brightness", self.sysfs), clamped.to_string())?;
        self.brightness = clamped;
        Ok(())
    }

    fn at_minimum(&self) -> bool {
        self.brightness <= self.step
    }

    fn hardware_pct(&self) -> f64 {
        (self.brightness as f64 / self.max as f64) * 100.0
    }
}

// --- GammaBrightness ---

impl GammaBrightness {
    fn from_dbus() -> Result<Self, Error> {
        let output = busctl_cmd(&["--user", "get-property", DBUS_DEST, DBUS_PATH, DBUS_IFACE, "Brightness"])?;
        let val = output
            .split_whitespace()
            .nth(1)
            .ok_or_else(|| Error::Parse(output.clone()))?
            .parse::<f64>()
            .map_err(|e| Error::Parse(e.to_string()))?;
        Ok(Self(val))
    }

    fn set(&mut self, value: f64) -> Result<(), Error> {
        let clamped = value.clamp(GAMMA_FLOOR, 1.0);
        busctl_cmd(&[
            "--user", "set-property", DBUS_DEST, DBUS_PATH, DBUS_IFACE,
            "Brightness", "d", &clamped.to_string(),
        ])?;
        self.0 = clamped;
        Ok(())
    }

    fn below_full(&self) -> bool {
        self.0 < 1.0
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
}

// --- Arc (degree/minute/second display) ---

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
                    let new = (gamma.0 + GAMMA_STEP).min(1.0);
                    gamma.set(new)?;
                } else {
                    backlight.set(backlight.brightness + backlight.step)?;
                }
            }
            Self::Down => {
                if backlight.at_minimum() {
                    backlight.set(backlight.step)?;
                    let new = (gamma.0 - GAMMA_STEP).max(GAMMA_FLOOR);
                    gamma.set(new)?;
                } else {
                    backlight.set(backlight.brightness - backlight.step)?;
                }
            }
        }
        Ok(())
    }
}

// --- Notification ---

fn notify(effective: &EffectiveBrightness, gamma: &GammaBrightness) -> Result<(), Error> {
    let arc = effective.to_arc();
    let sw_tag = if gamma.below_full() { " (sw)" } else { "" };
    let label = format!("{arc}{sw_tag}");
    let bar = effective.progress_bar().to_string();

    run_as_user("notify-send", &[
        "-h", "string:x-canonical-private-synchronous:brightness",
        "-h", &format!("int:value:{bar}"),
        "-t", "1500",
        "Brightness",
        &label,
    ])?;
    Ok(())
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
    notify(&effective, &gamma)?;

    Ok(())
}
