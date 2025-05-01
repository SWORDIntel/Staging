# GParted Live NVMe Shrink Guide

**Author:** John  
**Date:** May 1, 2025

---

## Overview
This guide walks you through using **GParted Live**—a bootable, Linux‑based partition editor—to safely and fully shrink an NVMe system drive by moving all NTFS metadata (including the MFT) offline. This approach guarantees the tightest possible volume shrink before resizing in Windows.

## Prerequisites
- **Backup your data.** Always ensure you have a recent image or backup of your system.
- A **USB flash drive** (≥1 GB).
- **GParted Live ISO**, downloaded from https://gparted.org/download.php
- A USB‑flashing tool: **Rufus** (Windows) or **balenaEtcher** (cross‑platform).

## 1. Download and Prepare

1. **Download GParted Live ISO**:
   - Visit https://gparted.org/download.php
   - Select the latest stable version for your architecture (64‑bit recommended).
   - Save the `.iso` file to your local PC.

2. **Flash the ISO to USB**:
   - **Rufus (Windows):**
     1. Launch Rufus.
     2. Select your USB device.
     3. Choose the GParted `.iso` under **Boot selection**.
     4. Leave defaults (FAT32, GPT), click **Start**.
   - **balenaEtcher:**
     ```bash
     # On Linux/macOS:
     sudo balena-etcher-electron /path/to/gparted-live.iso /dev/sdX
     ```
   - Wait for flashing to finish, then safely eject the USB.

## 2. Boot into GParted Live

1. **Insert the USB drive** into your target machine.
2. **Reboot** and enter your firmware’s Boot Menu (usually F12, Esc, or F2).
3. **Disable Secure Boot** if prompted (GParted Live is signed, but some firmwares still warn).
4. **Select your USB device** to boot.

## 3. Initial GParted Settings

1. At the **GParted boot menu**, choose **`GParted Live (Default settings)`** and press Enter.
2. Accept default keyboard and locale prompts, or adjust if needed.
3. When prompted for the display settings, you can typically accept defaults.
4. **Wait** for the GParted GUI to appear.

## 4. Check and Unmount the Partition

1. In the top‑right dropdown, select your **NVMe device** (e.g. `/dev/nvme0n1`).
2. In the partition list, locate the **Windows system partition** (NTFS, usually `/dev/nvme0n1p1`).
3. If it’s mounted (lock icon), **right‑click → Unmount**.
4. **Right‑click → Check** to run `ntfsfix` and fix any minor errors.

## 5. Resize/Move the Partition

1. **Right‑click** the NTFS partition → **Resize/Move**.
2. Drag the **right slider** leftward to free the desired amount of space, or enter the new size manually in the **New size (MiB)** field.
3. Click **Resize/Move** to confirm.

## 6. Apply Pending Operations

1. Click the green **checkmark** (✔️) on the toolbar to **Apply** all changes.
2. GParted will queue and execute:
   - Unmount (if needed)
   - Filesystem check
   - Metadata relocation (MFT, $LogFile)
   - Partition resize
3. **Monitor** the progress bar—this can take several minutes on large NVMe drives.
4. Once complete, close the summary dialog.

## 7. Finalize and Reboot

1. Close GParted and choose **Reboot** from the menu.
2. Remove the USB drive when prompted.
3. Boot back into **Windows**.

## 8. Verify in Windows

1. **Open Disk Management** (Win+X → Disk Management).
2. Confirm the **C:** partition is now the new smaller size, with unallocated space following.
3. If needed, you can now create or extend other partitions into the freed space.

## 9. Re-enable Windows Features (Optional)

If you disabled paging or hibernation earlier, re-enable them:
```powershell
# Re-enable system‑managed pagefile:
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management `
    -Name PagingFiles -Value 'C:\pagefile.sys 0 0'
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management `
    -Name AutomaticManagedPagefile -Value 1
# Re-enable hibernation:
powercfg /h on
```

## Troubleshooting

- **Partition fails to unmount**: Use the top‑menu **Device → Unmount** for the entire disk, then retry.
- **Filesystem errors persist**: Rerun **Check** until there are no errors.
- **GParted doesn’t list NVMe**: Ensure your firmware/USB environment supports NVMe (most recent versions do).

---

**Next Steps**
1. Use **Disk Management** or `diskpart` to create/extend partitions in the freed space.  
2. Restore any advanced Windows features you disabled.  
3. Re-enable your regular defrag or optimization schedule as needed.

