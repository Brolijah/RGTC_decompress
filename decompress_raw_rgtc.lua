-- Required stuff. Don't touch.
local Path = require('path')
local FileSystem = require('fs')
local Buffer = require("./modules/BufferExtended.lua")
local RGTC = require("./modules/RGTC.lua")
local Bitmap = require("./modules/Bitmap.lua")

 -- Only invoke if you have the raw, decoded buffers. It assumes AGBR byte order.
function BlendMipmaps(grayscale, normalmap, w, h)
    assert(grayscale and type(grayscale)=='table' and (grayscale.length%4 == 0))
    assert(normalmap and type(normalmap)=='table' and (normalmap.length%4 == 0))
    assert(normalmap.length == w*h)
    assert(grayscale.length == w*h*4)
    
    local function CalcLinearLight(n, t)
        n = (n/255.0)
        t = (t/255.0)
        local final = math.floor((t + 2*n-1) * 255)
        if final < 0 then final = 0
        elseif final > 255 then final = 255
        end
        return final
    end
    
    print("Now attempting to calculate the original image...")
    local bbp = 4
    for y=0, (h/2)-1 do
        for x=0, (w/2)-1 do
            local norm_pix = bbp * ((y*(w/2)) + x)
            for t=0, (4)-1 do
                local scale_pix = bbp * (y*(w*2) + x*2 + math.floor(t/2) + (t%2) + ((w-1) * math.floor(t/2)))
                grayscale[1+scale_pix + 3] = CalcLinearLight(normalmap[1+norm_pix+3], grayscale[1+scale_pix + 3]) -- Red
                grayscale[1+scale_pix + 2] = CalcLinearLight(normalmap[1+norm_pix+2], grayscale[1+scale_pix + 2]) -- Green
                grayscale[1+scale_pix + 1] = CalcLinearLight(normalmap[1+norm_pix+1], grayscale[1+scale_pix + 1]) -- Blue
            end
        end
    end

    return grayscale
end


-----------------------------------------
--              MAIN CODE              --
-----------------------------------------
CURRENT_DIR = Path.resolve("")

GrayScaleInput  = CURRENT_DIR .. '\\mip1.bin'
GrayScaleOutput = CURRENT_DIR .. '\\grayscale.bmp'
NormalMapInput  = CURRENT_DIR .. '\\mip2.bin'
NormalMapOutput = CURRENT_DIR .. '\\normal.bmp'
OrigImageOutput = CURRENT_DIR .. '\\calculated_final.bmp'

assert(FileSystem.existsSync(GrayScaleInput, "Input grayscale texture doesn't exist!!"))
assert(FileSystem.existsSync(NormalMapInput, "Input normal map texture doesn't exist!!"))

local grayscale = Buffer:new(FileSystem.readFileSync(GrayScaleInput))
local normalmap = Buffer:new(FileSystem.readFileSync(NormalMapInput))

grayscale = RGTC:decompressRGTC2_to_RGBA(grayscale, 512, 256, {'Y','Y','Y','X'})
normalmap = RGTC:decompressRGTC2_to_RGBA(normalmap, 256, 128, {'X','Z','Y',0xFF})
Bitmap:save(GrayScaleOutput, grayscale, 512, 256)
Bitmap:save(NormalMapOutput, normalmap, 256, 128)

local original = BlendMipmaps(grayscale, normalmap, 512, 256)
print("Saving the buffer to a bitmap...")
Bitmap:save(OrigImageOutput, original, 512, 256)
print("Remember to inspect the output and dump file!\n")

