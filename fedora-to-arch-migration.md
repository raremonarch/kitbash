# Fedora 42 → Arch Linux Migration Notes

> Research date: 2026-03-13
> Source system: Fedora 42 (current)
> Target system: Arch Linux (rolling release)

This document captures package availability and migration considerations for switching the current Fedora 42 setup to Arch Linux, with a focus on the Wayland/Niri desktop stack and all regularly used applications.

---

## TL;DR

The migration is **highly feasible**. The entire Wayland desktop stack (niri, hyprland, sway, hypridle, hyprlock, waybar, mako, etc.) is available in the official Arch `extra` repo. Nearly all apps are either in official repos or in the AUR. The main gaps:

- `google-chrome`, `zoom`, `nordvpn` → AUR only (all work fine)
- `visual-studio-code-bin` → AUR (or use the official `code` open-source build from AUR, or Flatpak)
- `~/.config/` dotfiles transfer directly — no changes needed

---

## Key Differences: Fedora vs Arch

| Concern | Fedora 42 | Arch Linux |
| --- | --- | --- |
| Package manager | `dnf` + RPM | `pacman` + `.pkg.tar.zst` |
| Third-party packages | COPR repos, RPMFusion | AUR (build from source via `makepkg`) |
| AUR helper | N/A | `yay` or `paru` (install manually) |
| SELinux | Enabled (enforcing) by default | Not included — kernel lacks SELinux support |
| Firewall | `firewalld` enabled by default | No firewall by default; install `firewalld` manually |
| Release model | 6-month cycle | Rolling release |
| Kernel | Patched Fedora kernel | Vanilla `linux` (or `linux-lts`) |
| Multilib (32-bit) | Enabled | Disabled by default — must uncomment `[multilib]` in `/etc/pacman.conf` (required for Steam) |
| Init system | systemd | systemd (identical — service files transfer) |
| Config locations | XDG (`~/.config/`) | XDG (`~/.config/`) — dotfiles transfer as-is |

---

## Package Availability

### Window Managers & Compositors

All in the official `extra` repo — no AUR needed.

| Package (Fedora) | Arch package | Repo |
| --- | --- | --- |
| `niri` | `niri` | extra |
| `hyprland` | `hyprland` | extra |
| `sway` | `sway` | extra |
| `swaylock` | `swaylock` | extra |
| `swayidle` | `swayidle` | extra |
| `swaybg` | `swaybg` | extra |
| `hyprlock` | `hyprlock` | extra |
| `hypridle` | `hypridle` | extra |

### Desktop Tooling

| Package (Fedora) | Arch package | Repo | Notes |
| --- | --- | --- | --- |
| `waybar` | `waybar` | extra | |
| `rofi-wayland` | `rofi` | extra | Arch `rofi` 2.0+ has native Wayland built in — the separate `rofi-wayland` fork is obsolete upstream |
| `mako` | `mako` | extra | |
| `wofi` | `wofi` | extra | |
| `wlsunset` | `wlsunset` | extra | |
| `greetd` | `greetd` | extra | |
| `gtkgreet` | `greetd-gtkgreet` | extra | Split package under greetd |
| `copyq` | `copyq` | extra | |
| `thunar` | `thunar` | extra | |
| `xarchiver` | `xarchiver` | extra | |

### Terminals

| Package (Fedora) | Arch package | Repo |
| --- | --- | --- |
| `alacritty` | `alacritty` | extra |
| `kitty` | `kitty` | extra |

### Browsers

| Package (Fedora) | Arch package | Repo | Notes |
| --- | --- | --- | --- |
| `firefox` | `firefox` | extra | |
| `google-chrome-stable` | `google-chrome` | AUR | Proprietary binary; also available as Flatpak |

### Development Tools

| Package (Fedora) | Arch package | Repo | Notes |
| --- | --- | --- | --- |
| `code` (VS Code) | `visual-studio-code-bin` | AUR | Full Microsoft build with marketplace; `code` (AUR) is the open-source OSS build without Microsoft branding — use `visual-studio-code-bin` for full extension marketplace access; Flatpak also available |
| `gh` | `github-cli` | extra | |
| `nodejs` | `nodejs` | extra | |
| `nodejs-npm` | `npm` | extra | |
| `docker-ce` | `docker` | extra | Arch packages Docker CE in official repos — no third-party Docker repo needed |
| `docker-compose-plugin` | `docker-compose` | extra | Plugin-style v2 compose |
| `obsidian` | `obsidian` | extra | In official extra repo since ~2024 |
| `awscli2` | `aws-cli-v2` | extra | Note: conflicts with v1 `aws-cli` — don't install both |

### Media

| Package (Fedora) | Arch package | Repo | Notes |
| --- | --- | --- | --- |
| `vlc` | `vlc` | extra | |
| `mpv` | `mpv` | extra | |
| `audacity` | `audacity` | extra | |
| `easyeffects` | `easyeffects` | extra | Requires PipeWire (Arch default) |
| `ghb` (HandBrake) | `handbrake` | extra | The `handbrake` package contains both `ghb` (GTK GUI) and `handbrake-cli` as split packages |

### Communication & Productivity

| Package (Fedora) | Arch package | Repo | Notes |
| --- | --- | --- | --- |
| `discord` | `discord` | extra | AUR alternative: `discord_arch_electron` uses system Electron (lighter) |
| `zoom` | `zoom` | AUR | Proprietary; also available as Flatpak; Wayland screen sharing works with some configuration |
| `remmina` | `remmina` | extra | |
| `freerdp-libs` | `freerdp` | extra | Install alongside remmina for RDP plugin support |
| `kdiff3` | `kdiff3` | extra | |
| `transmission` | `transmission-gtk` | extra | `transmission-gtk` (GUI) and `transmission-cli` (daemon+CLI) are split packages |
| `qbittorrent` | `qbittorrent` | extra | |

### Virtualization

| Package (Fedora) | Arch package | Repo | Notes |
| --- | --- | --- | --- |
| `virt-manager` | `virt-manager` | extra | |
| `qemu-kvm` + related | `qemu-system-x86` | extra | Or `qemu-full` for all targets; `qemu-base` for minimal |
| `libvirt` | `libvirt` | extra | Enable `libvirtd.service` after install |
| `gnome-boxes` | `gnome-boxes` | extra | Also available as Flatpak (Flatpak version is client-only, no bundled daemon) |

### System & Networking

| Package (Fedora) | Arch package | Repo | Notes |
| --- | --- | --- | --- |
| `nordvpn` | `nordvpn-bin` | AUR | Enable `nordvpnd.service`, add user to `nordvpn` group; install `wireguard-tools` for NordLynx mode |
| `steam` | `steam` | multilib | **Requires enabling `[multilib]` in `/etc/pacman.conf`** — uncomment the `[multilib]` section, then `pacman -Sy` |
| `flatpak` | `flatpak` | extra | |

---

## Migration Steps (High Level)

### 1. Before Leaving Fedora

```bash
# Export explicitly installed packages (for reference)
rpm -qa --queryformat '%{NAME}\n' | sort > ~/fedora-packages.txt

# Back up dotfiles (your ~/.config is the most important thing)
# If using a dotfiles repo, ensure it's fully committed and pushed
```

### 2. Arch Installation Essentials

Follow the [Arch Installation Guide](https://wiki.archlinux.org/title/Installation_guide). Key things to configure:

- Enable `[multilib]` in `/etc/pacman.conf` (needed for Steam)
- Install an AUR helper: `yay` or `paru`
- Install `firewalld` and enable it if you want equivalent Fedora defaults
- Install `base-devel` (needed to build AUR packages via `makepkg`)

### 3. Install AUR Helper

```bash
# After base Arch install, install paru or yay:
git clone https://aur.archlinux.org/paru.git
cd paru && makepkg -si
```

### 4. Restore Desktop Stack

```bash
# All official repo packages — one shot:
sudo pacman -S niri hyprland sway swaylock swayidle swaybg hyprlock hypridle \
  waybar rofi mako wofi wlsunset greetd greetd-gtkgreet copyq thunar xarchiver \
  alacritty kitty firefox \
  github-cli nodejs npm docker docker-compose obsidian aws-cli-v2 \
  vlc mpv audacity easyeffects handbrake \
  discord remmina freerdp kdiff3 transmission-gtk qbittorrent \
  virt-manager qemu-system-x86 libvirt gnome-boxes flatpak

# Enable multilib first, then:
sudo pacman -S steam

# AUR packages:
paru -S google-chrome visual-studio-code-bin zoom nordvpn-bin
```

### 5. Service Setup

```bash
# Docker
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# libvirt
sudo systemctl enable --now libvirtd

# NordVPN
sudo systemctl enable --now nordvpnd
sudo usermod -aG nordvpn $USER

# hypridle (same as Fedora — user service)
systemctl --user enable --now hypridle
```

### 6. Dotfiles

Your `~/.config/` directory transfers directly. No path changes needed. The only thing to verify:

- `rofi` config: Since Arch ships `rofi` 2.0+ (native Wayland), check if any config used `rofi-wayland`-specific flags — likely no changes needed
- `greetd` config: The package name for the GTK greeter is `greetd-gtkgreet` (same binary `gtkgreet`)

---

## Caveats & Known Issues

**NordVPN on Arch:**
DNS leaks can occur when not using `systemd-resolved`. Configure `systemd-resolved` and set `DNS=` in `/etc/systemd/resolved.conf` or let NordVPN manage DNS. Some users prefer using NordVPN with WireGuard/NordLynx directly via `wireguard-tools` without the daemon.

**Zoom Wayland screen sharing:**
Works, but may require setting `ENABLE_WAYLAND=1` environment variable or using the Wayland-native mode. Check the [Arch Wiki Zoom page](https://wiki.archlinux.org/title/Zoom_Meetings) for current workarounds.

**VS Code marketplace:**
The open-source `code` AUR build (OSS) can't access the Microsoft Extension Marketplace by default. For full marketplace access (including proprietary extensions like Copilot), use `visual-studio-code-bin`.

**SELinux:**
If any of your Docker containers, libvirt VMs, or services depend on SELinux labels or policies, these will not carry over. Arch has no SELinux. AppArmor is available (`apparmor` package) as an alternative MAC system, but requires kernel configuration and is not enabled by default.

**Rolling release risk:**
Arch updates continuously. Run `pacman -Syu` regularly. Occasionally an update may require manual intervention (e.g., config file changes, service restarts). Check the [Arch Linux news page](https://archlinux.org/news/) before major updates. The `informant` AUR package can alert you to news items that require action before upgrading.

**VirtualBox:**
Not listed above because Fedora's `virtualbox-guest-additions` suggests you may be running *inside* a VM, not hosting VMs via VirtualBox. If you run VirtualBox *as host*, install `virtualbox` from extra on Arch plus the matching `linux-headers` package.

---

## Summary Assessment

| Category | Confidence | Notes |
| --- | --- | --- |
| Wayland desktop stack | ✅ Excellent | Everything in official repos |
| Core productivity apps | ✅ Excellent | All available, most in official repos |
| Proprietary apps | ⚠️ Good | Chrome, Zoom, NordVPN via AUR — works well |
| VS Code | ⚠️ Good | AUR `visual-studio-code-bin` for full features |
| Docker / VMs | ✅ Excellent | Slightly simpler on Arch (no third-party repo needed) |
| SELinux | ❌ Not available | Not a concern unless you rely on it for security policy |
| Dotfiles / configs | ✅ Drop-in | `~/.config/` transfers directly |

**Overall: Migration is low-risk.** The Wayland compositor ecosystem arguably has better upstream support on Arch than on Fedora due to faster package updates. The main adjustments are operational (pacman instead of dnf, AUR for proprietary software) rather than functional.
