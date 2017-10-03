Buffer = require('buffer').Buffer

function Buffer:writeString(offset, str)
    for i=0, #str-1 do
        if (offset+i) <= self.length then
            self[offset+i] = str:byte(i+1)
        end
    end
end

function Buffer:memset(value, size, valType, offset)
    size = (size and size < self.length) or self.length
    offset = offset or 1

    -- MEMSET A STRING OR CHAR
    if type(value) == "string" then
        for i = offset, size, value:len() do
            self:writeString(i, value)
        end

    -- MEMSET A NUMBER
    elseif type(value) == "number" then
        assert(type(valType) == "string",
            "memset'ing a number requires that you specify the type of number")

        local func = ''
        local jump = nil
        valType = valType:lower()
        -- Shortcut cuz this will be easier
        if (valType == 'int8') or (valType == 'uint8') then
            func = 'UInt8'
            jump = 1
        else
            local sstr = ''
            -- GET SIGNED OR UNSIGNED
            if     (valType:sub(1,4) == 'uint') then func = 'UInt'
            elseif (valType:sub(1,3) == 'int')  then func = 'Int'
            end

            -- GET BIT WIDTH
            sstr = valType:sub(func:len()+1, func:len()+2)
            if     (sstr == '16') then func = func .. '16'; jump = 2
            elseif (sstr == '32') then func = func .. '32'; jump = 4
            end

            -- GET ENDIAN
            sstr = valType:sub(func:len()+1, func:len()+2)
            if     (sstr == 'le') then func = func .. 'LE'
            elseif (sstr == 'be') then func = func .. 'BE'
            end
        end

        func = self['write' .. func]
        if (func and type(func) == 'function') then
            for i = offset, size, jump do
                func(self, i, value)
            end
        else error("Cannot memset number value as the following type: " .. valType)
        end

    else
        error("Input value must be a string or number.")
    end
end

return Buffer
