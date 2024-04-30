-- Unicode
-- https://github.com/shewer/librime-lua-script/blob/main/lua/component/unicode.lua
local function unicode( input, seg, env )
    local ucodestr = seg:has_tag( 'unicode' ) and input:match( '`U([a-fA-F0-9]+)' )
    if ucodestr and #ucodestr > 1 then
        local code = tonumber( ucodestr:lower(), 16 )
        if code < 0 or code > 0x10FFFF then return end
        local text = utf8.char( code )
        yield( Candidate( 'unicode', seg.start, seg._end, text, '' ) )
        if code < 0x10000 then
            for i = 0, 15 do
                local text = utf8.char( code * 16 + i )
                yield( Candidate( 'unicode', seg.start, seg._end, text, '' ) )
            end
        end
    end
end

return unicode
