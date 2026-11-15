# Releasing with the script

`scripts/release.sh` publishes a device's newest build as a GitHub release, in the form the device's system updates look for. It does steps 3, 4 and 6 of [Releases](building.md#releases) in one go: it checks the image, signs it, writes its checksum and creates the release. The example is the Echo Spot. For another device, use its codename instead of `rook`.

## Once: a signing key

The device installs an update only if the zip's `.sig` matches the public key in its image. The images in this repository ship the public half of the upstream key, `common/ota/release-key.pem`, or `common/dot/ota/release-key.pem` on the Echo Dot. To publish releases that your devices install as updates, sign them with a key of your own:

```sh
mkdir -p ~/.config/biscuit-ota
openssl genrsa -out ~/.config/biscuit-ota/release-key.pem 3072
openssl rsa -in ~/.config/biscuit-ota/release-key.pem -pubout -out common/ota/release-key.pem
```

Commit the new public key. A device takes updates signed with your key only after it runs an image built with it, so install the first such image by hand from TWRP. Keep the private key safe and outside the repository. `BISCUIT_OTA_KEY` points the script at another file.

A device checks the upstream repository for releases. To check your fork instead, set this on the device once:

```sh
adb shell setprop persist.echo.ota.releases "https://api.github.com/repos/<owner>/lineageos-echo-kiosk-satellite/releases?per_page=100"
```

Use `persist.biscuit.ota.releases` on the Echo Dot.

## Each release

1. Rename `## Unreleased` in `CHANGELOG-rook.md` to the release, such as `## 2026.11.2 - 2026-11-15`. Commit and push.
2. Build from a clean output folder with `CLEAN=1 make rook` and wait for `#### build completed successfully`.
3. Run `make test`, then:

   ```sh
   make release DEVICE=rook
   ```

The script stops before it uploads anything if:

- the changelog still starts with `## Unreleased`,
- the checkout has uncommitted changes or HEAD is not on GitHub,
- the release already exists,
- the build is older than HEAD,
- `make check` fails, or the key does not match the public key in the repository.

It creates the release `rook-2026.11.2`, titled `Echo Spot (1st gen) 2026.11.2`, on origin's GitHub repository with:

- `lineageos-echo-kiosk-satellite-2026.11.2-rook.zip`,
- its `.sig` and its `.sha256`,
- notes made from the release's section of the changelog, with the file's checksum and build commit.

The files and the notes stay in `workspace/releases/rook-2026.11.2/`.

The release is a draft. No device installs a draft, so check it on GitHub first, then publish it:

```sh
gh release edit rook-2026.11.2 --draft=false
```

## Options

| Variable | Effect |
| --- | --- |
| `PUBLISH=1` | Publishes the release right away instead of as a draft |
| `NOTES=<file>` | Uses that file as the release notes instead of the changelog's section |
| `GH_REPO=<owner>/<repo>` | Creates the release there instead of on origin's repository |
| `BISCUIT_OTA_KEY=<file>` | The private key, `~/.config/biscuit-ota/release-key.pem` by default |
