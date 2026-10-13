Vagrant.configure("2") do |config|
  config.vm.box = "image-factory/windows-11-arm64"
  config.vm.box_architecture = "arm64"
  config.vm.box_check_update = false
  config.vm.hostname = "girpe-lab"
  # Keep later Vagrant commands connected to this VM after a restart.
  config.vm.network "forwarded_port", guest: 5986, host: 55986,
    host_ip: "127.0.0.1", id: "winrm-ssl", auto_correct: false

  # The box supplies HTTPS WinRM. Desktop and file access are enabled here.
  config.vm.network "forwarded_port", guest: 3389, host: 13389,
    host_ip: "127.0.0.1", id: "rdp", auto_correct: false
  config.vm.network "forwarded_port", guest: 445, host: 1445,
    host_ip: "127.0.0.1", id: "documents", auto_correct: false
  config.rdp.username = "vagrant"

  config.vm.provider "qemu" do |qemu|
    qemu.arch = "aarch64"
    qemu.machine = "virt,accel=hvf"
    qemu.cpu = "host"
    qemu.smp = "4"
    qemu.memory = "8G"
    # QEMU reserves an SSH port even when Windows uses WinRM.
    qemu.ssh_auto_correct = true
    qemu.drive_interface = "none"
    qemu.net_device = "virtio-net-pci"
    # ARM Windows needs both its NVMe disk and the UEFI framebuffer.
    qemu.extra_qemu_args = ["-device", "ramfb",
      "-device", "nvme,drive=disk0,serial=image-factory"]
  end

  # WinRM already has admin rights; use it without a second scheduled logon.
  config.vm.provision "shell", privileged: false,
    inline: "New-Item -ItemType Directory -Path C:/GirpeProvision -Force | Out-Null"
  config.vm.provision "file", source: "provision/source.json",
    destination: "C:/GirpeProvision/source.json"
  config.vm.provision "file", source: "provision/prepare-package.ps1",
    destination: "C:/GirpeProvision/prepare-package.ps1"
  config.vm.provision "shell", path: "provision/install_girpe.ps1", privileged: false
  config.vm.provision "shell", path: "provision/set_french_locale.ps1", privileged: false
  config.vm.provision "shell", path: "provision/desktop.ps1", privileged: false
end
