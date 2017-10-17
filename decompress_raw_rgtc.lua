-- Required stuff. Don't touch.
local Path = require('path')
local FileSystem = require('fs')
local Buffer = require("./modules/BufferExtended.lua")
local RGTC = require("./modules/RGTC.lua")
local Bitmap = require("./modules/Bitmap.lua")

 -- Only invoke if you have the raw, decoded buffers. It assumes AGBR byte order.
function BlendMipmaps(grayscale, component, w, h)
    assert(grayscale and type(grayscale)=='table' and (grayscale.length%4 == 0))
    assert(component and type(component)=='table' and (component.length%4 == 0))
    assert(component.length == w*h)
    assert(grayscale.length == w*h*4)
    
    local function ClampDoubleToByte(c, scale, minC, maxC)
        scale = scale or 255
        minC = minC or 0
        maxC = maxC or 255
        c = math.floor(c * scale)
        if     c < minC then c = 0
        elseif c > maxC then c = 255 end
        return c
    end
    
    -- Reference: http://www.equasys.de/colorconversion.html
    -- Luminance; Chroma: Blue; Chroma: Red
    local coeffs = { -- YPbPr to RGB
        SD = { -- Standard Definition
            R = {1.000,  0.000,  1.402},
            G = {1.000, -0.344, -0.714},
            B = {1.000,  1.772,  0.000}},
        HD = { -- High Definition
            R = {1.0000,  0.0000,  1.5748},
            G = {1.0000, -0.1873, -0.4681},
            B = {1.0000,  1.8556,  0.0000}}
    }

    local function Convert_8bitYCbCr_to_8bitRGB(ypb, cbb, crb)
        local ypn = (ypb/255)
        local cbn = (cbb/255) - 0.5
        local crn = (crb/255) - 0.5
        
        local r = ClampDoubleToByte((coeffs.HD.R[1] * ypn) + (coeffs.HD.R[2] * cbn) + (coeffs.HD.R[3] * crn))
        local g = ClampDoubleToByte((coeffs.HD.G[1] * ypn) + (coeffs.HD.G[2] * cbn) + (coeffs.HD.G[3] * crn))
        local b = ClampDoubleToByte((coeffs.HD.B[1] * ypn) + (coeffs.HD.B[2] * cbn) + (coeffs.HD.B[3] * crn))
        return r, g, b
    end
    
    print("Now attempting to calculate the original image...")
    local bbp = 4
    for y=0, (h/2)-1 do
        for x=0, (w/2)-1 do
            local norm_pix = bbp * ((y*(w/2)) + x)
            for t=0, (4)-1 do
                local scale_pix = bbp * (y*(w*2) + x*2 + math.floor(t/2) + (t%2) + ((w-1) * math.floor(t/2)))
                local Yb = grayscale[1+scale_pix + 1] -- Luminance (grayscale)
                local Bn = component[1+norm_pix  + 2] -- Normal byte chroma "Blue"
                local Rn = component[1+norm_pix  + 3] -- Normal byte chroma "Red"
                grayscale[1+scale_pix + 3],
                grayscale[1+scale_pix + 2],
                grayscale[1+scale_pix + 1] = Convert_8bitYCbCr_to_8bitRGB(Yb, Bn, Rn)
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
local prefix = '' -- 'img01_'
local f_width, f_height = 512, 256

GrayScaleInput  = CURRENT_DIR .. '\\' .. prefix .. 'mip1_' .. tostring(f_width) .. '_' .. tostring(f_height) .. '.bin'
ComponentInput  = CURRENT_DIR .. '\\' .. prefix .. 'mip2_' .. tostring(f_width/2) .. '_' .. tostring(f_height/2) .. '.bin'
GrayScaleOutput = CURRENT_DIR .. '\\' .. prefix .. 'grayscale.bmp'
ComponentOutput = CURRENT_DIR .. '\\' .. prefix .. 'components.bmp'
OrigImageOutput = CURRENT_DIR .. '\\' .. prefix .. 'calculated_final.bmp'

assert(FileSystem.existsSync(GrayScaleInput, "Input grayscale texture doesn't exist!!"))
assert(FileSystem.existsSync(ComponentInput, "Input components texture doesn't exist!!"))

local grayscale = Buffer:new(FileSystem.readFileSync(GrayScaleInput))
local component = Buffer:new(FileSystem.readFileSync(ComponentInput))

grayscale = RGTC:decompressRGTC2_to_RGBA(grayscale, f_width, f_height, {'Y','Y','Y','X'})
component = RGTC:decompressRGTC2_to_RGBA(component, (f_width/2), (f_height/2), {'X','Y',0x00,0xFF})
Bitmap:save(GrayScaleOutput, grayscale, f_width, f_height)
Bitmap:save(ComponentOutput, component, (f_width/2), (f_height/2))

local original = BlendMipmaps(grayscale, component, f_width, f_height)
print("Saving the buffer to a bitmap...")
Bitmap:save(OrigImageOutput, original, f_width, f_height)
print("Remember to inspect the output and dump file!\n")

