#!/usr/bin/env bash
. utils.sh
prnt "Installing kube-apiserver nginx load balancer on $loadbalancer"

install_nginx_from_official_repo() {
  sudo DEBIAN_FRONTEND=noninteractive apt update
  sudo DEBIAN_FRONTEND=noninteractive apt install -y curl ca-certificates gnupg
  sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y

  . /etc/os-release
  case "$ID" in
    ubuntu)
      nginx_repo_base=ubuntu
      case "$VERSION_CODENAME" in
        focal|jammy|noble|oracular|plucky|questing) nginx_distro=$VERSION_CODENAME ;;
        *) nginx_distro=noble ;;
      esac
      ;;
    debian)
      nginx_repo_base=debian
      case "$VERSION_CODENAME" in
        bullseye|bookworm|trixie) nginx_distro=$VERSION_CODENAME ;;
        *) nginx_distro=bookworm ;;
      esac
      ;;
    *)
      nginx_repo_base=debian
      nginx_distro=bookworm
      ;;
  esac

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://nginx.org/keys/nginx_signing.key \
    | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/nginx-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/$nginx_repo_base $nginx_distro nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list > /dev/null

  sudo DEBIAN_FRONTEND=noninteractive apt update
  sudo DEBIAN_FRONTEND=noninteractive apt install -y nginx
  sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y
  command -v nginx >/dev/null 2>&1 || { err "nginx installation failed on $loadbalancer"; return 1; }
  prnt "nginx has been installed on $loadbalancer"
}

if is_address_local $loadbalancer; then
  if [ -f /etc/apt/keyrings/nginx-archive-keyring.gpg ] \
     && [ -f /etc/apt/sources.list.d/nginx.list ] \
     && grep -q "nginx.org" /etc/apt/sources.list.d/nginx.list \
     && [ -x /usr/sbin/nginx ]; then
    prnt "nginx (official repo) is already installed"
  else
    install_nginx_from_official_repo
  fi
else
  _nginx_install_script=$(mktemp /tmp/install-nginx.XXXXXX)
  chmod 644 "$_nginx_install_script"
  cat > "$_nginx_install_script" <<'SCRIPT'
    if [ -f /etc/apt/keyrings/nginx-archive-keyring.gpg ] \
       && [ -f /etc/apt/sources.list.d/nginx.list ] \
       && grep -q "nginx.org" /etc/apt/sources.list.d/nginx.list \
       && [ -x /usr/sbin/nginx ]; then
      echo "nginx (official repo) is already installed"
      exit 0
    fi
    . /etc/os-release
    case "$ID" in
      ubuntu)
        nginx_repo_base=ubuntu
        case "$VERSION_CODENAME" in
          focal|jammy|noble|oracular|plucky|questing) nginx_distro=$VERSION_CODENAME ;;
          *) nginx_distro=noble ;;
        esac
        ;;
      debian)
        nginx_repo_base=debian
        case "$VERSION_CODENAME" in
          bullseye|bookworm|trixie) nginx_distro=$VERSION_CODENAME ;;
          *) nginx_distro=bookworm ;;
        esac
        ;;
      *)
        nginx_repo_base=debian
        nginx_distro=bookworm
        ;;
    esac
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://nginx.org/keys/nginx_signing.key \
      | sudo gpg --batch --yes --dearmor -o /etc/apt/keyrings/nginx-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/$nginx_repo_base $nginx_distro nginx" \
      | sudo tee /etc/apt/sources.list.d/nginx.list > /dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt update
    sudo DEBIAN_FRONTEND=noninteractive apt install -y nginx
    sudo DEBIAN_FRONTEND=noninteractive apt autoremove -y
    command -v nginx >/dev/null
SCRIPT
  if ! remote_script $loadbalancer "$_nginx_install_script"; then
    rm -f "$_nginx_install_script"
    err "Failed to install nginx on $loadbalancer"
    return 1
  fi
  rm -f "$_nginx_install_script"
  prnt "nginx has been installed on $loadbalancer"
fi
