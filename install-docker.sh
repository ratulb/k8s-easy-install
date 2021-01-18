#!/usr/bin/env bash
sudo apt update
# (Install Docker CE)
## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS

sudo apt update && sudo apt install -y \
  apt-transport-https ca-certificates curl software-properties-common gnupg2

sudo apt-get remove -y docker docker-engine docker.io containerd runc
home_url=$(sudo cat /etc/*release | grep HOME_URL | cut -d'"' -f2)
if [[ "$home_url" = "https://www.ubuntu.com/" ]] || [[ "$home_url" = "http://www.ubuntu.com/" ]]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
  version_id=$(sudo cat /etc/*release | grep VERSION_ID | cut -d'"' -f2)
  if [[ "$version_id" =~ "20*" ]]; then
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu eoan stable"
  else
    sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  fi
fi

if [ "$home_url" = "https://www.debian.org/" ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
  sudo add-apt-repository \
    "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
fi

sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io
# Set up the Docker daemon
cat <<EOF | sudo tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
sudo usermod -aG docker ${USER}

#Restart Docker
sudo systemctl daemon-reload
sudo systemctl restart docker
sudo systemctl enable docker
echo "Docker installed"
docker version
