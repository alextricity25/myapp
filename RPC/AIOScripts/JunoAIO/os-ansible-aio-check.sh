#!/usr/bin/env bash
# Copyright 2014, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
set -e -u -v -x

FROZEN_REPO_URL=${FROZEN_REPO_URL:-"http://mirror.rackspace.com/rackspaceprivatecloud"}
MAX_RETRIES=${MAX_RETRIES:-5}
ADMIN_PASSWORD=${ADMIN_PASSWORD:-"secrete"}
DEPLOY_SWIFT=${DEPLOY_SWIFT:-"no"}

# update the package cache and install required packages
apt-get update
apt-get install -y python-dev \
                   python2.7 \
                   build-essential \
                   curl \
                   git-core \
                   ipython \
                   tmux \
                   vim \
                   vlan \
                   bridge-utils \
                   lvm2 \
                   xfsprogs \
                   linux-image-extra-$(uname -r)

# Flush all the iptables rules set by openstack-infra
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT

# Ensure that sshd permits root login, or ansible won't be able to connect
if grep "^PermitRootLogin" /etc/ssh/sshd_config > /dev/null; then
  sed -i 's/^PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
else
  echo 'PermitRootLogin yes' >> /etc/ssh/sshd_config
fi

function key_create(){
  ssh-keygen -t rsa -f /root/.ssh/id_rsa -N ''
}

# Used to retry process that may fail due to random issues.
function successerator() {
  set +e
  RETRY=0
  # Set the initial return value to failure
  false

  while [ $? -ne 0 -a ${RETRY} -lt ${MAX_RETRIES} ];do
    RETRY=$((${RETRY}+1))
    $@
  done

  if [ ${RETRY} -eq ${MAX_RETRIES} ];then
    echo "Hit maximum number of retries, giving up..."
    exit 1
  fi
  set -e
}

function install_bits() {
  successerator ansible-playbook -e @/etc/rpc_deploy/user_variables.yml \
                                 playbooks/$@
}

function loopback_create() {
  LOOP_FILENAME=${1}
  LOOP_FILESIZE=${2}
  if ! losetup -a | grep "(${LOOP_FILENAME})$" > /dev/null; then
    LOOP_DEVICE=$(losetup -f)
    dd if=/dev/zero of=${LOOP_FILENAME} bs=1 count=0 seek=${LOOP_FILESIZE}
    losetup ${LOOP_DEVICE} ${LOOP_FILENAME}
  fi
}

# ensure that the current kernel can support vxlan
if ! modprobe vxlan; then
  MINIMUM_KERNEL_VERSION=$(awk '/required_kernel/ {print $2}' rpc_deployment/inventory/group_vars/all.yml)
  echo "A minimum kernel version of ${MINIMUM_KERNEL_VERSION} is required for vxlan support."
  echo "This build will not work without it."
  exit 1
fi

# create /opt if it doesn't already exist
if [ ! -d "/opt" ];then
  mkdir /opt
fi

# create /etc/rc.local if it doesn't already exist
if [ ! -f "/etc/rc.local" ];then
  touch /etc/rc.local
  chmod +x /etc/rc.local
fi

# Make the system key used for bootstrapping self
if [ ! -d /root/.ssh ];then
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
fi
pushd /root/.ssh/
  if [ ! -f "id_rsa" ];then
      key_create
  fi

  if [ ! -f "id_rsa.pub" ];then
    rm "id_rsa"
    key_create
  fi

  KEYENTRY=$(cat id_rsa.pub)
  if [ ! "$(grep \"$KEYENTRY\" authorized_keys)" ];then
      echo "$KEYENTRY" | tee -a authorized_keys
  fi
popd

# build the loopback drive for swap to use
if [ ! "$(swapon -s | grep -v Filename)" ]; then
  dd if=/dev/zero of=/opt/swap.img bs=512M count=1
  mkswap /opt/swap.img
  echo '/opt/swap.img none swap loop 0 0' >> /etc/fstab
  swapon -a
fi

# build the loopback drive for cinder to use
CINDER="cinder.img"
loopback_create /opt/${CINDER} 1000G
CINDER_DEVICE=$(losetup -a | awk -F: "/${CINDER}/ {print \$1}")
if ! pvs ${CINDER_DEVICE} > /dev/null; then
  pvcreate ${CINDER_DEVICE}
  pvscan
fi
if ! vgs cinder-volumes > /dev/null; then
  vgcreate cinder-volumes ${CINDER_DEVICE}
fi

# ensure that the cinder loopback is enabled after reboot
if ! grep ${CINDER} /etc/rc.local; then
  sed -i "\$i losetup \$(losetup -f) /opt/${CINDER}" /etc/rc.local
fi

if [ "${DEPLOY_SWIFT}" == "yes" ]; then
  # build the loopback drives for swift to use
  for SWIFT in swift1.img swift2.img swift3.img; do
    loopback_create /opt/${SWIFT} 1000G
    SWIFT_DEVICE=$(losetup -a | awk -F: "/${SWIFT}/ {print \$1}")
    if ! grep "${SWIFT}" /etc/fstab > /dev/null; then
      echo "/opt/${SWIFT} /srv/${SWIFT} xfs loop,noatime,nodiratime,nobarrier,logbufs=8 0 0" >> /etc/fstab
    fi
    if ! grep "${SWIFT}" /proc/mounts > /dev/null; then
      mkfs.xfs -f ${SWIFT_DEVICE}
      mkdir -p /srv/${SWIFT}
      mount /srv/${SWIFT}
    fi
  done
fi

# Copy the gate's repo to the expected location
mkdir -p /opt/ansible-lxc-rpc
cp -R * /opt/ansible-lxc-rpc

pushd /opt/ansible-lxc-rpc
  # Copy the base etc files
  if [ -d "/etc/rpc_deploy" ];then
    rm -rf "/etc/rpc_deploy"
  fi
  cp -R /opt/ansible-lxc-rpc/etc/rpc_deploy /etc/
  # Install pip
  curl ${FROZEN_REPO_URL}/downloads/get-pip.py | python
  # Install requirements
  pip install -r /opt/ansible-lxc-rpc/requirements.txt
  # Generate the passwords
  /opt/ansible-lxc-rpc/scripts/pw-token-gen.py --file /etc/rpc_deploy/user_variables.yml
popd

# change the generated passwords for the OpenStack (admin) and Kibana (kibana) accounts
sed -i "s/keystone_auth_admin_password:.*/keystone_auth_admin_password: ${ADMIN_PASSWORD}/" /etc/rpc_deploy/user_variables.yml
sed -i "s/kibana_password:.*/kibana_password: ${ADMIN_PASSWORD}/" /etc/rpc_deploy/user_variables.yml

if [ "${DEPLOY_SWIFT}" == "yes" ]; then
  # ensure that glance is configured to use swift
  sed -i "s/glance_default_store:.*/glance_default_store: swift/" /etc/rpc_deploy/user_variables.yml
  sed -i "s/glance_swift_store_auth_address:.*/glance_swift_store_auth_address: '{{ auth_identity_uri }}'/" /etc/rpc_deploy/user_variables.yml
  sed -i "s/glance_swift_store_container:.*/glance_swift_store_container: glance_images/" /etc/rpc_deploy/user_variables.yml
  sed -i "s/glance_swift_store_key:.*/glance_swift_store_key: '{{ glance_service_password }}'/" /etc/rpc_deploy/user_variables.yml
  sed -i "s/glance_swift_store_region:.*/glance_swift_store_region: RegionOne/" /etc/rpc_deploy/user_variables.yml
  sed -i "s/glance_swift_store_user:.*/glance_swift_store_user: 'service:glance'/" /etc/rpc_deploy/user_variables.yml
fi

# build the required user configuration
cat > /etc/rpc_deploy/rpc_user_config.yml <<EOF
---
environment_version: $(md5sum /etc/rpc_deploy/rpc_environment.yml | awk '{print $1}')
cidr_networks:
  container: 172.16.236.0/22
  tunnel: 172.16.240.0/22
used_ips:
  - 172.16.236.1,172.16.236.50
  - 172.16.236.100,172.16.236.150
  - 172.16.240.100,172.16.240.150
  - 172.16.244.1,172.16.244.50
global_overrides:
  rpc_repo_url: ${FROZEN_REPO_URL}
  internal_lb_vip_address: 10.127.83.3
  external_lb_vip_address: $(ip -o -4 addr show dev em1 | awk -F '[ /]+' '/global/ {print $4}')
  tunnel_bridge: "br-vlan"
  management_bridge: "br-mgmt"
infra_hosts:
  aio1:
    ip: 172.16.236.100
compute_hosts:
  aio1:
    ip: 172.16.236.100
storage_hosts:
  aio1:
    ip: 172.16.236.100
    container_vars:
      cinder_backends:
        limit_container_types: cinder_volume
        lvm:
          volume_group: cinder-volumes
          volume_driver: cinder.volume.drivers.lvm.LVMISCSIDriver
          volume_backend_name: LVM_iSCSI
log_hosts:
  aio1:
    ip: 172.16.236.100
network_hosts:
  aio1:
    ip: 172.16.236.100
haproxy_hosts:
  aio1:
    ip: 172.16.236.100
EOF

cat > /etc/rpc_deploy/conf.d/provider_networks.yml <<EOF
---
global_overrides:
  provider_networks:
    - network:
        container_bridge: "br-mgmt"
        container_interface: "eth1"
        ip_from_q: "container"
        type: "raw"
        group_binds:
          - all_containers
          - hosts
    - network:
        container_bridge: "br-vlan"
        container_interface: "eth11"
        ip_from_q: "tunnel"
        type: "vxlan"
        range: "1:1000"
        net_name: "vxlan"
        group_binds:
          - neutron_linuxbridge_agent
    - network:
        container_bridge: "br-vlan"
        container_interface: "eth11"
        type: "flat"
        net_name: "vlan"
        group_binds:
          - neutron_linuxbridge_agent
EOF

if [ "${DEPLOY_SWIFT}" == "yes" ]; then
  # add the swift bits
  cat >> /etc/rpc_deploy/conf.d/provider_networks.yml <<EOF
          - swift_proxy
EOF

  cat > /etc/rpc_deploy/conf.d/swift.yml <<EOF
---
global_overrides:
  swift:
    part_power: 8
    storage_network: 'br-storage'
    replication_network: 'br-storage'
    drives:
      - name: swift1.img
      - name: swift2.img
      - name: swift3.img
    mount_point: /srv
    storage_policies:
      - policy:
          name: default
          index: 0
          default: True
swift-proxy_hosts:
  aio1:
    ip: 172.29.236.100
swift_hosts:
  aio1:
    ip: 172.29.236.100
    # workaround for https://bugs.launchpad.net/openstack-ansible/+bug/1402594
    container_vars:
      swift_vars:
EOF
fi

cat > /etc/network/interfaces.d/aio-bridges.cfg <<EOF
## Required network bridges; br-vlan, br-vxlan, br-mgmt.
auto br-mgmt
iface br-mgmt inet static
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports em1
    address $(ifconfig em1 | awk '/inet addr/{print substr($2,6)}')
    netmask 255.255.255.0
    gateway $(ip r | grep 'default via' | awk '{print $3}')
    up ip addr add 172.16.236.100/22 dev \$IFACE label \$IFACE:0

auto br-vxlan
iface br-vxlan inet manual
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    bridge_ports none

auto br-vlan
iface br-vlan inet static
    bridge_stp off
    bridge_waitport 0
    bridge_fd 0
    # Notice this bridge port is an Untagged host interface
    bridge_ports em2
    address 172.16.240.100
    netmask 255.255.252.0
    
EOF

# Ensure the network source is in place
if [ ! "$(grep -Rni '^source\ /etc/network/interfaces.d/\*.cfg' /etc/network/interfaces)" ]; then
    echo "source /etc/network/interfaces.d/*.cfg" | tee -a /etc/network/interfaces
fi

# Bring up the new interfaces
for i in br-storage br-vlan br-vxlan br-mgmt; do
    /sbin/ifup $i || true
done

# Export the home directory just in case it's not set
export HOME="/root"
pushd /opt/ansible-lxc-rpc/rpc_deployment
  # Install all host bits
  install_bits setup/host-setup.yml
  # Install haproxy for dev purposes only
  install_bits infrastructure/haproxy-install.yml
  # Install all of the infra bits
  install_bits infrastructure/memcached-install.yml
  install_bits infrastructure/galera-install.yml
  install_bits infrastructure/rabbit-install.yml
  install_bits infrastructure/rsyslog-install.yml
  install_bits infrastructure/elasticsearch-install.yml
  install_bits infrastructure/logstash-install.yml
  install_bits infrastructure/kibana-install.yml
  install_bits infrastructure/es2unix-install.yml
  install_bits infrastructure/rsyslog-config.yml
  # install all of the Openstack Bits
  install_bits openstack/keystone-all.yml
  if [ "${DEPLOY_SWIFT}" == "yes" ]; then
  install_bits openstack/swift-all.yml
  fi
  install_bits openstack/glance-all.yml
  install_bits openstack/heat-all.yml
  install_bits openstack/nova-all.yml
  install_bits openstack/neutron-all.yml
  install_bits openstack/cinder-all.yml
  install_bits openstack/horizon-all.yml
  install_bits openstack/utility-all.yml
  install_bits openstack/rpc-support-all.yml
  # Stop rsyslog container(s)
  for i in $(lxc-ls | grep "rsyslog"); do
      lxc-stop -k -n $i; lxc-start -d -n $i
  done
  # Reconfigure Rsyslog
  install_bits infrastructure/rsyslog-config.yml
popd
