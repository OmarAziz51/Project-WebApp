
# Find the catalog containing the Ubuntu vApp template
data "vcd_catalog" "ubuntu_catalog" {
  org  = "COT-1"
  name = "Eslam"
}

# Find the Ubuntu 22 template
data "vcd_catalog_vapp_template" "ubuntu" {
  org        = "COT-1"
  catalog_id = data.vcd_catalog.ubuntu_catalog.id
  name       = "Ubuntu-25-10-live-server"
}

# Create VMs inside the existing OM-Project01 vApp

######################omdb02#################################################
resource "vcd_vapp_vm" "omdb02" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "omdb02"
  computer_name = "omdb02"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048

  
  # Enable Customization
customization { 
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname omdb02
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.80 omdb02
    10.10.10.81 ommc02
    10.10.10.82 omrmq02
    10.10.10.83 omapp02
    10.10.10.84 omweb02
    HOSTS
      cat > /root/setup_db.sh <<'VPSETUP'
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    apt_get() { apt-get -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -y "$@"; }
    wait_net() { for i in $(seq 1 60); do curl -fsI -o /dev/null http://archive.ubuntu.com && return 0; sleep 5; done; echo "no internet"; return 1; }
    wait_port() { for i in $(seq 1 $(( $3 * 12 ))); do timeout 3 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && return 0; sleep 5; done; return 1; }

    DB_ROOT_PASS="admin123"
    DB_NAME="accounts"
    DB_USER="admin"
    DB_USER_PASS="admin123"
    MARIADB_VER="10.11"   # must be 10.x: Hibernate 4.3.11 fails with NullPointerException on MariaDB 11.8
    REPO_URL="https://github.com/hkhcoder/vprofile-project.git"

    echo "==> [1/7] network + update"
    wait_net
    apt_get update
    apt_get upgrade
    apt_get install git curl apt-transport-https ca-certificates

    echo "==> [2/7] MariaDB $${MARIADB_VER} repo + pinning"
    . /etc/os-release
    CODENAME="$VERSION_CODENAME"
    if ! curl -sfI "https://mirror.mariadb.org/repo/$${MARIADB_VER}/ubuntu/dists/$${CODENAME}/Release" >/dev/null; then
      echo "MariaDB repo does not support $${CODENAME}, falling back to noble"
      CODENAME="noble"
    fi
    mkdir -p /etc/apt/keyrings
    curl -fsSL -o /etc/apt/keyrings/mariadb-keyring.asc https://mariadb.org/mariadb_release_signing_key.asc
    cat > /etc/apt/sources.list.d/mariadb.sources <<EOF
    X-Repolib-Name: MariaDB
    Types: deb
    URIs: https://mirror.mariadb.org/repo/$${MARIADB_VER}/ubuntu
    Suites: $${CODENAME}
    Components: main
    Signed-By: /etc/apt/keyrings/mariadb-keyring.asc
    EOF
    cat > /etc/apt/preferences.d/mariadb-pin <<EOF
    Package: *
    Pin: origin mirror.mariadb.org
    Pin-Priority: 1001
    EOF
    apt_get update

    echo "==> [3/7] Install MariaDB"
    apt_get install mariadb-server
    systemctl enable --now mariadb
    mariadb --version

    echo "==> [4/7] Secure + create DB and user"
    if mariadb -uroot -p"$${DB_ROOT_PASS}" -e "SELECT 1" &>/dev/null; then
      MYSQL="mariadb -uroot -p$${DB_ROOT_PASS}"
    else
      MYSQL="mariadb -uroot"
    fi
    $MYSQL <<EOF
    ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('$${DB_ROOT_PASS}');
    DELETE FROM mysql.global_priv WHERE User='';
    DROP DATABASE IF EXISTS test;
    DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
    FLUSH PRIVILEGES;
    EOF
    MYSQL="mariadb -uroot -p$${DB_ROOT_PASS}"
    $MYSQL <<EOF
    CREATE DATABASE IF NOT EXISTS $${DB_NAME};
    CREATE USER IF NOT EXISTS '$${DB_USER}'@'%' IDENTIFIED BY '$${DB_USER_PASS}';
    ALTER USER '$${DB_USER}'@'%' IDENTIFIED BY '$${DB_USER_PASS}';
    GRANT ALL PRIVILEGES ON $${DB_NAME}.* TO '$${DB_USER}'@'%';
    FLUSH PRIVILEGES;
    EOF

    echo "==> [5/7] Load project data"
    cd /tmp
    [ -d vprofile-project ] || git clone -b main "$${REPO_URL}"
    TABLES=$($MYSQL -N -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$${DB_NAME}'")
    if [ "$TABLES" -eq 0 ]; then
      $MYSQL "$${DB_NAME}" < /tmp/vprofile-project/src/main/resources/db_backup.sql
    fi
    $MYSQL "$${DB_NAME}" -e "show tables;"

    echo "==> [6/7] Allow remote connections (last step, so the port opens only when data is ready)"
    mkdir -p /etc/mysql/mariadb.conf.d
    cat > /etc/mysql/mariadb.conf.d/99-remote.cnf <<EOF
    [mysqld]
    bind-address = 0.0.0.0
    EOF
    systemctl restart mariadb

    echo "==> [7/7] Firewall"
    ufw allow 22/tcp
    ufw allow 3306/tcp
    ufw --force enable
    ss -tlnp | grep 3306 || true
    echo "DONE: MariaDB ready"
    VPSETUP
      chmod +x /root/setup_db.sh
      # run in the background so guest customization does not wait for it
      nohup setsid /root/setup_db.sh > /var/log/vprofile-setup.log 2>&1 &
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.80"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################




######################ommc02#################################################
resource "vcd_vapp_vm" "ommc02" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "ommc02"
  computer_name = "ommc02"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048


  # Enable Customization
customization {
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname ommc02
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.80 omdb02
    10.10.10.81 ommc02
    10.10.10.82 omrmq02
    10.10.10.83 omapp02
    10.10.10.84 omweb02
    HOSTS
      cat > /root/setup_memcached.sh <<'VPSETUP'
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    apt_get() { apt-get -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -y "$@"; }
    wait_net() { for i in $(seq 1 60); do curl -fsI -o /dev/null http://archive.ubuntu.com && return 0; sleep 5; done; echo "no internet"; return 1; }
    wait_port() { for i in $(seq 1 $(( $3 * 12 ))); do timeout 3 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && return 0; sleep 5; done; return 1; }

    CONF="/etc/memcached.conf"
    TCP_PORT=11211
    UDP_PORT=11111

    echo "==> [1/5] network + update"
    wait_net
    apt_get update
    apt_get upgrade

    echo "==> [2/5] Install memcached"
    apt_get install memcached

    echo "==> [3/5] Configure (listen + ports)"
    if grep -q '^-l ' "$CONF"; then sed -i 's/^-l .*/-l 0.0.0.0/' "$CONF"; else echo "-l 0.0.0.0" >> "$CONF"; fi
    if grep -q '^-p ' "$CONF"; then sed -i "s/^-p .*/-p $${TCP_PORT}/" "$CONF"; else echo "-p $${TCP_PORT}" >> "$CONF"; fi
    if grep -q '^-U ' "$CONF"; then sed -i "s/^-U .*/-U $${UDP_PORT}/" "$CONF"; else echo "-U $${UDP_PORT}" >> "$CONF"; fi

    echo "==> [4/5] Start & enable"
    systemctl enable memcached
    systemctl restart memcached

    echo "==> [5/5] Firewall"
    ufw allow 22/tcp
    ufw allow $${TCP_PORT}/tcp
    ufw allow $${UDP_PORT}/udp
    ufw --force enable
    ss -tlnp | grep $${TCP_PORT} || true
    echo "DONE: Memcached ready"
    VPSETUP
      chmod +x /root/setup_memcached.sh
      # run in the background so guest customization does not wait for it
      nohup setsid /root/setup_memcached.sh > /var/log/vprofile-setup.log 2>&1 &
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.81"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################

######################omrmq02#################################################
resource "vcd_vapp_vm" "omrmq02" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "omrmq02"
  computer_name = "omrmq02"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048


  # Enable Customization
customization {
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname omrmq02
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.80 omdb02
    10.10.10.81 ommc02
    10.10.10.82 omrmq02
    10.10.10.83 omapp02
    10.10.10.84 omweb02
    HOSTS
      cat > /root/setup_rabbitmq.sh <<'VPSETUP'
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    apt_get() { apt-get -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -y "$@"; }
    wait_net() { for i in $(seq 1 60); do curl -fsI -o /dev/null http://archive.ubuntu.com && return 0; sleep 5; done; echo "no internet"; return 1; }
    wait_port() { for i in $(seq 1 $(( $3 * 12 ))); do timeout 3 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && return 0; sleep 5; done; return 1; }

    RMQ_USER="test"
    RMQ_PASS="test"
    CONF="/etc/rabbitmq/rabbitmq.conf"
    AMQP_PORT=5672

    echo "==> [1/6] network + update"
    wait_net
    apt_get update
    apt_get upgrade

    echo "==> [2/6] Install RabbitMQ"
    apt_get install wget curl rabbitmq-server
    systemctl enable --now rabbitmq-server
    rabbitmqctl await_startup

    echo "==> [3/6] Allow remote access (loopback_users)"
    mkdir -p /etc/rabbitmq
    touch "$CONF"
    if grep -q '^loopback_users' "$CONF"; then
      sed -i 's/^loopback_users.*/loopback_users = none/' "$CONF"
    else
      echo "loopback_users = none" >> "$CONF"
    fi

    echo "==> [4/6] Create user and permissions"
    if rabbitmqctl list_users | awk '{print $1}' | grep -qx "$${RMQ_USER}"; then
      rabbitmqctl change_password "$${RMQ_USER}" "$${RMQ_PASS}"
    else
      rabbitmqctl add_user "$${RMQ_USER}" "$${RMQ_PASS}"
    fi
    rabbitmqctl set_user_tags "$${RMQ_USER}" administrator
    rabbitmqctl set_permissions -p / "$${RMQ_USER}" ".*" ".*" ".*"

    echo "==> [5/6] Restart"
    systemctl restart rabbitmq-server
    rabbitmqctl await_startup

    echo "==> [6/6] Firewall"
    ufw allow 22/tcp
    ufw allow $${AMQP_PORT}/tcp
    ufw --force enable
    rabbitmqctl list_users
    echo "DONE: RabbitMQ ready"
    VPSETUP
      chmod +x /root/setup_rabbitmq.sh
      # run in the background so guest customization does not wait for it
      nohup setsid /root/setup_rabbitmq.sh > /var/log/vprofile-setup.log 2>&1 &
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.82"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################

######################omapp02#################################################
resource "vcd_vapp_vm" "omapp02" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "omapp02"
  computer_name = "omapp02"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048


  # Enable Customization
customization {
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname omapp02
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.80 omdb02
    10.10.10.81 ommc02
    10.10.10.82 omrmq02
    10.10.10.83 omapp02
    10.10.10.84 omweb02
    HOSTS
      cat > /root/setup_tomcat_app.sh <<'VPSETUP'
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    apt_get() { apt-get -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -y "$@"; }
    wait_net() { for i in $(seq 1 60); do curl -fsI -o /dev/null http://archive.ubuntu.com && return 0; sleep 5; done; echo "no internet"; return 1; }
    wait_port() { for i in $(seq 1 $(( $3 * 12 ))); do timeout 3 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && return 0; sleep 5; done; return 1; }

    DB_HOST="omdb02"
    MC_HOST="ommc02"
    RMQ_HOST="omrmq02"
    DB_USER="admin"; DB_PASS="admin123"
    RMQ_USER="test"; RMQ_PASS="test"
    MC_PORT=11211
    RMQ_PORT=5672
    TOMCAT_VER="9.0.75"
    REPO_URL="https://github.com/hkhcoder/vprofile-project.git"
    TOMCAT_HOME="/usr/local/tomcat"
    BUILD_DIR="/opt/vprofile-build"

    echo "==> [1/9] network + update"
    wait_net
    apt_get update
    apt_get upgrade

    echo "==> [2/9] Install Java 11, git, maven"
    apt_get install openjdk-11-jdk git maven wget curl
    JAVA_BIN=$(readlink -f "$(which java)")
    JAVA_HOME_DIR=$(dirname "$(dirname "$JAVA_BIN")")

    echo "==> [3/9] Tomcat $${TOMCAT_VER}"
    cd /tmp
    wget -q https://archive.apache.org/dist/tomcat/tomcat-9/v$${TOMCAT_VER}/bin/apache-tomcat-$${TOMCAT_VER}.tar.gz
    tar xzf apache-tomcat-$${TOMCAT_VER}.tar.gz
    id tomcat &>/dev/null || useradd --home-dir $${TOMCAT_HOME} --shell /usr/sbin/nologin tomcat
    mkdir -p $${TOMCAT_HOME}
    cp -r /tmp/apache-tomcat-$${TOMCAT_VER}/* $${TOMCAT_HOME}/
    chown -R tomcat:tomcat $${TOMCAT_HOME}

    echo "==> [4/9] systemd service"
    cat > /etc/systemd/system/tomcat.service <<EOF
    [Unit]
    Description=Tomcat
    After=network.target

    [Service]
    User=tomcat
    Group=tomcat
    WorkingDirectory=$${TOMCAT_HOME}
    Environment=JRE_HOME=$${JAVA_HOME_DIR}
    Environment=JAVA_HOME=$${JAVA_HOME_DIR}
    Environment=CATALINA_HOME=$${TOMCAT_HOME}
    Environment=CATALINA_BASE=$${TOMCAT_HOME}
    ExecStart=$${TOMCAT_HOME}/bin/catalina.sh run
    ExecStop=$${TOMCAT_HOME}/bin/shutdown.sh
    SyslogIdentifier=tomcat-%i

    [Install]
    WantedBy=multi-user.target
    EOF
    systemctl daemon-reload
    systemctl enable tomcat

    echo "==> [5/9] Firewall"
    ufw allow 22/tcp
    ufw allow 8080/tcp
    ufw --force enable

    echo "==> [6/9] Source + application.properties"
    rm -rf $${BUILD_DIR}
    git clone -b main "$${REPO_URL}" $${BUILD_DIR}
    PROPS="$${BUILD_DIR}/src/main/resources/application.properties"
    sed -i "s#jdbc:mysql://[^:/]*:3306#jdbc:mysql://$${DB_HOST}:3306#" "$PROPS"
    sed -i "s#^jdbc.username=.*#jdbc.username=$${DB_USER}#" "$PROPS"
    sed -i "s#^jdbc.password=.*#jdbc.password=$${DB_PASS}#" "$PROPS"
    sed -i "s#^memcached.active.host=.*#memcached.active.host=$${MC_HOST}#" "$PROPS"
    sed -i "s#^memcached.active.port=.*#memcached.active.port=$${MC_PORT}#" "$PROPS"
    sed -i "s#^memcached.standBy.host=.*#memcached.standBy.host=$${MC_HOST}#" "$PROPS"
    sed -i "s#^memcached.standBy.port=.*#memcached.standBy.port=$${MC_PORT}#" "$PROPS"
    sed -i "s#^rabbitmq.address=.*#rabbitmq.address=$${RMQ_HOST}#" "$PROPS"
    sed -i "s#^rabbitmq.port=.*#rabbitmq.port=$${RMQ_PORT}#" "$PROPS"
    sed -i "s#^rabbitmq.username=.*#rabbitmq.username=$${RMQ_USER}#" "$PROPS"
    sed -i "s#^rabbitmq.password=.*#rabbitmq.password=$${RMQ_PASS}#" "$PROPS"
    # Important: keep the elasticsearch properties, the code needs them or the app fails at startup
    grep -nE "jdbc.url|memcached|rabbitmq|elasticsearch" "$PROPS"

    echo "==> [7/9] Build"
    cd $${BUILD_DIR}
    mvn install -DskipTests
    ls -l target/*.war

    echo "==> [8/9] Wait for backends (DB / Memcached / RabbitMQ)"
    wait_port $${DB_HOST} 3306 40 || echo "WARN: DB not reachable yet"
    wait_port $${MC_HOST} $${MC_PORT} 40 || echo "WARN: Memcached not reachable yet"
    wait_port $${RMQ_HOST} $${RMQ_PORT} 40 || echo "WARN: RabbitMQ not reachable yet"
    sleep 60   # RabbitMQ opens its port before the user is created

    echo "==> [9/9] Deploy (with retry)"
    for attempt in 1 2 3; do
      systemctl stop tomcat || true
      rm -rf $${TOMCAT_HOME}/webapps/ROOT $${TOMCAT_HOME}/webapps/ROOT.war
      cp $${BUILD_DIR}/target/vprofile-v2.war $${TOMCAT_HOME}/webapps/ROOT.war
      chown -R tomcat:tomcat $${TOMCAT_HOME}/webapps
      systemctl start tomcat
      OK=no
      for i in $(seq 1 48); do
        sleep 5
        CODE=$(curl -s -o /dev/null -w "%%{http_code}" http://localhost:8080/ || true)
        if [ "$CODE" = "200" ] || [ "$CODE" = "302" ]; then OK=yes; break; fi
      done
      if [ "$OK" = "yes" ]; then echo "App is UP (HTTP $CODE) on attempt $attempt"; break; fi
      echo "App not ready (HTTP $CODE), retry $attempt"
      journalctl -u tomcat --no-pager -n 200 | grep -iE "SEVERE|Exception" | tail -n 10 || true
      sleep 60
    done
    echo "DONE: Tomcat app deployed"
    VPSETUP
      chmod +x /root/setup_tomcat_app.sh
      # run in the background so guest customization does not wait for it
      nohup setsid /root/setup_tomcat_app.sh > /var/log/vprofile-setup.log 2>&1 &
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.83"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################

######################omweb02#################################################
resource "vcd_vapp_vm" "omweb02" {
  org              = "COT-1"
  vdc              = "K8s"
  vapp_name        = "OM-Project01"
  name             = "omweb02"
  computer_name = "omweb02"
  vapp_template_id = data.vcd_catalog_vapp_template.ubuntu.id
  vm_name_in_template = "Ubuntu-25-10-l"

  # CPU: 2 sockets, 1 core per socket
  cpus      = 2
  cpu_cores = 1

  # Memory: 2 GB (MB)
  memory = 2048


  # Enable Customization
customization {
  force                      = false
  enabled                    = true
  allow_local_admin_password = true
  auto_generate_password     = false
  admin_password             = "4FrD&3d+u"
  initscript = <<-EOT
    #!/bin/bash
    if [ "$1" = "postcustomization" ]; then
      hostnamectl set-hostname omweb02
      cat >> /etc/hosts <<'HOSTS'
    10.10.10.80 omdb02
    10.10.10.81 ommc02
    10.10.10.82 omrmq02
    10.10.10.83 omapp02
    10.10.10.84 omweb02
    HOSTS
      cat > /root/setup_nginx.sh <<'VPSETUP'
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=a

    apt_get() { apt-get -o DPkg::Lock::Timeout=900 -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold -y "$@"; }
    wait_net() { for i in $(seq 1 60); do curl -fsI -o /dev/null http://archive.ubuntu.com && return 0; sleep 5; done; echo "no internet"; return 1; }
    wait_port() { for i in $(seq 1 $(( $3 * 12 ))); do timeout 3 bash -c "echo > /dev/tcp/$1/$2" 2>/dev/null && return 0; sleep 5; done; return 1; }

    APP_HOST="omapp02"
    APP_PORT=8080

    echo "==> [1/4] network + update"
    wait_net
    apt_get update
    apt_get upgrade

    echo "==> [2/4] Install nginx"
    apt_get install nginx curl

    echo "==> [3/4] vproapp config"
    cat > /etc/nginx/sites-available/vproapp <<EOF
    upstream vproapp {
        server $${APP_HOST}:$${APP_PORT};
    }

    server {
        listen 80;

        location / {
            proxy_pass http://vproapp;
        }
    }
    EOF
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/vproapp /etc/nginx/sites-enabled/vproapp
    nginx -t
    systemctl enable nginx
    systemctl restart nginx

    echo "==> [4/4] Firewall"
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw --force enable
    echo "DONE: nginx ready (returns 502 until the app on $${APP_HOST} is up)"
    VPSETUP
      chmod +x /root/setup_nginx.sh
      # run in the background so guest customization does not wait for it
      nohup setsid /root/setup_nginx.sh > /var/log/vprofile-setup.log 2>&1 &
    fi
  EOT

  }



  # Connect to the organization network named OM-Project01.
  # Use type = "vapp" instead if OM-Project01 is a vApp network.
  network {
    type               = "org"
    name               = "OM-Project01"
    ip_allocation_mode = "MANUAL"
    ip                 = "10.10.10.84"
    is_primary         = true
    connected          = true
  }

  power_on = true
}
##############################################################################





