# InfiniteLivez-Video-Performer
A creative application for loading and controlling gifs/videos on the raspberrypi.

![halftheory_image1.png](halftheory_image1.png?raw=true) ![halftheory_image2.png](halftheory_image2.png?raw=true)

Features:
- Finds all gifs/videos on connected USB drives and copies them locally.
- Converts all gifs to high quality videos.
- Automatically detect midi devices.
- Control videos via midi, keyboard, or the [LCDHat](https://www.waveshare.com/wiki/1.44inch_LCD_HAT).
- Play videos alphabetically or at random.
- Automatic BPM mode.
- Many features also work on macos.

Programmed by [Half/theory](http://halftheory.com/). Commissioned by [Infinite Livez](https://infinitelivez.bandcamp.com/).

## Install
- Install the files and dependencies:
```
cd ~
sudo apt-get -y install git
git clone https://github.com/halftheory/InfiniteLivez-Video-Performer
cd InfiniteLivez-Video-Performer
chmod +x install.sh
./install.sh -install -depends
```
- Turn on the LCDHat if it's installed: `lcdhat on`
  - Q: Resize screen to LCD size? A: no.
- Reboot: `sudo reboot`

## Operation
Recommendation: If possible force connected displays to use 720p as the raspberrypi can have problems with high resolutions.
Command | Function
:--- | :---
`vp`<br/>`123`(LCDHat) | Start the application.
1 | Midi mode - 'beats' are received via midi to change videos (default every 4 beats).
2 | BPM mode - 'beats' are automatically generated (default 100 BPM).
3 | Toggle file order alphabetical/random.
Left | Trigger the previous video.
Right | Trigger the next video.
Up | Midi mode - shorten the change interval.<br/>BPM mode - increase the BPM.
Down | Midi mode - lengthen the change interval.<br/>BPM mode - decrease the BPM.
Enter | Midi mode - reset the change interval.<br/>BPM mode - reset the BPM.
b | Trigger a 'beat'.
Esc<br/>q<br/>hold 123(LCDHat) | Quit.
`321`(LCDHat) | Shutdown.

## Update
```
cd ~/InfiniteLivez-Video-Performer
./update.sh
```

## Uninstall
```
cd ~/InfiniteLivez-Video-Performer
./install.sh -uninstall
# or to delete all working files
./install.sh -uninstall -depends
```

### Notes
- Details on how to setup the raspberrypi are provided in [instructions.md](instructions.md).
- Source code for the openframeworks c++ project is in the [ofx-video-performer](ofx-video-performer) folder.
- Compiled binaries for armv6 `video-performer` and macos `video-performer.app` are provided, although it's preferable to use the `video-performer-launcher.sh`.

### Known Issues
- The application will only recognize a USB keyboard *or* the LCDHat buttons, not both at the same time. To use the LCDHat buttons unplug the keyboard before launching.
- The first video may not be scaled correctly in fullscreen mode. This is corrected when the video changes.
