# --- Install xcaddy from the official repository ---
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-xcaddy-archive-keyring.gpg

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-xcaddy.list

sudo apt update
sudo apt install -y xcaddy

# --- Create build workspace ---
mkdir -p /opt/caddy
cd /opt/caddy

# --- Build customized Caddy (NO sudo for build) ---
xcaddy build v2.10.0 \
  --with github.com/greenpau/caddy-security \
  --with github.com/darkweak/souin/plugins/caddy \
  --with github.com/mholt/caddy-l4 \
  --with github.com/abiosoft/caddy-exec \
  --with github.com/porech/caddy-maxmind-geolocation \
  --with github.com/caddyserver/ntlm-transport \
  --with github.com/imgk/caddy-trojan \
  --with github.com/chukmunnlee/caddy-openapi \
  --with github.com/hslatman/caddy-openapi-validator \
  --with github.com/mholt/caddy-grpc-web \
  --with github.com/greenpau/caddy-git \
  --with github.com/dunglas/vulcain/caddy \
  --with github.com/sjtug/caddy2-filter \
  --with github.com/mholt/caddy-webdav \
  --with github.com/aksdb/caddy-cgi/v2 \
  --output /usr/local/bin/caddy

# --- Verify ---
/usr/local/bin/caddy version
/usr/local/bin/caddy list-modules

