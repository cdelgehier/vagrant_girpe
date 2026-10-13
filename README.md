# GIRPE2 Windows lab

Run the official [GIRPE2 application](https://www.fftt.com/deploiements/girpe-v2/)
in a Windows 11 ARM64 VM on Apple Silicon. This lab also checks desktop access,
application compatibility and document exchange with the host.

The pinned package is **GIRPE2 2.2.3**, published by FFTT on 19 May 2026.
Its portable Windows application is x64 and uses Windows ARM64 emulation.
The package includes the application runtime. The setup checks the archive's
SHA-256, copies the executable to `C:\Girpe` and creates a desktop shortcut.
It keeps Defender and the Windows certificate store settings.

## Prepare the box

Build and test the private Windows box with
[Image Factory](https://github.com/cdelgehier/image-factory/tree/main/targets/windows-11-arm64).
Follow that target's instructions to import it as
`image-factory/windows-11-arm64`. Windows images are not published in Factory
releases or catalogues.

The Factory build and guest tests must finish successfully before you import
the box. `task up` checks for the imported ARM64 box with the `libvirt` format
used by `vagrant-qemu`. If it is missing, the task stops with a setup message.

Install Vagrant, QEMU and `vagrant-qemu` 0.6.3. The VM uses four CPUs and
8 GiB of RAM. Install Task, uv and PowerShell to run the project checks:

```sh
brew install go-task uv qemu
brew install --cask powershell
vagrant plugin install vagrant-qemu --plugin-version 0.6.3
```

## Start and connect

From this repository:

```sh
task ci
task up
vagrant rdp
```

You can also connect with a Remote Desktop client to `127.0.0.1:13389`.
The initial account and password are `vagrant`. Use your changed password
if you changed it in the guest. WinRM follows `IMAGE_FACTORY_WINDOWS_PASSWORD`.
Desktop access uses Network Level Authentication. Host ports listen on loopback.
The guest keeps an English interface with French formats and keyboard settings.
Sign out and back in to apply user settings.

Open the GIRPE2 desktop shortcut. Sign in with your FFTT account when needed.
The automated checks do not sign in or send competition results.

## Keep your documents

Choose `C:\GirpeData` as the application's external backup folder. This folder
is available from the Mac through an authenticated SMB share:

```sh
open 'smb://127.0.0.1:1445/GIRPEData'
```

Use the guest's `vagrant` account and password when Finder asks. You can copy
files in both directions. Before replacing or destroying the VM, copy the
backup folder to a host folder and check that your saved files are there.
The share is on the guest disk; it is not a host shared folder.
The old `GIRPEclasseur` host folder is kept for existing files.

## Check the lab

```sh
task test:runtime
task halt
```

Runtime checks cover the installed version, ARM64 Windows, RDP negotiation,
a document round trip through encrypted SMB and an application window in the
interactive desktop. Sign in to the desktop before running them. Diagnostics
and the test report are saved in `reports/`. Tests remove their temporary file,
scheduled task and application process. They keep the VM and your documents.

For printing, first select Microsoft Print to PDF in Windows and save the file
in `C:\GirpeData`. You can then print it from macOS. A network printer can be
added in Windows by its IP address if it is reachable from the VM. Automatic
printer discovery and RDP printer redirection depend on the network and client;
they are not covered by the automated tests.

See the official [user manual](https://www.fftt.com/deploiements/girpe-v2/downloads/FFTT-Documentation%20Utilisateur-GirpeV2.pdf)
for application backups and offline use.
