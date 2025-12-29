# ==============================================================================
# SSH Public Keys
# ==============================================================================

{
  # User SSH keys (~/.ssh/id_ed25519.pub)
  users = {
    hakula = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqd9HS6uF0h0mXMbIwCv9yrkvvdl3o1wUgQWVkjKuiJ";
  };

  # Server SSH host keys (/etc/ssh/ssh_host_ed25519_key.pub)
  hosts = {
    us-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7sPLIoCS4frp1la++4Iv2ws/3L0dRcRSnD5CNCP5s3";
    us-2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPxT+47E+dG8+MClHeVb6zNhPcprRH76tOVlUMhrXmfM";
  };
}
