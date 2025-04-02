### advanced_drastic

This project was launched to overcome the limitations of screen output and input fixed as base with the drastic-steward 32-bit source developed for miyoomini by steward-fu.

For normal operation, you must use the drastic file below.<br>
md5sum:59a7711eff41c640b8861b4d869c747d  drastic<br>

- The parts that differ from drastic-steward are as follows.

1. Hooked based on 64 bit drastic.
2. You can still use the drastic default input settings menu (keyboard/mouse/vibration support)
3. Configure the settings screen and layout screen based on the detected resolution.
4. You can configure a separate layout.json file to change the background image to define it.
5. Supports writing .sav files.

Other changings are as follows.<br>
[history](history.md)

You can download the library from the following path.<br>
[libs](https://github.com/trngaje/advanced_drastic/releases/tag/libs) <br>
Copy to the `libSDL2-2.0.so .0` to `libs` folder <br>

Supports all devices that support mali, gles and egl environments.

- The devices that have been verified for operation are as follows.<br>

folder | platform
-------| -------------
knulli_mali | h700 devices(rg35xx-h/p/sp, rg34xx, rg40xx-h/v, rgcubexx, rg35xx for knull / muos)
knulli_gles | a133 device(trimui smart pro, trimui brick for knulli )
crossmix_gles | a133 devices (trimui smart pro, trimui brick for crossmix os)
rocknix_wayland | rk3566 devices (rg arc-s for rocknix, wayland-es, sway)

Checked normal operation in various os. (knulli / muos / crossmix)

test files for crossmix, trimui smart pro <br>
- step1.back up /mnt/SDCARD/Emus/NDS folder
- step2.download a below file
[https://github.com/trngaje/tsp_binary/releases/download/test/NDS.tar.gz](https://github.com/trngaje/tsp_binary/releases/download/test/NDS.tar.gz)
- step3.unzip the file in device

>Key settings

key | assign
---------------|--------
l2 | toggle stylus / dpad
r2 | swap screen0/1
menu | call setting menu
select | hot key
select + left | dec index of layout
select + right | inc index of layout
select + y | change themes
select + b | toggle blur / pixel mode
select + start | display steward custom settings
select + l | quick load
select + r | quick save


> Configure folders
~~~
├── libs (external)
├── config
│   ├── drastic.cf2
│   └── drastic.cfg
├── devices
│   ├── rg28xx
│   │   ├── config
│   │   │   ├── drastic.cf2
│   │   │   └── drastic.cfg
│   │   └── resources
│   │       └── settings.json
│   ├── rg35xx-sp
│   │   ├── config
│   │   │   ├── drastic.cf2
│   │   │   └── drastic.cfg
│   │   └── resources
│   │       └── settings.json
│   ├── trimui-brick
│   │   └── config
│   │       ├── drastic.cf2
│   │       └── drastic.cfg
│   └── trimui-smart-pro
│       └── config
│           ├── drastic.cf2
│           └── drastic.cfg
├── drastic
├── launch.sh
├── microphone
│   └── microphone.wav
├── resources
│   ├── bg (external)
│   ├── font
│   ├── lang
│   ├── menu
│   ├── pen
│   └── settings.json
├── system
│   ├── drastic_bios_arm7.bin
│   ├── drastic_bios_arm9.bin
│   ├── nds_bios_arm7.bin
│   ├── nds_bios_arm9.bin
│   └── nds_firmware.bin
└── usrcheat.dat
~~~

> fake microphone

`microphone.wav` : default wav (16bit mono) file for all roms <br>
`[name_of_rom].wav` : wav file for individual rom <br>

> stylus cursor

name| image
-----|-----
1_lt.png | ![](resources/pen/1_lt.png)
2_lb.png | ![](resources/pen/2_lb.png)
3_rt.png |  ![](resources/pen/3_rt.png)
4_lb.png |  ![](resources/pen/4_lb.png)
5_rb.png |  ![](resources/pen/5_rb.png)
6_cp.png |  ![](resources/pen/6_cp.png)
7_lb.png |  ![](resources/pen/7_lb.png)

The layout resources are managed in the following path.<br>
[https://github.com/trngaje/drastic_layout](https://github.com/trngaje/drastic_layout)

[Support for devices or assistance in purchasing devices is always welcome.](https://ko-fi.com/trngaje) <br>
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/G2G5DV6J4)

If you need any improvements, please feel free to communicate your opinion in the discord below <br>
[<img src="https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0b5061df29d55a92d945_full_logo_blurple_RGB.svg" alt="discord" width="150">](https://discord.gg/ymh4mdJVad)
