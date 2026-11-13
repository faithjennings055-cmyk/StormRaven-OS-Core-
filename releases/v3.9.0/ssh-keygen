#!/usr/bin/env python3
"""
StormRaven OS — Pure-Python OpenSSH Ed25519 Key Generator & ssh-keygen Polyfill
Works in rootless iOS sandboxes (DevBox /sandbox $, a-Shell, iSH) without openssh-client installed.
"""
import base64, hashlib, os, struct, sys

q = 2**255 - 19

def inv(z):
    return pow(z, q - 2, q)

d = -121665 * inv(121666) % q
I = pow(2, (q - 1) // 4, q)

def xrecover(y):
    xx = (y * y - 1) * inv(d * y * y + 1)
    x = pow(xx, (q + 3) // 8, q)
    if (x * x - xx) % q != 0:
        x = (x * I) % q
    if x % 2 != 0:
        x = q - x
    return x

By = 4 * inv(5) % q
Bx = xrecover(By)
B = (Bx % q, By % q, 1, (Bx * By) % q)

def edwards_add(P, Q):
    x1, y1, z1, t1 = P
    x2, y2, z2, t2 = Q
    a = (y1 - x1) * (y2 - x2) % q
    b_ = (y1 + x1) * (y2 + x2) % q
    c = t1 * 2 * d * t2 % q
    dd = z1 * 2 * z2 % q
    e = b_ - a
    f = dd - c
    g = dd + c
    h = b_ + a
    return (e * f % q, g * h % q, f * g % q, e * h % q)

def scalarmult(P, e):
    Q = (0, 1, 1, 0)
    addend = P
    while e > 0:
        if e & 1:
            Q = edwards_add(Q, addend)
        addend = edwards_add(addend, addend)
        e >>= 1
    return Q

def encodepoint(P):
    x, y, z, _ = P
    zi = inv(z)
    x = (x * zi) % q
    y = (y * zi) % q
    bits = [(y >> i) & 1 for i in range(255)] + [x & 1]
    return bytes(sum(bits[i * 8 + j] << j for j in range(8)) for i in range(32))

def publickey(seed):
    h = hashlib.sha512(seed).digest()
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8
    a |= 1 << 254
    return encodepoint(scalarmult(B, a))

def ssh_str(data):
    if isinstance(data, str):
        data = data.encode("utf-8")
    return struct.pack(">I", len(data)) + data

def main():
    args = sys.argv[1:]
    home = os.environ.get("HOME") or "/sandbox"
    if not os.path.isdir(home):
        home = os.getcwd()
    out_file = os.path.join(home, ".ssh", "id_ed25519")
    comment = "faith@stormraven-ios"
    list_fp = False

    i = 0
    while i < len(args):
        a = args[i]
        if a == "-f" and i + 1 < len(args):
            out_file = args[i + 1]
            i += 2
        elif a == "-C" and i + 1 < len(args):
            comment = args[i + 1]
            i += 2
        elif a in ("-t", "-N", "-b") and i + 1 < len(args):
            i += 2
        elif a in ("-l", "-lf", "-fl"):
            list_fp = True
            if a in ("-lf", "-fl") and i + 1 < len(args):
                out_file = args[i + 1]
                i += 2
            else:
                i += 1
        else:
            i += 1

    if list_fp:
        pub_path = out_file if out_file.endswith(".pub") else (out_file + ".pub" if os.path.exists(out_file + ".pub") else out_file)
        with open(pub_path, "r") as f:
            parts = f.read().strip().split()
        raw = base64.b64decode(parts[1])
        fp = base64.b64encode(hashlib.sha256(raw).digest()).decode("ascii").rstrip("=")
        c = parts[2] if len(parts) > 2 else ""
        print(f"256 SHA256:{fp} {c} (ED25519)")
        return

    os.makedirs(os.path.dirname(os.path.abspath(out_file)), exist_ok=True)
    seed = os.urandom(32)
    pub = publickey(seed)
    pub_blob = ssh_str("ssh-ed25519") + ssh_str(pub)
    pub_line = f"ssh-ed25519 {base64.b64encode(pub_blob).decode('ascii')} {comment}\n"

    check = os.urandom(4)
    priv_inner = (
        check + check +
        ssh_str("ssh-ed25519") +
        ssh_str(pub) +
        ssh_str(seed + pub) +
        ssh_str(comment)
    )
    pad_len = (8 - (len(priv_inner) % 8)) % 8
    priv_inner += bytes(range(1, pad_len + 1))

    openssh_bin = (
        b"openssh-key-v1\x00" +
        ssh_str("none") +
        ssh_str("none") +
        ssh_str(b"") +
        struct.pack(">I", 1) +
        ssh_str(pub_blob) +
        ssh_str(priv_inner)
    )
    b64_body = base64.b64encode(openssh_bin).decode("ascii")
    lines = [b64_body[j:j+70] for j in range(0, len(b64_body), 70)]
    priv_pem = "-----BEGIN OPENSSH PRIVATE KEY-----\n" + "\n".join(lines) + "\n-----END OPENSSH PRIVATE KEY-----\n"

    with open(out_file, "w") as f:
        f.write(priv_pem)
    try:
        os.chmod(out_file, 0o600)
    except OSError:
        pass
    with open(out_file + ".pub", "w") as f:
        f.write(pub_line)

    fp = base64.b64encode(hashlib.sha256(pub_blob).digest()).decode("ascii").rstrip("=")
    print(f"Generating public/private ed25519 key pair.")
    print(f"Your identification has been saved in {out_file}")
    print(f"Your public key has been saved in {out_file}.pub")
    print(f"The key fingerprint is:\nSHA256:{fp} {comment}")

if __name__ == "__main__":
    main()
