#!/usr/bin/env bash
sudo apt update
# (Install Docker CE)
## Set up the repository:
### Install packages to allow apt to use a repository over HTTPS
sudo apt update && sudo apt install -y \
  apt-transport-https ca-certificates curl software-properties-common gnupg2

# Add Docker's official GPG key:
if [ -f /etc/debian_version ]; then
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
  sudo apt update
  sudo apt install docker-ce
  sudo usermod -aG docker ${USER}

else
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo \
    apt-key --keyring /etc/apt/trusted.gpg.d/docker.gpg add -
  # Add the Docker apt repository:
  sudo cat /etc/*release | grep VERSION_ID=\"20.04\"
  if [ "$?" -eq 0 ]; then
    sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu eoan stable"
  else
    sudo add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
  fi
  # Install Docker CE
  sudo apt update && sudo apt install -y \
    containerd.io=1.2.13-2 \
    docker-ce=5:19.03.11~3-0~ubuntu-$(lsb_release -cs) \
    docker-ce-cli=5:19.03.11~3-0~ubuntu-$(lsb_release -cs)
fi
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

#Create /etc/systemd/system/docker.service.d
#sudo mkdir -p /etc/systemd/system/docker.service.d

#Restart Docker
sudo systemctl daemon-reload
sudo systemctl restart docker

sudo systemctl enable docker

echo "Docker installed"
docker version