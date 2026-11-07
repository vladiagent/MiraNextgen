# Boot splash

MiraOS uses GRUB to launch Arch unified kernel images (UKIs). The splash is the bitmap embedded in each UKI by mkinitcpio. This option supports the standard Arch bitmap in existing mkinitcpio UKIs on a mounted EFI System Partition.

`boot/miraos-logo.png` is the original MiraOS artwork. `boot/miraos-splash.bmp` preserves its transparency over the UEFI stub's dark screen and matches the byte length of the Arch splash. The helper checks the EFI image format and existing splash, stages the new bytes, and retains the complete originals before writing. It updates the mkinitcpio preset to use the MiraOS bitmap for future builds.

## Check and install

From the repository directory, inspect the presets and confirm the existing images:

```sh
python -I boot/uki-splash.py check
sudo /usr/bin/python -I boot/uki-splash.py check
```

Select boot branding in the installer, or apply it independently:

```sh
sudo /usr/bin/python -I boot/uki-splash.py install
```

Review a refusal before making any boot changes. Secure Boot, signed images, TPM-bound boot policies and images with nonstandard splash settings need their existing boot build and signing workflow. On BIOS or GRUB-only setups, this option is unavailable. The change becomes visible on the next normal boot.

## Rollback

```sh
sudo /usr/bin/python -I boot/uki-splash.py uninstall
```

Rollback restores the original bitmap and preset, including after kernel updates that retained the MiraOS splash. The original files and the manifest are backed up under `/var/lib/miraos-dots/boot`. The uninstaller retains them under `/var/lib/miraos-dots/boot-rollback-*`.

If the presets or installed bitmap changed independently, review the differences before restoring anything. If the UKIs were also updated, rebuild with `mkinitcpio -P` after restoring the relevant splash option. An older UKI backup may contain an outdated kernel.

See the [systemd-stub manual](https://www.freedesktop.org/software/systemd/man/latest/systemd-stub.html) and [mkinitcpio manual](https://man.archlinux.org/man/mkinitcpio.8) for the image format and the `--splash` option.
