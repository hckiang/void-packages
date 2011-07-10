#!/bin/sh
#
# A simple script to remove old kernel files/modules.
# Brought to you by yours truly Juan RP in the Public Domain.
#
: ${progname:=$(basename $0)}

usage()
{
	cat <<_EOF
Usage: $progname <target> [<version>]

Targets:
 list	Lists old installed kernels.
 rm	Remove kernel <version>

Example:
	$ $progname list
	$ $progname rm 2.6.39.2
_EOF
	exit 1
}

list_kernels()
{
	local k kpkg installed skip

	for k in /var/lib/initramfs-tools/*; do
		kver=$(basename $k)
		for kpkg in kernel kernel-snapshot; do
			installed=$(xbps-uhelper -r / version $kpkg)
			if [ -n "$installed" ]; then
				if [ "$installed" = "$kver" ]; then
					skip=1
					break
				fi
			fi
		done
		if [ -n "$skip" ]; then
			unset skip
			continue
		fi
		echo "$kver"
	done
}

run_hooks()
{
	local dir="$1"
	local kver="$2"
	local d

	for d in /etc/kernel.d/${dir}/*; do
		[ ! -x "$d" ] && continue
		echo "Running ${dir} kernel hook: $(basename $d)..."
		$d kernel $kver
	done
}

remove_kernel()
{
	local rmkver="$1"
	local installed f kfile

	if [ ! -f /boot/vmlinuz-${rmkver} -a ! -d /lib/modules/${rmkver} ]; then
		echo "Kernel ${rmkver} not installed."
		exit 0
	fi

	installed=$(xbps-uhelper -r / version $rmkver)
	if [ -n "$installed" ]; then
		echo "Kernel $rmkver is currently installed."
		exit 0
	fi

	# Execute pre-remove kernel hooks.
	run_hooks pre-remove $rmkver
	# Remove kernel files in /boot.
	for f in config System.map vmlinuz; do
		kfile="/boot/${f}-${rmkver}"
		[ ! -f "${kfile}" ] && continue
		echo "Removing ${kfile}..."
		rm -f ${kfile}
	done
	# Remove kernel modules
	if [ -d "/lib/modules/${rmkver}" ]; then
		echo "Removing /lib/modules/${rmkver}..."
		rm -rf /lib/modules/${rmkver}
	fi
	# Execute post-remove kernel hooks.
	run_hooks post-remove $rmkver
}

if [ "$1" = "list" ]; then
	list_kernels
elif [ "$1" = "rm" ]; then
	[ -z "$2" ] && usage
	remove_kernel "$2"
else
	usage
fi

exit 0
