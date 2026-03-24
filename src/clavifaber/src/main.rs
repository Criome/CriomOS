mod complex;
mod gpg_agent;
mod ssh_key;
mod x509;

use clap::{Parser, Subcommand};
use std::fs;
use std::path::PathBuf;

#[derive(Parser)]
#[command(name = "clavifaber", about = "GPG → X.509 certificate tool for CriomOS WiFi PKI")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    /// Create a self-signed CA certificate from a GPG Ed25519 key
    CaInit {
        /// GPG keygrip of the CA key (40 hex chars)
        #[arg(long)]
        keygrip: String,

        /// Common Name for the CA certificate
        #[arg(long)]
        cn: String,

        /// Output PEM file path
        #[arg(long)]
        out: PathBuf,
    },

    /// Generate a P-256 server keypair + certificate signed by the CA
    ServerCert {
        /// GPG keygrip of the CA key
        #[arg(long)]
        ca_keygrip: String,

        /// Path to the CA certificate PEM
        #[arg(long)]
        ca_cert: PathBuf,

        /// Common Name for the server certificate
        #[arg(long)]
        cn: String,

        /// Output path for the server certificate PEM
        #[arg(long)]
        out_cert: PathBuf,

        /// Output path for the server private key PEM
        #[arg(long)]
        out_key: PathBuf,
    },

    /// Create an X.509 client certificate for a node's Ed25519 SSH pubkey
    NodeCert {
        /// GPG keygrip of the CA key
        #[arg(long)]
        ca_keygrip: String,

        /// Path to the CA certificate PEM
        #[arg(long)]
        ca_cert: PathBuf,

        /// SSH public key (openssh format: "ssh-ed25519 AAAA...")
        #[arg(long)]
        ssh_pubkey: String,

        /// Common Name for the node certificate (e.g. "li@ouranos")
        #[arg(long)]
        cn: String,

        /// Output PEM file path
        #[arg(long)]
        out: PathBuf,
    },

    /// Generate node identity complex (Ed25519 keypair) at first install
    ComplexInit {
        /// Directory to store the complex (e.g. /etc/criomOS/complex)
        #[arg(long)]
        dir: PathBuf,
    },

    /// Re-derive ssh.pub from the private key (run on every boot)
    DerivePubkey {
        /// Directory containing the complex
        #[arg(long)]
        dir: PathBuf,
    },

    /// Verify a certificate chains to the CA
    Verify {
        /// Path to the CA certificate PEM
        #[arg(long)]
        ca_cert: PathBuf,

        /// Path to the certificate to verify
        #[arg(long)]
        cert: PathBuf,
    },
}

fn main() {
    let cli = Cli::parse();

    let result = match cli.command {
        Commands::CaInit { keygrip, cn, out } => cmd_ca_init(&keygrip, &cn, &out),
        Commands::ServerCert {
            ca_keygrip,
            ca_cert,
            cn,
            out_cert,
            out_key,
        } => cmd_server_cert(&ca_keygrip, &ca_cert, &cn, &out_cert, &out_key),
        Commands::NodeCert {
            ca_keygrip,
            ca_cert,
            ssh_pubkey,
            cn,
            out,
        } => cmd_node_cert(&ca_keygrip, &ca_cert, &ssh_pubkey, &cn, &out),
        Commands::ComplexInit { dir } => cmd_complex_init(&dir),
        Commands::DerivePubkey { dir } => cmd_derive_pubkey(&dir),
        Commands::Verify { ca_cert, cert } => cmd_verify(&ca_cert, &cert),
    };

    if let Err(e) = result {
        eprintln!("error: {e}");
        std::process::exit(1);
    }
}

fn cmd_ca_init(keygrip: &str, cn: &str, out: &PathBuf) -> Result<(), String> {
    eprintln!("Creating CA certificate: CN={cn}");

    // Get the Ed25519 public key from gpg-agent via keygrip
    let pubkey_bytes = export_ed25519_pubkey_from_keygrip(keygrip)?;

    let spki = spki::SubjectPublicKeyInfoOwned {
        algorithm: spki::AlgorithmIdentifierOwned {
            oid: der::asn1::ObjectIdentifier::new_unwrap("1.3.101.112"),
            parameters: None,
        },
        subject_public_key: der::asn1::BitString::from_bytes(&pubkey_bytes)
            .map_err(|e| format!("BitString: {e}"))?,
    };

    let cert_der = x509::create_ca_cert(keygrip, cn, spki)?;
    let pem = x509::cert_to_pem(&cert_der)?;

    fs::write(out, &pem).map_err(|e| format!("write {}: {e}", out.display()))?;
    eprintln!("CA certificate written to {}", out.display());
    Ok(())
}

fn cmd_server_cert(
    ca_keygrip: &str,
    ca_cert_path: &PathBuf,
    cn: &str,
    out_cert: &PathBuf,
    out_key: &PathBuf,
) -> Result<(), String> {
    eprintln!("Creating server certificate: CN={cn}");

    let ca_pem = fs::read_to_string(ca_cert_path)
        .map_err(|e| format!("read CA cert: {e}"))?;
    let ca_der = x509::pem_to_cert_der(&ca_pem)?;

    let (cert_der, key_pem) = x509::create_server_cert(ca_keygrip, &ca_der, cn)?;
    let cert_pem = x509::cert_to_pem(&cert_der)?;

    fs::write(out_cert, &cert_pem)
        .map_err(|e| format!("write cert: {e}"))?;
    fs::write(out_key, &key_pem)
        .map_err(|e| format!("write key: {e}"))?;

    eprintln!("Server certificate: {}", out_cert.display());
    eprintln!("Server private key: {}", out_key.display());
    Ok(())
}

fn cmd_node_cert(
    ca_keygrip: &str,
    ca_cert_path: &PathBuf,
    ssh_pubkey_str: &str,
    cn: &str,
    out: &PathBuf,
) -> Result<(), String> {
    eprintln!("Creating node certificate: CN={cn}");

    let ca_pem = fs::read_to_string(ca_cert_path)
        .map_err(|e| format!("read CA cert: {e}"))?;
    let ca_der = x509::pem_to_cert_der(&ca_pem)?;

    let spki = ssh_key::ssh_pubkey_to_spki(ssh_pubkey_str)?;

    let cert_der = x509::create_node_cert(ca_keygrip, &ca_der, spki, cn)?;
    let pem = x509::cert_to_pem(&cert_der)?;

    fs::write(out, &pem).map_err(|e| format!("write {}: {e}", out.display()))?;
    eprintln!("Node certificate written to {}", out.display());
    Ok(())
}

fn cmd_complex_init(dir: &PathBuf) -> Result<(), String> {
    match complex::Complex::validate(dir)? {
        Some(existing) => {
            let ssh_pub = existing.ssh_pubkey_string();
            eprintln!("complex already exists at {}", dir.display());
            println!("{ssh_pub}");
        }
        None => {
            eprintln!("Generating node identity complex at {}", dir.display());
            let cx = complex::Complex::generate();
            cx.write(dir)?;
            let ssh_pub = cx.ssh_pubkey_string();
            eprintln!("Complex generated. SSH public key:");
            println!("{ssh_pub}");
        }
    }
    Ok(())
}

fn cmd_derive_pubkey(dir: &PathBuf) -> Result<(), String> {
    let cx = complex::Complex::load(dir)?;
    let ssh_pub = cx.ssh_pubkey_string();
    let ssh_path = dir.join("ssh.pub");
    complex::atomic_write(&ssh_path, ssh_pub.as_bytes(), 0o644)?;
    println!("{ssh_pub}");
    Ok(())
}

fn cmd_verify(ca_cert_path: &PathBuf, cert_path: &PathBuf) -> Result<(), String> {
    let ca_pem = fs::read_to_string(ca_cert_path)
        .map_err(|e| format!("read CA cert: {e}"))?;
    let cert_pem = fs::read_to_string(cert_path)
        .map_err(|e| format!("read cert: {e}"))?;

    let ca_der = x509::pem_to_cert_der(&ca_pem)?;
    let cert_der = x509::pem_to_cert_der(&cert_pem)?;

    x509::verify_cert_chain(&ca_der, &cert_der)?;
    eprintln!("OK: certificate chains to CA");
    Ok(())
}

/// Extract Ed25519 public key bytes from gpg-agent using READKEY.
fn export_ed25519_pubkey_from_keygrip(keygrip: &str) -> Result<Vec<u8>, String> {
    // Try gpg --export-ssh-key first, fall back to READKEY via agent
    let output = std::process::Command::new("gpg")
        .args(["--batch", "--export-ssh-key", &format!("{keygrip}!")])
        .output()
        .map_err(|e| format!("gpg --export-ssh-key: {e}"))?;

    if !output.status.success() {
        // Fallback: the keygrip might need to be looked up differently
        // Try using READKEY via agent
        return read_key_from_agent(keygrip);
    }

    let ssh_line = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if ssh_line.is_empty() {
        return read_key_from_agent(keygrip);
    }

    ssh_key::ssh_pubkey_raw_bytes(&ssh_line)
}

/// Read the public key from gpg-agent using the READKEY Assuan command.
fn read_key_from_agent(keygrip: &str) -> Result<Vec<u8>, String> {
    use std::io::{BufRead, BufReader, Write};
    use std::os::unix::net::UnixStream;

    let output = std::process::Command::new("gpgconf")
        .args(["--list-dirs", "agent-socket"])
        .output()
        .map_err(|e| format!("gpgconf: {e}"))?;

    let socket_path = String::from_utf8_lossy(&output.stdout).trim().to_string();
    let raw = UnixStream::connect(&socket_path)
        .map_err(|e| format!("connect: {e}"))?;
    let mut stream = BufReader::new(raw);

    let mut line = String::new();
    stream.read_line(&mut line).map_err(|e| format!("read greeting: {e}"))?;

    let cmd = format!("READKEY {keygrip}\n");
    stream.get_mut().write_all(cmd.as_bytes())
        .map_err(|e| format!("write READKEY: {e}"))?;
    stream.get_mut().flush().map_err(|e| format!("flush: {e}"))?;

    let mut data = Vec::new();
    loop {
        let mut resp = String::new();
        stream.read_line(&mut resp).map_err(|e| format!("read: {e}"))?;
        let resp = resp.trim_end();

        if resp.starts_with("D ") {
            let raw = &resp[2..];
            data.extend(decode_assuan(raw));
        } else if resp.starts_with("OK") {
            break;
        } else if resp.starts_with("ERR") {
            return Err(format!("READKEY failed: {resp}"));
        }
    }

    // Parse the S-expression to extract Ed25519 public key
    // Format: (10:public-key(3:ecc(5:curve7:Ed25519)(5:flags5:eddsa)(1:q32:<32 bytes>)))
    extract_sexp_q_value(&data)
        .ok_or_else(|| "could not extract public key from READKEY S-expression".to_string())
}

fn extract_sexp_q_value(data: &[u8]) -> Option<Vec<u8>> {
    // Look for (1:q followed by length:data
    let needle = b"(1:q";
    let pos = data.windows(needle.len()).position(|w| w == needle)?;
    let after = pos + needle.len();

    // Parse the length
    let mut i = after;
    let mut len_str = String::new();
    while i < data.len() && data[i].is_ascii_digit() {
        len_str.push(data[i] as char);
        i += 1;
    }
    if i >= data.len() || data[i] != b':' {
        return None;
    }
    i += 1;

    let len: usize = len_str.parse().ok()?;
    if i + len > data.len() {
        return None;
    }

    let mut key_data = data[i..i + len].to_vec();

    // Ed25519 public key is 32 bytes, but gpg may prefix with 0x40
    if key_data.len() == 33 && key_data[0] == 0x40 {
        key_data.remove(0);
    }

    Some(key_data)
}

fn decode_assuan(input: &str) -> Vec<u8> {
    let bytes = input.as_bytes();
    let mut result = Vec::with_capacity(bytes.len());
    let mut i = 0;
    while i < bytes.len() {
        if bytes[i] == b'%' && i + 2 < bytes.len() {
            if let Ok(byte) = u8::from_str_radix(
                &String::from_utf8_lossy(&bytes[i + 1..i + 3]),
                16,
            ) {
                result.push(byte);
                i += 3;
                continue;
            }
        }
        result.push(bytes[i]);
        i += 1;
    }
    result
}
