#!/bin/bash

overlay_dir=/root/initramfs-overlay


kerns="$(eselect kernel list | grep -F '[')"
nkerns=$(echo "$kerns" | wc -l)

echo "$kerns"
echo "  [$(( $nkerns + 1 ))]   Current config"
echo "  [Manual entry]"

while true; do
	echo -n 'Grab config from where: '
	read n
	if [[ $n -ge 1 ]] && [[ $n -le $nkerns ]]; then
		eselect kernel set $n
		cp -v /usr/src/linux/.config /tmp/kconfig
		break
	elif [[ $n -eq $(( $nkerns + 1 )) ]]; then
		echo "Copying from /proc/config.gz"
		zcat /proc/config.gz > /tmp/kconfig
		break
	elif [[ -f "$n" ]]; then
		cp -v "$n" /tmp/kconfig
		break
	else
		echo "Invalid selection!"
	fi
done

unset n

echo "$kerns"

while true; do
	echo -n 'Select a kernel: '
	read n
	if [[ $n -ge 1 ]] && [[ $n -le $nkerns ]]; then
		eselect kernel set $n
		break
	else
		echo "Invalid selection!"
	fi
done

unset n

genkernel kernel --kernel-config=/tmp/kconfig $*

emerge -1 nvidia-drivers

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

pushd /usr/src/linux
for mod in "$dir"/video/*; do 
	scripts/sign-file sha512 certs/signing_key.pem certs/signing_key.x509 "$mod"
done
popd

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

rm -r "$overlay_dir"
overlay_moddir="${overlay_dir}${dir}"
mkdir -p "$overlay_moddir/kernel/drivers"

cp "$dir"/modules.* "$overlay_moddir"
for d in i2c gpu char; do 
	cp -a "$dir/kernel/drivers/$d" "$overlay_moddir/kernel/drivers"
done
cp -a "$dir/video" "$dir"/modules* "$overlay_moddir"

genkernel --kernel-config=/tmp/kconfig initramfs $*

pushd /usr/src/linux
make clean
make prepare
popd

grub-mkconfig -o /boot/grub/grub.cfg
