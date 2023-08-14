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
pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1

su # Enter in root
/data/data/com.termux/files/usr/bin/tmx #full path or tmx
```

### Run without root
Just run as usual
```bash
tmx # dont need to run pulseaudio `tmx` already start it
```
# or use
```bash
$PREFIX/bin/tmx
```
