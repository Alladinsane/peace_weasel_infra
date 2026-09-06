#cloud-config
package_update: true
packages:
  - ca-certificates
  - curl
  - gnupg
  - git
  - ufw
  - cron

runcmd:
  # --- Docker Engine + Compose plugin ---
  - install -m 0755 -d /etc/apt/keyrings
  - curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  - chmod a+r /etc/apt/keyrings/docker.asc
  - >
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc]
    https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo $VERSION_CODENAME) stable"
    | tee /etc/apt/sources.list.d/docker.list > /dev/null
  - apt-get update
  - apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  - usermod -aG docker ubuntu

  # --- Small swap cushion and disk-pressure warning ---
  - >
    sh -c 'if ! swapon --show | grep -q /swapfile; then
    fallocate -l 2G /swapfile && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile;
    grep -q "^/swapfile " /etc/fstab || echo "/swapfile none swap sw 0 0" >> /etc/fstab;
    fi'
  - >
    sh -c 'cat > /usr/local/sbin/wp-disk-check <<"SCRIPT"
    #!/bin/sh
    usage=$(df -P / | awk "NR==2 {gsub(/%/, \"\", \$5); print \$5}")
    if [ "$usage" -ge 85 ]; then logger -t wp-disk-check "root filesystem is $${usage}% full"; fi
    SCRIPT
    chmod 0755 /usr/local/sbin/wp-disk-check'
  - >
    sh -c 'cat > /etc/cron.daily/wp-disk-check <<"SCRIPT"
    #!/bin/sh
    exec /usr/local/sbin/wp-disk-check
    SCRIPT
    chmod 0755 /etc/cron.daily/wp-disk-check'

  # --- Host firewall as a second layer behind Cloudflare / OCI security list ---
  - ufw allow from ${admin_ssh_cidr} to any port 22 proto tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable

  # --- Pull the repo that defines the environment running on this host ---
  - mkdir -p /opt/wp-stack
  - git clone --branch ${git_repo_branch} ${git_repo_url} /opt/wp-stack

  # Actual containers/secrets are populated by the deploy.yml GitHub Actions
  # workflow over SSH for this host — cloud-init
  # deliberately embeds no secrets, so this file is safe in a public repo.

final_message: "wp-host base ready after $UPTIME seconds. Awaiting first deploy of dev and prod via GitHub Actions."
