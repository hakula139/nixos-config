# ==============================================================================
# SSH Public Keys
# ==============================================================================

{
  # User SSH keys (~/.ssh/id_ed25519.pub)
  users = {
    hakula-cloudcone = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqd9HS6uF0h0mXMbIwCv9yrkvvdl3o1wUgQWVkjKuiJ cloudcone";
    hakula-tencent = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICc3XQ37RuIqVgQYED0HDU3RVSACPHmr/JoE7w/cvJzu tencent";
  };

  # Server SSH host keys (/etc/ssh/ssh_host_ed25519_key.pub)
  hosts = {
    us-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7sPLIoCS4frp1la++4Iv2ws/3L0dRcRSnD5CNCP5s3";
    us-2 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPxT+47E+dG8+MClHeVb6zNhPcprRH76tOVlUMhrXmfM";
    # TODO: Add us-3 host key after initial deployment
    # us-3 = "ssh-ed25519 ...";
    sg-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN7u+0CKIQHDMQNF9L90xoMe9lhruFqYDG48Da7zlM8G";
  };

  # Workstation SSH keys (/Users/hakula/.ssh/id_ed25519.pub)
  workstations = {
    hakula-macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+FcR3wQnWYQm7Jhk5J+D9xBUj81Yv7HLRumCHg5ffn";
  };
}
