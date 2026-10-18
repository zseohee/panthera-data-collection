# Panthera workflow: Mac for development, Ubuntu VM for hardware

The Panthera Python binding and motor libraries built in the VM are Linux
ELF files. Keep them and the virtual environment in Ubuntu. Work on source
files and inspect collected data on macOS. Run arm control and camera capture
in Ubuntu so the control and image streams can be recorded together.

## On the Mac: make a shared workspace

1. Create `~/PantheraWork` in Finder or Terminal:

   ```bash
   mkdir -p ~/PantheraWork/code ~/PantheraWork/data
   ```

2. Shut down the Ubuntu VM. In UTM, edit this VM and select the QEMU shared
   directory option **VirtFS** with `~/PantheraWork` as the shared directory.
   Keep USB sharing enabled. Start the VM again. UTM documents VirtFS for
   QEMU/Linux sharing; USB passthrough also requires the QEMU backend.

3. Edit code or analyze exported data from `~/PantheraWork` on macOS. Do not
   copy the VM's `.venvs/panthera` or compiled `.so` files to the Mac.

## In Ubuntu: mount and check the workspace

After setting the UTM shared directory, run in the Ubuntu terminal:

```bash
sudo mkdir -p /mnt/utm
sudo mount -t 9p -o trans=virtio,version=9p2000.L share /mnt/utm
bash ~/panthera_split_check.sh
```

The script is read-only. `/mnt/utm` should show as mounted. Try writing a
small file to `/mnt/utm/data` from your Ubuntu user account. If permission
is denied, see UTM's VirtFS ownership instructions; do not change ownership
of your entire Mac home directory.

Keep the SDK and Quest installation under `/home/seohee` in the VM. The
shared folder is for files you edit on Mac and for completed recordings. Copy
only the files you intend to use into the VM's source tree before running
them; use version control for larger code changes.

## At the robot: hardware stays in Ubuntu

1. In UTM's USB toolbar, attach the Panthera comm board, Quest headset, and
   USB camera to the VM. A Mac built-in camera may not be available to UTM.
2. Run `bash ~/panthera_split_check.sh` again. It should list arm serial
   devices and the camera when attached.
3. Activate the VM environment and follow the existing Panthera guide:

   ```bash
   source ~/.venvs/panthera/bin/activate
   export PANTHERA_SDK_DIR="$HOME/Panthera-HT_SDK/panthera_python"
   cd ~/QuestTelePanthera
   bash tools/scan_ports.sh
   lerobot-find-cameras opencv
   ```

4. Configure the actual live port, run the Quest dry run, then test recording
   with the arm secured and its emergency stop accessible. The Quest bridge
   records commanded joint trajectories as JSONL; a camera-inclusive
   LeRobot dataset still needs a compatible Panthera Quest teleoperator.
5. Stop recording cleanly before copying finished files into
   `/mnt/utm/data/`. They will then appear in `~/PantheraWork/data` on Mac.

This split does not make the Linux SDK executable on macOS. Hardware tests
must still run in the VM. Mac-side development and offline tests can use the
shared files without taking control of the arm's USB serial port.

UTM references:
- https://docs.getutm.app/guest-support/sharing/directory/
- https://docs.getutm.app/guest-support/linux/#virtfs
- https://docs.getutm.app/guest-support/sharing/usb/
