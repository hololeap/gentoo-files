#!/bin/bash

overlay_dir=/root/initramfs-overlay
installed_dir=/var/db/pkg/

# Usage: extra_mods MODDIR
# Customize this to list extra modules you want to include in the initramfs
extra_mods() {
	find "$1"/kernel/drivers/{i2c,gpu,char} -type f
}

# Usage: error TEXT
error() {
	echo "Error: $1"
	exit 1
}

# Usage: run PROGRAM ARG1 ARG2 ...
# Exits with an error if this program doesn't exit with code 0
run() {
	$* || error "Failed on command: $*"
}

# Usage: sign_modules MODULE ...
# Runs scripts/sign-file on each listed module (full paths)
sign_modules() {
	pushd /usr/src/linux
	for mod in $*; do 
		run scripts/sign-file sha512 certs/signing_key.pem certs/signing_key.x509 "$mod"
	done
	popd
}

# Usage: cp_modules DIR MODULE1 MODULE2 ...
# Copy all listed modules from DIR to $overlay_dir
# (automatically creates directory structure and includes modules.*)
cp_modules() {
	dir="$1"
	shift
	overlay_moddir="$overlay_dir/$dir"
	run mkdir -pv "$overlay_moddir"
	run cp -v "$dir"/modules.* "$overlay_moddir"
	for mod in $*; do
		dirname="$(realpath "$(dirname "$mod")")"
		run mkdir -pv "$overlay_dir/$dirname"
		run cp -v "$mod" "$overlay_dir/$dirname"
	done
}			

# Usage: module_atoms
# 
module_atoms() {
	run find "$installed_dir" -type f -name CONTENTS -print0 |\
	xargs -0 grep -l /lib/modules |\
	sed -rn 's/.*\/pkg\/(.*)\/CONTENTS/=\1/p'
}

kerns="$(run eselect kernel list | grep -F '[')"
nkerns=$(echo "$kerns" | wc -l)
atoms="$(module_atoms)"
mods=$(echo "$atoms" | while read f; do run equery f -f obj "$f" | grep -F /lib/modules/; done)

echo "$kerns"
echo "  [$(( $nkerns + 1 ))]   Current config"
echo "  [Manual entry]"

while true; do
	echo -n 'Grab config from where: '
	read n
	if echo "$n" | pcregrep -q '^[0-9]+$'; then
		if [[ $n -ge 1 ]] && [[ $n -le $nkerns ]]; then
			run eselect kernel set $n
			run cp -v /usr/src/linux/.config /tmp/kconfig
			break
		elif [[ $n -eq $(( $nkerns + 1 )) ]]; then
			echo "Copying from /proc/config.gz"
			run zcat /proc/config.gz > /tmp/kconfig
			break
		else
			echo "Invalid selection!"
		fi
	elif [[ -f "$n" ]]; then
		run cp -v "$n" /tmp/kconfig
		break
	else
		echo "Not a file: $n"
	fi
done

unset n

echo "$kerns"

while true; do
	echo -n 'Select a kernel: '
	read n
	if [[ $n -ge 1 ]] && [[ $n -le $nkerns ]]; then
		run eselect kernel set $n
		break
	else
		echo "Invalid selection!"
	fi
done

unset n

run genkernel kernel --kernel-config=/tmp/kconfig $*
[[ -n $atoms ]] && run emerge -1 $atoms

module_dirs=( $(ls -d /lib/modules/*/ | xargs -n1 basename) )
	
for i in $( seq 0 $(( ${#module_dirs[*]} - 1 )) ); do
	echo $(( $i + 1 )): ${module_dirs[$i]}
done


while true; do
	echo -n 'Select a module dir: '
	read n
	if [[ $n -ge 1 ]] && [[ $n -le ${#module_dirs[*]} ]]; then
		dir="/lib/modules/${module_dirs[$(( $n - 1 ))]}"
		break
	else
		echo "Invalid selection!"
	fi
done

sign_modules $mods

unset n

while true; do
	echo "About to recursively delete $overlay_dir ..."
	echo -n "Proceed? "
	read n
	case "$n" in
		( [Yy] | [Yy][Ee] | [Yy][Ee][Ss] ) break ;;
		( [Nn] | [Nn][Oo]                ) echo "Exiting" ; exit ;;
		*                                ) echo "Invalid response!" ;;
	esac
done

rm -rf "$overlay_dir"
cp_modules "$dir" $(extra_mods "$dir") $mods

run genkernel --kernel-config=/tmp/kconfig initramfs $*

pushd /usr/src/linux
run make clean
run make prepare
popd

run grub-mkconfig -o /boot/grub/grub.cfg
