local core = require('core')
local ffi  = require('ffi')
local Buffer = require('./BufferExtended.lua')

local RGTC = {}

local bor = bit.bor
local band = bit.band
local lshift = bit.lshift
local rshift = bit.rshift

local BLOCKSIZE = 16 -- Don't touch this REEEEEE
-- Note: col is short for color. I wanted something generic and easy enough
-- to not confuse **myself** of what is what. So depending on what your
-- target channel is, that can any of the 4 RGBA channels.
function RGTC:decodeBlockRGTC(b_texel, n_offset, tbl_chnl, n_width) --, b_debug)
    assert(b_texel and (type(b_texel) == 'table'))
    assert(b_texel.length == 8)
    
    local col_0 = b_texel[1]
    local col_1 = b_texel[2]
    local bits = ffi.cast('uint64_t',
        b_texel[3] +
          256 * (b_texel[4] +
            256 * (b_texel[5] +
              256 * (b_texel[6] +
                256 * (b_texel[7] +
                  256 * b_texel[8])))))

--  local codestr = nil
--  if b_debug then codestr = 'Codes:' end

    for i=1, BLOCKSIZE do
        local ctrl_code = band(rshift(bits, 3*(i-1)), 0x07) -- 0x07 = 00000111 Binary
        local val
        if col_0 > col_1 then
            if     ctrl_code == 0 then val = col_0
            elseif ctrl_code == 1 then val = col_1
            elseif ctrl_code == 2 then val = math.floor(((6*col_0) + (1*col_1)) / 7)
            elseif ctrl_code == 3 then val = math.floor(((5*col_0) + (2*col_1)) / 7)
            elseif ctrl_code == 4 then val = math.floor(((4*col_0) + (3*col_1)) / 7)
            elseif ctrl_code == 5 then val = math.floor(((3*col_0) + (4*col_1)) / 7)
            elseif ctrl_code == 6 then val = math.floor(((2*col_0) + (5*col_1)) / 7)
            elseif ctrl_code == 7 then val = math.floor(((1*col_0) + (6*col_1)) / 7)
            end
        
        else -- col_0 <= col_1
            if     ctrl_code == 0 then val = col_0
            elseif ctrl_code == 1 then val = col_1
            elseif ctrl_code == 2 then val = math.floor(((4*col_0) + (1*col_1)) / 5)
            elseif ctrl_code == 3 then val = math.floor(((3*col_0) + (2*col_1)) / 5)
            elseif ctrl_code == 4 then val = math.floor(((2*col_0) + (3*col_1)) / 5)
            elseif ctrl_code == 5 then val = math.floor(((1*col_0) + (4*col_1)) / 5)
            elseif ctrl_code == 6 then val = 0x00
            elseif ctrl_code == 7 then val = 0xFF
            end
        
        end
        
        -- Value **will** have been assigned something.
        local px_indx = 1 + ((math.ceil((i/4)-1) * n_width) + ((i-1)%4) + n_offset)
        tbl_chnl[px_indx] = val
        
--      if codestr then codestr = (codestr .. string.format(' %02X,', tonumber(ctrl_code))) end
    end
--  if codestr then print(codestr) end
end

function RGTC:decompressRGTC2_to_RGBA(buff_in, w, h, tbl_swiz)
    assert(buff_in and type(buff_in)=='table', "Input should be a Luvit Buffer!!")
    assert(w and (w>=4) and ((w%4)==0), "Width must be a power of 2 integer!!")
    assert(h and (h>=4) and ((h%4)==0), "Height must be a power of 2 integer!!")
    assert(tbl_swiz and type(tbl_swiz)=='table' and #tbl_swiz==4,
            "You must specify how you want interpret the XY channels.")

    local X, Y, Z = {}, {}, {}
    local workingBuff = Buffer:new(buff_in:toString())
--  print("\nBeginning texel block decoding process...")
    for i=1, (workingBuff.length), BLOCKSIZE do
        local block
        block = Buffer:new(workingBuff:toString(i, i+7))
        self:decodeBlockRGTC(block, #Y, Y, w)
        
        block = Buffer:new(workingBuff:toString(i+8, i+15))
        self:decodeBlockRGTC(block, #X, X, w)
    end
--  print("Decoding completed! Length of X = " .. #X)

--  print("\nBeginning writing the RGBA buffer...")
    local function CalcZ(x,y)
        local xn = (x/255.0)
        local yn = (y/255.0)
        local final = math.sqrt(1.0 - (xn*xn) - (yn*yn))
        final = math.floor(final * 255.0)
        return final
    end
    local R,G,B,A = tbl_swiz[1], tbl_swiz[2], tbl_swiz[3], tbl_swiz[4]
    local channels = {R,G,B,A}

    for i,c in ipairs(channels) do
        if c == 'X' then channels[i] = X
        elseif c == 'Y' then channels[i] = Y
        elseif c == 'Z' then channels[i] = CalcZ
        elseif (c >= 0) and (c < 256) and (c % 1 == 0) then -- nothing
        else error('Invalid channel specification.')
        end
    end
    
    local pos = 0
    workingBuff = Buffer:new((w*h) * 4)     -- 4 Channels
    for i=1, workingBuff.length, 4 do
        pos = pos + 1
        for j,c in ipairs(channels) do
            local val
            if type(c) == 'table' then val = c[pos]
            elseif type(c) == 'function' then val = c(X[pos],Y[pos])
            elseif type(c) == 'number' then val = c
            else error('Invalid channel write specification. Channel Type: ' .. type(c))
            end
            workingBuff:writeUInt8((i + (4-j)), val)
        end
    end
--  print("Pixels written: " .. pos)
--  print("RGBA Dump complete!")

    return workingBuff
end

return RGTC
