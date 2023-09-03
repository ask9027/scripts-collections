# Start Termux-X11

## With is Script you can start termux-x11 with root or without root
It will start `pulseaudio` to fix sound problem

First move these files to `bin`
```bash
git clone https://github.com/ask9027/scripts-collections.git
cd $PWD/scripts-collections/termux-x11
mv $PWD/tmx $PREFIX/bin/
chmod +x $PREFIX/bin/tmx
```

### Run with root
Run `tmx` like this
```bash
# fix audio ( first install pulseaudio)
if want to use mic in termux-x11, need to install termux-api from https://github.com/termux/termux-api
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1 -D
```
```bash
su -c /data/data/com.termux/files/usr/bin/tmx 	# full path of tmx
```

### Run without root
Just run as usual
```bash
tmx
```
# or use
```bash
$PREFIX/bin/tmx
```
