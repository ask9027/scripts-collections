# Start Termux-X11

## With is Script you can start termux-x11 with root or without root
It will start `pulseaudio` to fix sound problem

First move this to `bin`

    git clone https://github.com/ask9027/scripts-collections.git
    cd $PWD/scripts-collections/termux-x11
    mv $PWD/startTermux-X11 $PREFIX/bin/
    chmod +x $PREFIX/bin/startTermux-X11
### Run with root
Just provide `0` after script like

    startTermux-X11 0
it will run termux-x11 with root if your device rooted

### Run without root
Just run as usual

    startTermux-X11
