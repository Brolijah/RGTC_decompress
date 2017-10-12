# RGTC_decompress
Decoding of raw RGTC2 textures out to RGBA bitmaps.  
**Requires Luvit.**  
You'll find looking at this the code is very... crass. I'll clean it up when I start adding other texture formats and expand what I got here. I started making this just so I could decode some packed textures in Project DIVA F 2nd. The game files are stripped of headers and are placed in containers. And some of the textures used RGTC2/BC5/3Dc/ATI2 compression with some other special footnotes about them...  

That said, these are designed with the intent of reversing textures of an unknown configuration about them, including how they may have been swizzled, resolutions, what the mipmaps are used for, etc. The function call expects the raw uncontained buffer of the texture data. I figured I'd stupid proof it later when I needed to, so it lacks some error handling. (Some, not entirely.)  

### How To Use the RGTC Module
The function you care about is `RGTC:decompressRGTC2_to_RGBA()` which accepts the following four arguments:  
* Raw texture buffer  
* Width  
* Height  
* Channel Swizzling/Values  

As it is right now, the input should be the raw texture data as a Luvit Buffer.  
The channel swizzle I wanted to be very self-explanatory. In order of RGBA, into where did you want the X Y and potentially Z channels placed in? This means of block compression really only stores an X channel and a Y channel. And the Z channel is regenerated when the graphical engine renders the texture. You may also put a byte value in if you want that channel to explicitly be that across all pixels.  
The channel swizzling was my biggest motivation for writing the script. I ran out of patience trying to figure out how I should parse the textures by placing them inside DDS files and then having to re-arrange the channels. Something I don't see tools let you do is control how the texture was swizzled when you want to read it. And since I was trying to reverse files, I didn't have the luxury of knowing how it was all done beforehand.  
An example usage case as seen in the main lua file:  
```lua
local Path = require('path')
local FileSystem = require('fs')
local Buffer = require("./modules/BufferExtended.lua") -- This is also needed by RGTC and Bitmap for some extra functions
local RGTC = require("./modules/RGTC.lua")
local Bitmap = require("./modules/Bitmap.lua")

CURRENT_DIR = Path.resolve("")
GrayScaleInput  = CURRENT_DIR .. '\\mip1.bin'
GrayScaleOutput = CURRENT_DIR .. '\\grayscale.bmp'
NormalMapInput  = CURRENT_DIR .. '\\mip2.bin'
NormalMapOutput = CURRENT_DIR .. '\\normal.bmp'

assert(FileSystem.existsSync(GrayScaleInput, "Input grayscale texture doesn't exist!!"))
assert(FileSystem.existsSync(NormalMapInput, "Input normal map texture doesn't exist!!"))

local grayscale = Buffer:new(FileSystem.readFileSync(GrayScaleInput))
local normalmap = Buffer:new(FileSystem.readFileSync(NormalMapInput))

grayscale = RGTC:decompressRGTC2_to_RGBA(grayscale, 512, 256, {'Y','Y','Y','X'})
normalmap = RGTC:decompressRGTC2_to_RGBA(normalmap, 256, 128, {'X','Z','Y',0xFF})
Bitmap:save(GrayScaleOutput, grayscale, 512, 256)
Bitmap:save(NormalMapOutput, normalmap, 256, 128)
```  

If you're just a random person who came across this while looking into BC5/RGTC/ATI2/3Dc, and you're looking into some understanding on how to restore them to their proper colors, then perhaps I hope this may offer some guidance if you're lost.  
For some further reading material on this form of compression, I found these pages to be most useful:  
https://www.khronos.org/registry/DataFormat/specs/1.1/dataformat.1.1.html#RGTC  
http://neatcorporation.com/forums/viewtopic.php?t=277  

In regards to the other function contanied in `decompress_raw_rgtc.lua`, BlendMipmaps was intended for restoring the aforementioned Project DIVA textures to their original color. That function takes the grayscale and the half size normal map and does some weird variation of Linear Light blending (to be more technical, Add Signed Normal) with a bias to it. In my tests, the red channel is usually accurate to the post-blended buffer ripped using renderdocs. Blue has some more variation to it but it's mostly accurate. And green is all over the place...  

![success](https://i.imgur.com/LbAkoGI.png)
