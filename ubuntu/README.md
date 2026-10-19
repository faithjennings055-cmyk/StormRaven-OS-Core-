# StormRaven OS — Ubuntu edition (amd64)

Single 1.4 GB ISO, split into 22 parts (GitHub file size limits).

Reassemble:

```
cat StormRavenOS-ubuntu-amd64.iso.part-* > StormRavenOS-ubuntu-amd64.iso
sha256sum -c SHA256SUMS.txt
```

Write to a USB stick with `dd` or balenaEtcher and boot. StormRaven kernel payload on an Ubuntu 24.04 base, gateway auto-starts on port 8787. Login: user / live.
