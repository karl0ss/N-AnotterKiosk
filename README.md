N-AnotterKiosk (Not-AnotterKiosk)
=================================

### I have hacked this about alot from the main branch, mainly Raspberry Pi changes

- Removed x86 support
- Added scheduled screen on/off
- Added scheduled chrome page refresh
- Rpi3 Overclock settings
- Disabled KMS driver for HW screen rotation (screen rotated portrait by default)

### Overview

Another kiosk browser OS? Yes, this one is a little bit opinionated :)

The author ran several similar setups in production for years and has seen a lot of problems and strange failure modes.
This project aims to solve a lot of those (at least for the author), it might also be useful for others :)

#### Key features

- [Images built via CI](https://github.com/Manawyrm/N-AnotterKiosk/blob/main/.github/workflows/main.yml)
- WiFi connection support
- Raspberry Pi (Arm64) compatibility
- [USB flash drive, USB SSD, etc. compatible](#how-to-use)
- aarch64 mode for Raspberry Pis (_significant_ performance improvements over armv7/32bit ARM)
- Read-only filesystem handling (no more broken SD cards)
- Configurable cache clear functionality
- [HTTP watchdog (website needs to send heartbeat messages via XHR/AJAX to localhost)](#http-watchdog-functionality)
- Force specific resolution (1080p on 4k screens, broken EDID, etc.)
- Hard NTP handling (will wait for NTP at boot)
- SSH support
- VNC support
- SSH tunneling support (for remote-access without port-forwarding, etc.)
- Basic API for Rpi Actions
- Hyperion-NG support for ambilight

#### Planned features:

- Raspberry Pi PXE/network boot support
- Network connectivity watchdog (configurable ping, etc. timeout)
- Automatic reboot at specified time

#### Security considerations:

- Autossh does not check SSH host keys. This is okay-ish as long as the target server only allows tunneling, nothing else.
- nginx/PHP are allowed to use sudo/NOPASSWD (because it needs to query the VideoCore, manage service, etc.), more priviledge seperation would be nice
- due to the skeleton mechanism, the system has some ... creative permissions. some cleanup required.

### How-To Use

Like any other Raspberry Pi image: download the current .img file from the [Releases](https://github.com/Manawyrm/N-AnotterKiosk/releases) page and flash it to a storage device of your choice.
SD cards, USB flash drives, USB SSDs, SATA SSDs, NVMe SSDs are all good options.
You can use a tool like the [Raspberry Pi Imager](https://www.raspberrypi.com/software/), [BalenaEtcher](https://etcher.balena.io/), [Win32DiskImager](https://sourceforge.net/projects/win32diskimager/) or plain "dd" on \*nix-like systems.
When using the latter two, make sure to extract the .gz compression first (using a tool like 7zip).

After flashing, re-plug the storage device and open the FAT32 partition.
Open the [`kioskbrowser.ini`](https://github.com/Manawyrm/N-AnotterKiosk/blob/main/kiosk_skeleton/boot/kioskbrowser.ini) file in a text editor and change everything to your needs.
More complex WiFi setups (like WPA2-Enterprise) can be configured by creating a wpa_supplicant.conf.
Adding your own SSH keys can be done by creating a authorized_keys file.
If you want to use the autossh tunneling features, copy an SSH private key as either "id_rsa" or "id_ed25519".

### HTTP watchdog functionality

Browsers are complex, networks are unstable and software can be buggy.
In order to get the highest reliability possible, self-hosted websites can be modified to include a heartbeat/watchdog functionality.
This works by requesting a certain http-endpoint from the website at some interval.
If your page is being reloaded often (like with a <meta refresh=-header), you can just load the heartbeat-URL as an image:

```html
<img src="http://localhost/heartbeat.php" style="display: none;">
```

If your page stays on one page for a long time (or is just a single-page application), you might want to use AJAX requests to send a heartbeat:

```html
<script>
const req = new XMLHttpRequest();
setInterval(function() {
	req.open("GET", "http://localhost/heartbeat.php");
	req.send();
}, 2000);
</script>
```

Whenever the heartbeat stops (for whatever reason), the device will first restart the X11 environment (browser, window manager, etc.) and later (if it hasn't recovered) the whole system by rebooting.

### API

Lightweight HTTP API for controlling and monitoring a Raspberry Pi-based kiosk system. It exposes several endpoints that allow you to query system status, control the display, refresh the screen, and reboot the device — all protected by an API key.

API key will be loaded from `/boot/kioskbrowser.ini`

```ini
[api]
key = "My Key"
```

#### Endpoints

All requests must include a key query parameter matching the API key from the INI file.

`GET /script.php?action=status&key=YOUR_API_KEY`
Returns system status:

```json
{
  "temperature": "temp=48.0'C",
  "voltage": "volt=1.2000V",
  "throttled": "throttled=0x0",
  "heartbeat": "2025-06-09 14:33:12"
 }
```

`GET /script.php?action=screen_off&key=YOUR_API_KEY`
Turns off the screen.

`GET /script.php?action=screen_on&key=YOUR_API_KEY`
Turns on the screen.

`GET /script.php?action=screen_refresh&key=YOUR_API_KEY`
Starts the screen-refresh.service to refresh the screen.

`GET /script.php?action=reboot&key=YOUR_API_KEY`
Reboots the Raspberry Pi.

### Hyperion-NG

The kiosk now supports Hyperion-NG for ambilight control.
Manage Hyperion via its web interface, which is available on port 8090.

### Inspiration / Other Kiosk-OSes:

- https://github.com/jareware/chilipie-kiosk/
- https://github.com/guysoft/FullPageOS
