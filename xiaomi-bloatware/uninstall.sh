echo "Uninstalling Unwanted Packages"

filename="packages.txt"
start=1
pacnumbers=$(wc -l <$filename)

function removepac() {
	while [ $start -le $pacnumbers ]; do
		pac=$(sed -e "${start}q;d" $filename)
		printf "No.$start: $pac Uninstalling ..."
		echo
		sudo pm uninstall --user 0 -k $pac
		((++start))
	done
}

function checkroot() {
	printf "Does Your Devices rooted? (y/N): "
	read r
	if [ $r = "y" ] || [ $r = "Y" ]; then
		if [ -f "$PREFIX/bin/sudo" ]; then
			removepac
		else
			printf "Install tsu first.\nDo you want to install it? (y/N): "
			read p
			if [ $p = "y" ] || [ $p = "Y" ]; then
				pkg install tsu
				removepac
			else
				printf "use ADB"
				echo
			fi
		fi
	else
		printf "You should root devices or use ADB"
		echo
	fi
}

checkroot
