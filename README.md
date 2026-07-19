# Devstack
## Installing Docker on RHEL-10
```bash

# Add the repo
sudo dnf config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo

# Update cache
sudo dnf makecache

# Install Docker
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

```
