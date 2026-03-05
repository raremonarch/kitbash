# Kitbash TODO

## Future Enhancements

---

### Uninstall Framework

#### Phase 3: `lib/uninstall.sh`

**Chosen design: Option 1 — inline `uninstall_<module>()` functions**

Each module that needs custom cleanup gets an `uninstall_<module>()` function appended
at the bottom of its own `.sh` file. The central `lib/uninstall.sh` framework:

1. Sources the target module file
2. Calls `uninstall_<module>()` if it exists (custom cleanup)
3. Falls back to generic DNF removal by parsing the `# Installs:` header if no function defined
4. Updates `~/.local/state/kitbash/state.json` to remove the module entry

**Key helpers to build in `lib/uninstall.sh`:**

- `get_module_installs <module_name>` — reads `# Installs:` header, strips annotations like
  `(optional, ...)`, `(binary: ...)`, `(AppImage: ...)`, `(systemd service: ...)`, returns
  space-separated list of bare package names suitable for `dnf remove`
- `uninstall_module <module_name>` — main entry point: sources module, dispatches

**State integration:** After uninstall, call `state_record_module <module> uninstalled` (or
remove the entry entirely). Requires adding an "uninstalled" status to `lib/state.sh`.

---

#### Modules requiring custom `uninstall_<module>()` functions

Each entry below describes exactly what the function must do.

**`awscli`** — Binary install

- Run `/usr/local/aws-cli/v2/current/bin/aws2/install --uninstall` if it exists
- Otherwise: `sudo rm -rf /usr/local/bin/aws /usr/local/aws-cli`
- Do NOT remove `~/.aws/` (user credentials/config)

**`claude_cli`** — Curl-piped installer, unknown install location

- Try: `which claude` to locate binary, then `sudo rm -f <path>`
- Try common locations: `~/.local/bin/claude`, `/usr/local/bin/claude`
- Warn user to check PATH if not found

**`cursor`** — Config-only, multiple files modified

- Remove `~/.config/environment.d/cursor.conf`
- Remove `XCURSOR_*` lines from `~/.profile`
- Remove cursor block from `~/.config/gtk-3.0/settings.ini`
- Remove `seat * xcursor_theme ...` line from Sway config (if present)
- Remove `cursor { ... }` block from Niri config (if present)
- Do NOT remove `breeze-cursor-theme` package (may be used elsewhere)
- Warn user to reload compositor

**`docker`** — Packages + repo + service + group

- `sudo systemctl stop docker && sudo systemctl disable docker`
- `sudo dnf remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`
- `sudo dnf config-manager --remove-repo docker-ce-stable` (or remove `/etc/yum.repos.d/docker-ce.repo`)
- `sudo gpasswd -d ${USER} docker`
- Optionally: `sudo groupdel docker` (warn user, don't auto-delete)
- Do NOT remove `/var/lib/docker/` (user images/containers) — warn user

**`dotfiles`** — DANGEROUS: warn-only, no auto-removal

- Print: "To remove: rm -rf $HOME/.git (this will destroy all version history)"
- Print: "Your dotfiles will remain on disk, but git tracking will be lost"
- Exit without making changes

**`dropbox`** — Tarball + CLI + user service

- `systemctl --user stop dropbox && systemctl --user disable dropbox`
- `rm -f ~/.config/systemd/user/dropbox.service`
- `systemctl --user daemon-reload`
- `rm -rf ~/.dropbox-dist`
- `rm -f ~/.local/bin/dropbox`
- Do NOT remove `~/.dropbox/` (user account data/cache) — warn user

**`easyeffects`** — Packages + service or autostart

- `systemctl --user stop easyeffects 2>/dev/null; systemctl --user disable easyeffects 2>/dev/null`
- `rm -f ~/.config/autostart/easyeffects-service.desktop`
- `sudo dnf remove -y easyeffects lsp-plugins-lv2`

**`editor`** — Config-only

- `rm -f ~/.config/environment.d/editor.conf`
- `git config --global --unset core.editor`
- `systemctl --user unset-environment EDITOR VISUAL`

**`google_chrome`** — Package + repo

- `sudo dnf remove -y google-chrome-stable`
- `sudo dnf config-manager --remove-repo google-chrome`
- Repo file is usually `/etc/yum.repos.d/google-chrome.repo`

**`greetd`** — DANGEROUS: changes system login manager, warn first

- Print warning: "This will restore SDDM as login manager. Requires reboot."
- Prompt for confirmation before proceeding
- `sudo systemctl disable greetd && sudo systemctl enable sddm`
- `sudo dnf remove -y greetd gtkgreet cage`
- `sudo rm -f /etc/greetd/config.toml`
- Do NOT remove `~/.config/gtkgreet/` (user config)

**`hyprland`** — Packages + COPR repo

- `sudo dnf remove -y hyprland hyprlock hypridle hyprpaper hyprland-plugin-hyprexpo`
- `sudo dnf copr disable -y solopasha/hyprland`
- Note: `hypridle`/`hyprlock` may be shared with `niri` module — check before removing

**`mounts`** — DANGEROUS: /etc/fstab edits, warn-only

- Print: "Automatic fstab cleanup is not supported to avoid data loss"
- Print each mount entry that was configured (read from state or kit.conf)
- Print instructions: "Manually remove entries from /etc/fstab and run: sudo systemctl daemon-reload"
- Do NOT modify /etc/fstab automatically

**`niri`** — Packages + COPR repo + user service

- `systemctl --user stop hypridle 2>/dev/null; systemctl --user disable hypridle 2>/dev/null`
- `sudo dnf remove -y niri hypridle hyprlock`
- `sudo dnf copr disable -y yalter/niri`
- Note: `hypridle`/`hyprlock` may be shared with `hyprland` module — check before removing

**`nordvpn`** — Curl-piped installer + service + group

- `sudo systemctl stop nordvpnd && sudo systemctl disable nordvpnd`
- Try official uninstaller first: `sudo dnf remove -y nordvpn`
- `sudo gpasswd -d ${USER} nordvpn`
- Do NOT remove `~/.config/nordvpn/` (user config)
- Warn: logout/login required after group change

**`obsidian`** — AppImage + desktop entry + icon

- `sudo rm -f /usr/local/bin/obsidian`
- `sudo rm -f /usr/share/applications/obsidian.desktop`
- `sudo rm -f /usr/share/icons/hicolor/512x512/apps/obsidian.png`
- `sudo update-desktop-database /usr/share/applications`
- Do NOT remove `fuse-libs` (may be used by other AppImages)
- Do NOT remove `~/.obsidian/` or vault directories (user data)

**`ollama`** — Tarball binary + system user + service

- `sudo systemctl stop ollama && sudo systemctl disable ollama`
- `sudo rm -f /etc/systemd/system/ollama.service`
- `sudo systemctl daemon-reload`
- `sudo rm -f /usr/bin/ollama`
- `sudo rm -rf /usr/lib/ollama`
- `sudo userdel -r ollama` (removes `/usr/share/ollama`)
- `sudo gpasswd -d ${USER} ollama 2>/dev/null`
- Do NOT remove `~/.ollama/` (user models) — warn user they can delete it

**`sddm`** — Config-only

- Restore `/etc/sddm.conf`: uncomment `DisplayServer=x11`, set `Current=` to empty or prior theme
- Note: sddm.sh only modifies if a custom theme exists; safe to revert

**`sudo_timeout`** — Config-only, single file

- `sudo rm -f /etc/sudoers.d/${USER}-timeout`
- `sudo -k` (reset sudo timestamp)

**`synology`** — Package + COPR repo

- `sudo dnf remove -y synology-drive-noextra`
- `sudo dnf copr disable -y emixampp/synology-drive`

**`terminal`** — Package + update-alternatives + XFCE config

- `sudo update-alternatives --remove x-terminal-emulator /usr/bin/${TERMINAL_APP}`
- Remove XFCE terminal setting from `~/.config/xfce4/helpers.rc` (if present)
- Optionally `sudo dnf remove -y <terminal>` — warn user, they may want to keep it

**`theme`** — Cloned installer + gsettings

- `rm -rf ~/.themes/Catppuccin-GTK-Dark ~/.local/share/themes/Catppuccin-GTK-Dark`
- `gsettings reset org.gnome.desktop.interface gtk-theme`
- `gsettings reset org.gnome.desktop.interface color-scheme`
- Do NOT remove `sassc`, `gtk-murrine-engine`, `gnome-themes-extra` (shared deps)

**`vscode`** — Repo-only (package installed separately)

- `sudo dnf remove -y code`
- `sudo rm -f /etc/yum.repos.d/vscode.repo`

**`wallpaper`** — DANGEROUS: edits multiple compositor configs, partial only

- Remove system files: `sudo rm -f /usr/share/backgrounds/wallpaper* /usr/share/backgrounds/default`
- Remove downloaded file: `rm -f ~/wallpaper.*`
- Print: "Wallpaper config is embedded in Sway, Hyprland, Niri, and SDDM configs"
- Print instructions for manually reverting each compositor config
- Do NOT auto-edit compositor config files

---

#### Modules with no custom function needed (generic DNF removal covers it)

These modules only do `dnf install`, so the framework's generic handler suffices.
The `# Installs:` header already has the correct package name(s).

- `copyq` → `sudo dnf remove -y copyq`
- `discord` → `sudo dnf remove -y discord` (do NOT remove RPM Fusion repos — shared with steam)
- `font` → nothing to remove (fonts live in `~/.local/share/fonts/`) — print location for user
- `gnome_boxes` → `sudo dnf remove -y gnome-boxes virt-manager`
- `hostname` → nothing (hostnamectl change is permanent, warn user)
- `imagemagick` → `sudo dnf remove -y ImageMagick`
- `jq` → `sudo dnf remove -y jq` (**warn: kitbash uses jq internally for state tracking**)
- `qpwgraph` → `sudo dnf remove -y qpwgraph`
- `steam` → `sudo dnf remove -y steam` (do NOT remove RPM Fusion repos — shared with discord)
- `zoom` → `sudo dnf remove -y zoom`

---

#### Shared resource protection rules for `lib/uninstall.sh`

Before removing any shared resource, check if other installed modules depend on it:

- **RPM Fusion repos**: only remove if neither `discord` nor `steam` are installed
- **`hypridle`/`hyprlock` packages**: shared by `niri` and `hyprland` — only remove if both are uninstalled
- **`fuse-libs`**: never auto-remove (used by system and other AppImages)
- **`jq`**: warn strongly — kitbash's own state tracking depends on it
- **Wayland dev libraries**: never auto-remove

---

- [ ] Phase 3: Build `lib/uninstall.sh` (see design above)
- [ ] Phase 4: Enhanced commands (`--list`, `--installed`, `--info`, `--uninstall`)

---

### System Improvements

- [ ] Pre-flight checks for desktop environment compatibility (Wayland/X11, compositor detection)
- [ ] Module version tracking and update detection
