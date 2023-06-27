# Start Termux-X11

## With is Script you can start termux-x11 with root or without root
It will start `pulseaudio` to fix sound problem

First move these files to `bin`

    git clone https://github.com/ask9027/scripts-collections.git
    cd $PWD/scripts-collections/termux-x11
    mv $PWD/tmx* $PREFIX/bin/
    chmod +x $PREFIX/bin/tmx*


### Run with root
Run `tmx_root` like this

    # fix audio ( first install pulseaudio)
    pulseaudio --start --load="module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1" --exit-idle-time=-1
    su -c $PREFIX/bin/tmx_root
it will run termux-x11 with root if your device rooted

### Run without root
Just run as usual

    tmx # dont need to run pulseaudio `tmx` already start it
    # or use 
    $PREFIX/bin/tmx
