# InfiniteLivez-Video-Performer Instructions
These instructions describe the process of installing the application on a raspberrypi from scratch.

## 1. SD Card
- Download the raspberrypi disk image [2021-05-07-raspios-buster-armhf-lite.zip](https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-05-28/2021-05-07-raspios-buster-armhf-lite.zip).
- Install it on your SD card with [etcher](https://www.balena.io/etcher/). Do not eject the card.
- Terminal: `sudo touch /Volumes/boot/ssh`
- Eject the card and put it in your raspberrypi.

## 2. First Boot
- Connect all devices to your raspberrypi and power on. A screen is not needed at this stage.
- Enable internet sharing on your machine: System Preferences > Sharing > Internet Sharing > From: Wi-Fi, To: Ethernet.
- Terminal: `ssh pi@raspberrypi.local`
- Password: `raspberry`

## 3. Initial Setup
- Install git + tmux: `sudo apt-get -y install git tmux`
- Install helper scripts:
```
cd ~
git clone https://github.com/halftheory/sh-halftheory-pi
cd sh-halftheory-pi
chmod +x install.sh
./install.sh
```
- Perform common optimizations: `optimize force`
  - When you reach the 'raspi-config' menu set: boot console auto-login, network wait off, keyboard localization, opengl driver legacy, gpu memory 256.
- Note the new easy password: `pi`
- Turn on/off common features:
```
config audio off
config bluetooth off
config hdmi on
config overclock off
```

## 4. Application Install
- Install the files and dependencies:
```
cd ~
git clone https://github.com/halftheory/InfiniteLivez-Video-Performer
cd InfiniteLivez-Video-Performer
chmod +x install.sh
./install.sh -install -depends
```
- Turn on the [LCDHat](https://www.waveshare.com/wiki/1.44inch_LCD_HAT) if it's installed: `lcdhat on`
  - Q: Resize screen to LCD size? A: no.
- Reboot: `sudo reboot`

## 5. Application Operation
- Recommendation: If possible force connected displays to use 720p as the raspberrypi can have problems with high resolutions.
- Start: `vp` or `123`(LCDHat)
- Quit: `Esc` or `q` or hold together `123`(LCDHat)
- Shutdown: `sudo halt` or `321`(LCDHat)

## 6. Application Update
```
cd ~/InfiniteLivez-Video-Performer
./update.sh
```
