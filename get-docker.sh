#!/bin/bash -e

ARCH=$(uname -m)
DOCKER_DIR=/volume1/@docker

echo "Downloading latest docker for $ARCH"
PACKAGE=$(curl -s "https://download.docker.com/linux/static/stable/$ARCH/" | awk -F\" '/docker-[0-9]/ {print $2}' | sort | tail -1)
echo "Latest package: $PACKAGE"
curl "https://download.docker.com/linux/static/stable/$ARCH/$PACKAGE" | tar -xz -C /usr/local/bin --strip-components=1

echo "Creating docker working directory $DOCKER_DIR"
mkdir -p "$DOCKER_DIR"

echo "Creating docker.json config file"
mkdir -p /usr/local/etc/docker
cat <<EOT > /usr/local/etc/docker/docker.json
{
  "storage-driver": "vfs",
  "iptables": false,
  "bridge": "none",
  "data-root": "$DOCKER_DIR"
}
EOT

echo "Creating docker startup script"
cat <<'EOT' > /usr/local/etc/rc.d/docker.sh
#!/bin/sh
# Start docker daemon

NAME=dockerd
PIDFILE=/var/run/$NAME.pid
DAEMON_ARGS="--config-file=/usr/local/etc/docker/docker.json --pidfile=$PIDFILE"

case "$1" in
    start)
        echo "Starting docker daemon"
        /usr/local/bin/dockerd $DAEMON_ARGS &
        ;;
    stop)
        echo "Stopping docker daemon"
        kill $(cat $PIDFILE)
        ;;
    *)
        echo "Usage: "$1" {start|stop}"
        exit 1
esac
exit 0
EOT

chmod 755 /usr/local/etc/rc.d/docker.sh

echo "Creating docker group"
synogroup --get docker || synogroup --add docker root

echo "Installing docker compose"
COMPOSE_URL=$(curl -s "https://api.github.com/repos/docker/compose/releases/latest" | awk -F\" '/https.*linux-aarch64[^.]/ {print $4}')
sudo mkdir -p /usr/local/lib/docker/cli-plugins
curl -L --fail "$COMPOSE_URL" -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose


echo "Starting docker"
/usr/local/etc/rc.d/docker.sh start

echo "Done.  Please add your user to the docker group in the Synology GUI and reboot your NAS."
