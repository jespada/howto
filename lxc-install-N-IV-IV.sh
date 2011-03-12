#!/bin/bash

set -u

#Install nesesary packages
apt-get install -y --force-yes debootstrap lxc ipcalc
 

#create and mount cgroup virtual file system
if [ -d /var/local/cgroup ]; then
	echo " cgroup already created :) "
else
	mkdir -p /var/local/cgroup
	echo "cgroup /var/local/cgroup cgroup defaults 0 0" >> /etc/fstab
	mount /var/local/cgroup
fi

#get the container installation wrapper script
if [ -e /usr/local/bin/lxc-debian ]; then
	echo "wrapper debian-script already in place..lets fix it just in case.."
	chmod +x /usr/local/bin/lxc-debian
	sed -i 's/$(arch)/$(uname \-m)/' /usr/local/bin/lxc-debian
	sed -i 's/--variant=minbase//g' /usr/local/bin/lxc-debian
else
	cp /usr/share/doc/lxc/examples/lxc-debian.gz /usr/local/bin/
	gunzip /usr/local/bin/lxc-debian.gz
	chmod +x /usr/local/bin/lxc-debian
	sed -i 's/$(arch)/$(uname \-m)/' /usr/local/bin/lxc-debian
	sed -i 's/--variant=minbase//g' /usr/local/bin/lxc-debian
fi


####CONTAINER CREATION#####
NAME=$1
IP1=$2
VLAN1=$3
HW1=`printf "06:00:%x:%x:%x:%x" ${IP1//./ }`
NET1=`ipcalc $IP1 | grep Network | cut -d "/" -f2 | awk '{print $1}'`
IP2=$4
VLAN2=$5
HW2=`printf "06:00:%x:%x:%x:%x" ${IP2//./ }`
NET2=`ipcalc $IP2 | grep Network | cut -d "/" -f2 | awk '{print $1}'`

#Create a container
mkdir -p /srv/lxc/$NAME
lxc-debian -p /srv/lxc/$NAME


#Set hostname

echo $NAME > /srv/lxc/$NAME/rootfs/etc/hostname
echo "127.0.0.1 localhost
`ipcalc $IP1|awk '/^Address:/ {print $2}'` $NAME.mydomain.com $NAME

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts" > /srv/lxc/$NAME/rootfs/etc/hosts

#mount filesystems from host to container
echo "none /srv/lxc/$NAME/rootfs/dev/pts devpts defaults 0 0
none /srv/lxc/$NAME/rootfs/proc proc defaults 0 0
none /srv/lxc/$NAME/rootfs/sys sysfs defaults 0 0
none /srv/lxc/$NAME/rootfs/dev/shm tmpfs defaults 0 0
/home /srv/lxc/$NAME/rootfs/home none bind 0 0" > /srv/lxc/$NAME/fstab
echo "# bind host filesystems
lxc.mount = /srv/lxc/$NAME/fstab" >> /srv/lxc/$NAME/config

#Network configuration
echo "# network1
lxc.utsname = $NAME
lxc.network.type = macvlan
lxc.network.flags = up
lxc.network.link = $VLAN1
lxc.network.name = $VLAN1
lxc.network.macvlan.mode = bridge
lxc.network.hwaddr = $HW1
lxc.network.ipv4 = $IP1/$NET1

# network2
lxc.network.type = macvlan
lxc.network.flags = up
lxc.network.link = $VLAN2
lxc.network.name = $VLAN2
lxc.network.macvlan.mode = bridge
lxc.network.hwaddr = $HW2
lxc.network.ipv4 = $IP2/$NET2" >> /srv/lxc/$NAME/config

echo "# Used by ifup(8) and ifdown(8). See the interfaces(5) manpage or
# /usr/share/doc/ifupdown/examples for more information.

# The loopback network interface
auto lo
iface lo inet loopback

auto $VLAN1
iface eth0 inet static
        address `ipcalc $IP1|awk '/^Address:/ {print $2}'`
        netmask `ipcalc $IP1|awk '/^Netmask:/ {print $2}'`
        network `ipcalc $IP1|awk '/^Network:/ {print $2}'|cut -d / -f 1`
        broadcast `ipcalc $IP1|awk '/^Broadcast:/ {print $2}'`
        gateway `ipcalc $IP1|awk '/^HostMin:/ {print $2}'` 

auto $VLAN2
iface eth1 inet static
        address `ipcalc $IP2|awk '/^Address:/ {print $2}'`
        netmask `ipcalc $IP2|awk '/^Netmask:/ {print $2}'`
        network `ipcalc $IP2|awk '/^Network:/ {print $2}'|cut -d / -f 1`
        broadcast `ipcalc $IP2|awk '/^Broadcast:/ {print $2}'`" \
       
 > /srv/lxc/$NAME/rootfs/etc/network/interfaces

#Fix apt config
cp /etc/apt/apt.conf.d/01proxy /srv/lxc/$NAME/rootfs/etc/apt/apt.conf.d/
cp /etc/apt/preferences /srv/lxc/$NAME/rootfs/etc/apt/
cp /etc/apt/sources.list /srv/lxc/$NAME/rootfs/etc/apt/
cp /etc/apt/sources.list.d/* /srv/lxc/$NAME/rootfs/etc/apt/sources.list.d/
chroot /srv/lxc/$NAME/rootfs apt-get update

#Enable access to container

chroot /srv/lxc/$NAME/rootfs apt-get install ca-certificates
cp /usr/local/share/ca-certificates/mydomain.crt \
 /srv/lxc/$NAME/rootfs/usr/local/share/ca-certificates/
chroot /srv/lxc/$NAME/rootfs update-ca-certificates
chroot /srv/lxc/$NAME/rootfs apt-get install ldap-utils sudo-ldap \
 libsasl2-modules-gssapi-mit libpam-krb5 wamerican nscd
chroot /srv/lxc/$NAME/rootfs apt-get install --no-install-recommends libnss-ldap \
 libpam-cracklib
cp /etc/krb5.conf /srv/lxc/$NAME/rootfs/etc/
cp /etc/pam.d/common-* /srv/lxc/$NAME/rootfs/etc/pam.d/
cp /etc/ldap/ldap.conf /srv/lxc/$NAME/rootfs/etc/ldap/
cp /etc/libnss-ldap.conf /srv/lxc/$NAME/rootfs/etc/
cp /etc/nsswitch.conf /srv/lxc/$NAME/rootfs/etc/
cp /etc/sudoers /srv/lxc/$NAME/rootfs/etc/

#Locales
chroot /srv/lxc/$NAME/rootfs apt-get -y install locales
chroot /srv/lxc/$NAME/rootfs cp /usr/share/i18n/SUPPORTED /etc/locale.gen
chroot /srv/lxc/$NAME/rootfs locale-gen

#Disable root
chroot /srv/lxc/$NAME/rootfs passwd -d root
chroot /srv/lxc/$NAME/rootfs passwd -l root
#Enable buzz
chroot /srv/lxc/$NAME/rootfs addgroup --system buzz
chroot /srv/lxc/$NAME/rootfs adduser --system --home /home/buzz --shell /bin/bash \
 --gecos "Nimbuzz System Administrator" --ingroup buzz buzz
chroot /srv/lxc/$NAME/rootfs  passwd buzz # FIXME - this is interactive

#Create container
lxc-create -n $NAME -f /srv/lxc/$NAME/config

#Start container

lxc-start -d -n $NAME

exit 0
