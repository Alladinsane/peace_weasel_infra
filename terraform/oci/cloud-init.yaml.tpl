#cloud-config
package_update: true
packages:
  - ca-certificates
  - curl
  - gnupg
  - git
  - ufw

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

  # --- Host firewall as a second layer behind Cloudflare / OCI security list ---
  - ufw allow 22/tcp
  - ufw allow 80/tcp
  - ufw allow 443/tcp
  - ufw --force enable

  # --- Pull the repo that defines both the dev and prod stacks ---
  - mkdir -p /opt/wp-stack
  - git clone --branch ${git_repo_branch} ${git_repo_url} /opt/wp-stack

  # Actual containers/secrets are populated by the deploy.yml GitHub Actions
  # workflow over SSH, separately for dev and for prod — cloud-init
  # deliberately embeds no secrets, so this file is safe in a public repo.

final_message: "wp-host base ready after $UPTIME seconds. Awaiting first deploy of dev and prod via GitHub Actions."
