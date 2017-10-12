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
    
    -- sb  = source byte                ; tb  = target byte
    -- snu = source normalized unsigned ; tnu = target normalized unsigned
    -- sns = source normalized signed   ; tns = target normalized signed

    local function CalcAddSignedNormalBiased(sb, tb, bias)
        local sns = (2*(sb/255.0)) - 1.0
        local tnu = (tb/255.0)
        
        local final = tnu + (sns * (1.000 - bias))
        final = math.floor(final * 255)
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
                grayscale[1+scale_pix + 3] = CalcAddSignedNormalBiased(normalmap[1+norm_pix+3], grayscale[1+scale_pix + 3], 0.223) -- Red
                grayscale[1+scale_pix + 2] = CalcAddSignedNormalBiased(normalmap[1+norm_pix+2], grayscale[1+scale_pix + 2], 0.622) -- Green
                grayscale[1+scale_pix + 1] = CalcAddSignedNormalBiased(normalmap[1+norm_pix+1], grayscale[1+scale_pix + 1], 0.155) -- Blue
            end
        end
    end

    return grayscale
end


-----------------------------------------
--              MAIN CODE              --
-----------------------------------------
CURRENT_DIR = Path.resolve("")

-- I named the raw texture data accordingly, yours may differ. I just didn't want to
-- keep re-writing the sizes and file names everywhere.
local prefix = 'img01_'
local f_width, f_height = 512, 256

GrayScaleInput  = CURRENT_DIR .. '\\' .. prefix .. 'mip1_' .. tostring(f_width) .. '_' .. tostring(f_height) .. '.bin'
NormalMapInput  = CURRENT_DIR .. '\\' .. prefix .. 'mip2_' .. tostring(f_width/2) .. '_' .. tostring(f_height/2) .. '.bin'
GrayScaleOutput = CURRENT_DIR .. '\\' .. prefix .. 'grayscale.bmp'
NormalMapOutput = CURRENT_DIR .. '\\' .. prefix .. 'normal.bmp'
OrigImageOutput = CURRENT_DIR .. '\\' .. prefix .. 'calculated_final.bmp'

assert(FileSystem.existsSync(GrayScaleInput, "Input grayscale texture doesn't exist!!"))
assert(FileSystem.existsSync(NormalMapInput, "Input normal map texture doesn't exist!!"))

local grayscale = Buffer:new(FileSystem.readFileSync(GrayScaleInput))
local normalmap = Buffer:new(FileSystem.readFileSync(NormalMapInput))

grayscale = RGTC:decompressRGTC2_to_RGBA(grayscale, f_width, f_height, {'Y','Y','Y','X'})
normalmap = RGTC:decompressRGTC2_to_RGBA(normalmap, (f_width/2), (f_height/2), {'X','Z','Y',0xFF})
Bitmap:save(GrayScaleOutput, grayscale, f_width, f_height)
Bitmap:save(NormalMapOutput, normalmap, (f_width/2), (f_height/2))

local original = BlendMipmaps(grayscale, normalmap, f_width, f_height)
print("Saving the buffer to a bitmap...")
Bitmap:save(OrigImageOutput, original, f_width, f_height)
print("Remember to inspect the output and dump file!\n")

