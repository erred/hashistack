resource "null_resource" "medea" {
  connection {
    host        = "medea.seankhliao.com"
    private_key = file(pathexpand("~/.ssh/id_ed25519"))
    agent       = false
  }

  provisioner "remote-exec" {
    inline = [
      "rm /etc/sysctl.d/* || true",
      "rm /etc/ssh/ssh_host_{dsa,rsa,ecdsa}_key* || true",
      "pacman -Rns --noconfirm btrfs-progs gptfdisk haveged xfsprogs wget vim net-tools cronie || true",
      "pacman -Syu --noconfirm neovim zip unzip",
      "systemctl enable --now systemd-timesyncd",
    ]
  }
  provisioner "file" {
    destination = "/root/.ssh/authorized_keys"
    content     = <<-EOT
      ${file(pathexpand("~/.ssh/id_ed25519.pub"))}
      ${file(pathexpand("~/.ssh/id_ed25519_sk.pub"))}
      ${file(pathexpand("~/.ssh/id_ecdsa_sk.pub"))}
    EOT
  }
  provisioner "file" {
    destination = "/etc/sysctl.d/30-ipforward.conf"
    content     = <<-EOT
      net.ipv4.ip_forward=1
      net.ipv4.conf.lxc*.rp_filter=0
      net.ipv6.conf.default.forwarding=1
      net.ipv6.conf.all.forwarding=1
    EOT
  }
  provisioner "file" {
    destination = "/etc/modules-load.d/br_netfilter.conf"
    content     = "br_netfilter"
  }
  provisioner "file" {
    destination = "/etc/systemd/network/40-wg0.netdev"
    content     = <<-EOT
      # WireGuard

      [NetDev]
      Name = wg0
      Kind = wireguard

      [WireGuard]
      PrivateKey = 8N8HPJ7Q0w1V+MSuLXXCsY/ny9OAWf0IVTLCX04xi14=
      # PublicKey = lombY0b15giOmoM9t0xBi+UgVkZDoOKDaEV9+ONwH1U=
      ListenPort = 51820

      # eevee
      [WireGuardPeer]
      PublicKey = YvSLDXl3NX1ySTX2C8D72+fCVBcqSs+fmAX3uySCDAQ=
      AllowedIPs = 192.168.100.13/32

      # pixel 3
      [WireGuardPeer]
      PublicKey = 3xpGlOORQb9/yg545KX+odrup3YaslxO9ie+ztJ3Y3E=
      AllowedIPs = 192.168.100.3/32

      # arch
      [WireGuardPeer]
      PublicKey = Lr17jGvc7uwjn9LNRR+IkCkjuP8nkHTOMHbVV+onMn0=
      AllowedIPs = 192.168.100.1/24
      Endpoint = 34.90.235.32:51820
    EOT
  }
  provisioner "file" {
    destination = "/etc/systemd/network/41-wg0.network"
    content     = <<-EOT
      [Match]
      Name = wg0

      [Network]
      Address = 192.168.100.2/24
    EOT
  }
}
