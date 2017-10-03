local FileSystem = require('fs')
local Buffer = require('./BufferExtended.lua')

local Bitmap = {}

function Bitmap:save(file_out, buff, w, h) -- Cuz I'm lazy
    assert(file_out and type(file_out)=='string')
    assert(buff and type(buff)=='table')
    assert(w and type(w)=='number')
    assert(h and type(h)=='number')
    local header = self:createHeader(w, h)
    FileSystem.writeFileSync(file_out, (header .. buff))
end

function Bitmap:createHeader(w,h)
    -- You're goddamn right I'm bullshitting this.
    local hBuff = Buffer:new(70)
    hBuff:memset(0, nil, 'uint8') -- Make everything a zero
    hBuff:writeString(1, 'BM')     -- Magic
    hBuff:writeUInt32LE(3, (w*h*4 + 70)) -- Total File size
    hBuff:writeUInt32LE(11, 70)    -- Image Offset
    hBuff:writeUInt32LE(15, 56)    -- ?
    hBuff:writeUInt32LE(19, w)     -- Width
    hBuff:writeUInt32LE(23, h)     -- Height
    hBuff:writeUInt16LE(27, 1)     -- Planes
    hBuff:writeUInt16LE(29, 32)    -- Bits Per Pixel
    hBuff:writeUInt32LE(31, 3)     -- Compression level (None)
    hBuff:writeUInt32LE(35, w*h*4) -- Image Size
    hBuff:writeUInt32LE(39, 2835)  -- ?
    hBuff:writeUInt32LE(43, 2835)  -- ?
    -- Technically the end of the header
    -- Channel order (I think)
    hBuff:writeUInt32LE(55, 0xFF000000) -- Channel #1 : Alpha
    hBuff:writeUInt32LE(59, 0x00FF0000) -- Channel #2 : Blue
    hBuff:writeUInt32LE(63, 0x0000FF00) -- Channel #3 : Green
    hBuff:writeUInt32LE(67, 0x000000FF) -- Channel #4 : Red
    
    return hBuff
end

return Bitmap
