# Validation

- The installer ran in temporary home directories with a space in the path and package installation simulated. Tested dry run, declining a plan, backup, repeat install, preservation of generated palettes and wallpaper choices, restoration of prior files and desktop preferences, and rollback after a real Hyprland configuration error.
- Hyprland accepted the exported Lua configuration. The binding and startup checks found no duplicates. The Arch package database resolved the packages in `scripts/packages.conf`.
- A private Wayland session loaded the Quickshell bar, launcher and workspace overview. Verified native notification activation, history, DND and urgent notifications, the secure lock surface, tray Quit actions, clipboard capture and restore, and emoji search and copy. A private PipeWire sink verified the 2% volume change and mouse slider.
- The wallpaper picker started with an empty library and applied two test images using awww. Matugen produced distinct accents and preserved the #282828 background. Running GTK 3, GTK 4 and Qt 6 probes received both accents in the same processes. The Qt 5 bridge compiled from the included source. The accent portal activated through D-Bus and returned the configured named accent.
- The SDDM helper passed installation, repeat installation, conflict handling, and removal in a test filesystem. A temporary Qt 6 greeter loaded the exported theme with a published wallpaper and palette.
- The boot helper validated and updated the existing Arch and LTS UKIs. An isolated systemd-stub fixture verified the EFI images and byte-for-byte rollback. The firmware display is visible at the next normal boot.

The isolated desktop tests used the installed Hyprland and Quickshell versions. A fresh bare-metal installation and hardware Wi-Fi/Bluetooth pairing were outside the test environment. The exported desktop has brightness shortcuts. The visual volume overlay is the OSD present in the recovered configuration.
