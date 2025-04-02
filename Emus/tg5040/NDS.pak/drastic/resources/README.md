### drastic_layout

resolution | description
---------- | -----------------
640x480  | images worked on by the @steward-fu.
1024x768 | resizing the 640x480 image and using it again.
720x720 | images worked on by @duncanyoyo1.
1280x720 | This image is pre-applied by crossmix.
854x480 | not defined
720x480 | images worked on by @tamarindojuice.
480x320 | not defined

#### The description of layout.json is as follows.

> The format is still in development. It may be deleted at any time.

"type" : 0 (default,normal),1:trasparent,2:vertical,3:high resolution,4:single <br>
"rotate" : 0, 90, 270 for vertical layout <br>
"bg" : "[file name of bg image]" <br>
"_x" : positon x of screen <br>
"_y" : position y of screen <br>
"_w" : width of screen <br>
"_h" : height of screen <br>

example <br>
#### 1.type : normal
~~~
{
    "index":4,
    "name":"v0",
    "bg":"bg_v0.png",

    "screen0_x":192,
    "screen0_y":48,
    "screen0_w":256,
    "screen0_h":192,

    "screen1_x":192,
    "screen1_y":240,
    "screen1_w":256,
    "screen1_h":192
},
~~~
#### 2.type : transparent
~~~
{
    "index":0,
    "name":"vh_t0",
    "bg":"",
    "type":1,

    "screen0_x":0,
    "screen0_y":0,
    "screen0_w":160,
    "screen0_h":120,

    "screen1_x":0,
    "screen1_y":0,
    "screen1_w":640,
    "screen1_h":480
},
~~~
#### 3.type : single
~~~
{
    "index":2,
    "name":"s0",
    "bg":"bg_s0.png",
    "type":4,

    "screen0_x":0,
    "screen0_y":0,
    "screen0_w":0,
    "screen0_h":0,

    "screen1_x":64,
    "screen1_y":48,
    "screen1_w":512,
    "screen1_h":384
},
~~~
#### 4.type : vertical
~~~
{
    "index":13,
    "name":"hh0",
    "bg":"bg_hh0.png",
    "type":2,
    "rotate":90,

    "screen0_x":0,
    "screen0_y":26,
    "screen0_w":427,
    "screen0_h":320,

    "screen1_x":320,
    "screen1_y":26,
    "screen1_w":427,
    "screen1_h":320
},
~~~
#### 5.type : high resolution
~~~
{
    "index":15,
    "name":"hres0",
    "bg":"bg_hres0.png",
    "type":3,

    "screen0_x":63,
    "screen0_y":48,
    "screen0_w":512,
    "screen0_h":384,

    "screen1_x":64,
    "screen1_y":48,
    "screen1_w":512,
    "screen1_h":384
},
~~~
I'm not good at graphics work tools, so I'm always welcome to reflect on this git hub after someone changes the bg image.

[Support for devices or assistance in purchasing devices is always welcome.](https://ko-fi.com/trngaje) <br>
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/G2G5DV6J4)

If you need any improvements, please feel free to communicate your opinion in the discord below <br>
[<img src="https://cdn.prod.website-files.com/6257adef93867e50d84d30e2/636e0b5061df29d55a92d945_full_logo_blurple_RGB.svg" alt="discord" width="150">](https://discord.gg/ymh4mdJVad)
