use ed25519_dalek::SigningKey;
use rand::rngs::OsRng;
use std::fs;
use std::io::Write;
use std::os::unix::fs::PermissionsExt;
use std::path::Path;
use std::time::SystemTime;

/// The complex: a node's root Ed25519 identity.
/// Generated once at first install, root-owned.
///
/// Layout:
///   <dir>/key.pem       — PKCS#8 Ed25519 private key (0600)
///   <dir>/ssh.pub       — OpenSSH public key
pub struct Complex {
    pub signing_key: SigningKey,
}

impl Complex {
    /// Generate a new complex (fresh Ed25519 keypair).
    pub fn generate() -> Self {
        let signing_key = SigningKey::generate(&mut OsRng);
        Self { signing_key }
    }

    /// Load an existing complex from its directory.
    pub fn load(dir: &Path) -> Result<Self, String> {
        let key_path = dir.join("key.pem");
        let pem = fs::read_to_string(&key_path)
            .map_err(|e| format!("read {}: {e}", key_path.display()))?;

        let (label, der) = pem_rfc7468::decode_vec(pem.as_bytes())
            .map_err(|e| format!("decode PEM: {e}"))?;
        if label != "PRIVATE KEY" {
            return Err(format!("expected PRIVATE KEY label, got: {label}"));
        }

        let secret_bytes = extract_ed25519_private_from_pkcs8(&der)?;
        let signing_key = SigningKey::from_bytes(&secret_bytes);
        Ok(Self { signing_key })
    }

    /// Write the complex to a directory. Atomic writes with restrictive permissions.
    pub fn write(&self, dir: &Path) -> Result<(), String> {
        fs::create_dir_all(dir)
            .map_err(|e| format!("mkdir {}: {e}", dir.display()))?;
        fs::set_permissions(dir, fs::Permissions::from_mode(0o700))
            .map_err(|e| format!("chmod {}: {e}", dir.display()))?;

        // Write PKCS#8 private key (atomic)
        let pkcs8_der = encode_ed25519_pkcs8(&self.signing_key.to_bytes());
        let key_pem = pem_rfc7468::encode_string(
            "PRIVATE KEY",
            pem_rfc7468::LineEnding::LF,
            &pkcs8_der,
        ).map_err(|e| format!("PEM encode: {e}"))?;

        let key_path = dir.join("key.pem");
        atomic_write(&key_path, key_pem.as_bytes(), 0o600)?;

        // Write SSH public key (atomic)
        let ssh_pub = self.ssh_pubkey_string();
        let ssh_path = dir.join("ssh.pub");
        atomic_write(&ssh_path, ssh_pub.as_bytes(), 0o644)?;

        Ok(())
    }

    /// Validate an existing complex. Returns:
    /// - Ok(Some(cx)) if key exists and parses correctly
    /// - Ok(None) if no key exists or key was corrupt (corrupt key renamed aside)
    /// - Err only on I/O failure during rename
    pub fn validate(dir: &Path) -> Result<Option<Self>, String> {
        let key_path = dir.join("key.pem");
        if !key_path.exists() {
            return Ok(None);
        }
        match Self::load(dir) {
            Ok(cx) => Ok(Some(cx)),
            Err(e) => {
                let ts = SystemTime::now()
                    .duration_since(SystemTime::UNIX_EPOCH)
                    .unwrap_or_default()
                    .as_secs();
                let broken = dir.join(format!("key.pem.broken.{ts}"));
                fs::rename(&key_path, &broken).map_err(|re| {
                    format!(
                        "corrupt key at {} (error: {e}), rename to {} failed: {re}",
                        key_path.display(),
                        broken.display()
                    )
                })?;
                eprintln!(
                    "warning: corrupt key renamed to {} (parse error: {e})",
                    broken.display()
                );
                let ssh_path = dir.join("ssh.pub");
                if ssh_path.exists() {
                    let ssh_broken = dir.join(format!("ssh.pub.broken.{ts}"));
                    let _ = fs::rename(&ssh_path, &ssh_broken);
                }
                Ok(None)
            }
        }
    }

    /// Get the Ed25519 public key bytes (32 bytes).
    pub fn public_key_bytes(&self) -> [u8; 32] {
        self.signing_key.verifying_key().to_bytes()
    }

    /// Format the public key as an OpenSSH string.
    pub fn ssh_pubkey_string(&self) -> String {
        let vk = self.signing_key.verifying_key();
        let pk_bytes = vk.as_bytes();

        // OpenSSH Ed25519 wire format:
        //   u32 len "ssh-ed25519"
        //   "ssh-ed25519"
        //   u32 len <32 bytes>
        //   <32 bytes>
        let key_type = b"ssh-ed25519";
        let mut blob = Vec::new();
        push_ssh_string(&mut blob, key_type);
        push_ssh_string(&mut blob, pk_bytes);

        let encoded = base64ct::Base64::encode_string(&blob);
        format!("ssh-ed25519 {encoded} complex")
    }
}

use base64ct::Encoding;

/// Write contents to path atomically: write to .tmp, sync, chmod, rename.
pub fn atomic_write(path: &Path, contents: &[u8], mode: u32) -> Result<(), String> {
    let tmp = path.with_extension("tmp");
    let mut f = fs::File::create(&tmp)
        .map_err(|e| format!("create {}: {e}", tmp.display()))?;
    f.write_all(contents)
        .map_err(|e| format!("write {}: {e}", tmp.display()))?;
    f.sync_all()
        .map_err(|e| format!("sync {}: {e}", tmp.display()))?;
    drop(f);
    fs::set_permissions(&tmp, fs::Permissions::from_mode(mode))
        .map_err(|e| format!("chmod {}: {e}", tmp.display()))?;
    fs::rename(&tmp, path)
        .map_err(|e| format!("rename {} -> {}: {e}", tmp.display(), path.display()))?;
    Ok(())
}

fn push_ssh_string(buf: &mut Vec<u8>, data: &[u8]) {
    buf.extend_from_slice(&(data.len() as u32).to_be_bytes());
    buf.extend_from_slice(data);
}

/// Encode an Ed25519 private key as PKCS#8 DER.
/// SEQUENCE {
///   INTEGER 0
///   SEQUENCE { OID 1.3.101.112 }
///   OCTET STRING { OCTET STRING { <32 bytes> } }
/// }
fn encode_ed25519_pkcs8(private_bytes: &[u8; 32]) -> Vec<u8> {
    let oid = &[0x06, 0x03, 0x2B, 0x65, 0x70]; // OID 1.3.101.112

    // Inner OCTET STRING wrapping the 32-byte key
    let inner_octet = {
        let mut v = vec![0x04, 0x20]; // OCTET STRING, length 32
        v.extend_from_slice(private_bytes);
        v
    };

    // Outer OCTET STRING wrapping inner
    let outer_octet = {
        let mut v = vec![0x04];
        push_der_length(&mut v, inner_octet.len());
        v.extend(&inner_octet);
        v
    };

    // AlgorithmIdentifier SEQUENCE
    let alg_id = {
        let mut v = vec![0x30];
        push_der_length(&mut v, oid.len());
        v.extend_from_slice(oid);
        v
    };

    // version INTEGER 0
    let version = &[0x02, 0x01, 0x00];

    // Total inner length
    let inner_len = version.len() + alg_id.len() + outer_octet.len();

    let mut result = vec![0x30];
    push_der_length(&mut result, inner_len);
    result.extend_from_slice(version);
    result.extend(&alg_id);
    result.extend(&outer_octet);
    result
}

/// Extract 32-byte Ed25519 private key from PKCS#8 DER.
fn extract_ed25519_private_from_pkcs8(der: &[u8]) -> Result<[u8; 32], String> {
    // Walk the DER structure to find the nested OCTET STRING containing 32 bytes.
    // Structure: SEQUENCE { INTEGER, SEQUENCE { OID }, OCTET STRING { OCTET STRING { key } } }
    // The key is in the innermost OCTET STRING.

    // Find the pattern: 04 20 <32 bytes> (inner OCTET STRING)
    for i in 0..der.len().saturating_sub(33) {
        if der[i] == 0x04 && der[i + 1] == 0x20 {
            let key_slice = &der[i + 2..i + 34];
            let mut key = [0u8; 32];
            key.copy_from_slice(key_slice);
            return Ok(key);
        }
    }
    Err("could not find Ed25519 private key in PKCS#8 structure".into())
}

fn push_der_length(buf: &mut Vec<u8>, len: usize) {
    if len < 0x80 {
        buf.push(len as u8);
    } else if len < 0x100 {
        buf.push(0x81);
        buf.push(len as u8);
    } else {
        buf.push(0x82);
        buf.push((len >> 8) as u8);
        buf.push(len as u8);
    }
}
