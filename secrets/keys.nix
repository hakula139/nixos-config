# ==================================================================================================
# SSH Public Keys
# ==================================================================================================

{
  # Builder SSH key (~/.ssh/builder/id_ed25519.pub)
  builder = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIUFhp4yJc8Mogop4/sy8SJ/3Li8sumpuETF7G8BPjCY builder";

  # User SSH keys (~/.ssh/<provider>/id_ed25519.pub)
  users = {
    cloudcone = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPqd9HS6uF0h0mXMbIwCv9yrkvvdl3o1wUgQWVkjKuiJ cloudcone";
    dmit = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDniOpCdWc/0ne5my9fUKmxkWH7IrAGALzbdc6T83rQi dmit";
  };

  # Server SSH host keys (/etc/ssh/ssh_host_ed25519_key.pub)
  hosts = {
    us-1 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM7sPLIoCS4frp1la++4Iv2ws/3L0dRcRSnD5CNCP5s3";
    us-4 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDJCY6UGyWXNDi+JXSXzsiVLOqMOQRnyfF3ZGRR9lGq4";
    devvm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMgylLKYgQj+SAzLNQSsJYWv4dabX33FmvvG/C2GcUxZ";
  };

  # Workstation SSH keys (~/.ssh/id_ed25519.pub)
  workstations = {
    macbook = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK+FcR3wQnWYQm7Jhk5J+D9xBUj81Yv7HLRumCHg5ffn";
    wsl = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIWfYOT8WdYxjgxLzxqVnCAlOweMjHKKQw3vgjsAvSCg";
  };
}
