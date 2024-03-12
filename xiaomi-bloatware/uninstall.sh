echo "Uninstalling Unwanted Packages"

filename="packages.txt"
index=1
pacnumbers=$(wc -l <$filename)

function removepackegs() {
	while [ $index -le $pacnumbers ]; do
		pac=$(sed -e "${index}q;d" $filename)
		printf "No.$index: $pac Uninstalling ..."
		echo
		if [ $1 = "1" ]; then
			sudo pm uninstall --user 0 -k $pac
		else
			adb shell pm uninstall --user 0 -k $pac
		fi
		((++index))
	done
}

function checkroot() {
	printf "Does Your Devices rooted? (y/N): "
	read r
	if [ $r = "y" ] || [ $r = "Y" ]; then
		if [ -f "$PREFIX/bin/sudo" ]; then
			removepackegs 1
		else
			printf "Install tsu first.\nDo you want to install it? (y/N): "
			read p
			if [ $p = "y" ] || [ $p = "Y" ]; then
				pkg install tsu
				removepackegs 1
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

function select_method() {
	printf "Select 1 for ROOT and 2 for ADB: "
	read r
	if [ $r = "1" ]; then
		checkroot
	elif [ $r = "2" ]; then
		if [ -f "$PREFIX/bin/adb" ]; then
			echo "$(adb devices)"
			removepackegs 2
		else
			echo "install adb or connect devices"
		fi
	fi
}

select_method
