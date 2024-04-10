-- Copyright (C) Mirtle
-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)

local s = {}

function s.init( env )
    s.t = { '1', '2', '3', '4', '5', '6', '7', '8', '9', '0' }
    s.t_2 = { 'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12' }
    for i, v in ipairs( s.t ) do s.t[v] = i - 1 end
    for i, v in ipairs( s.t_2 ) do s.t_2[v] = i - 1 end
    s.kb = { 'KP_0', 'KP_1', 'KP_2', 'KP_3', 'KP_4', 'KP_5', 'KP_6', 'KP_7', 'KP_8', 'KP_9' }
    for i, v in ipairs( s.kb ) do s.kb[v] = i - 1 end

    s.number = {
        'Control+1', 'Control+2', 'Control+3', 'Control+4', 'Control+5', 'Control+6', 'Control+7', 'Control+8',
        'Control+9', 'Control+0',
    }
    for _, v in ipairs( s.number ) do s.number[v] = v:gsub( 'Control%+', '' ) end
end

function s.func( key, env )
    if key:release() or key:alt() or key:super() then
        return 2 -- kNoop
    end
    local key_sequence = key:repr()
    local context = env.engine.context

    if context:is_composing() and s.number[key_sequence] then
        context.input = context.input .. s.number[key_sequence]
        return 1
    end

    if key:ctrl() then return 2 end
    local i = s.t[key_sequence]
    local i_2 = s.t_2[key_sequence]

    if context:has_menu() then
        if i then
            context:select( i )
            return 1
        elseif i_2 then
            context:select( i_2 )
            return 1
        end
    end

    local num = s.kb[key_sequence]
    if context:is_composing() and num then
        context:commit()
        context:commit_text( num )
        return 1
    end

    return 2
end

return s
