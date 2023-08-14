echo "Uninstalling Unwanted Packages"

filename="packages.txt"
index=1
pacnumbers=$(wc -l <$filename)

function removepackegs() {
	while [ $index -le $pacnumbers ]; do
		pac=$(sed -e "${index}q;d" $filename)
		printf "No.$index: $pac Uninstalling ..."
		echo
		sudo pm uninstall --user 0 -k $pac
		((++index))
	done
}

function checkroot() {
	printf "Does Your Devices rooted? (y/N): "
	read r
	if [ $r = "y" ] || [ $r = "Y" ]; then
		if [ -f "$PREFIX/bin/sudo" ]; then
			removepackegs
		else
			printf "Install tsu first.\nDo you want to install it? (y/N): "
			read p
			if [ $p = "y" ] || [ $p = "Y" ]; then
				pkg install tsu
				removepackegs
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
