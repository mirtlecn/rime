-- Copyright (C) Mirtle
-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)
local function alt_lua_punc( s )
    if s then
        return s:gsub( '([%.%+%-%*%?%[%]%^%$%(%)%%])', '%%%1' )
    else
        return ''
    end
end

local T = {}

function T.init( env )
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub( '^*', '' )

    local schema_name = config:get_string( env.name_space .. '/dict' )
    if schema_name then T.mem = Memory( env.engine, Schema( schema_name ) ) end
    if not T.mem then return end

    T.allcase_comment = config:get_bool( env.name_space .. '/case_tip_always_on' )
    T.disable_comment = config:get_bool( env.name_space .. '/disable_comment' )
    T.update_userdict = config:get_bool( env.name_space .. '/update_userdict' )
    T.skip_when_find = alt_lua_punc( config:get_string( env.name_space .. '/ignore_string' ) )

end

function T.gen_cand( cand_text, cand_code, cand_comment, case_tips_on, seg )
    if T.update_userdict then
        local dict_entry = DictEntry()
        dict_entry.text = cand_text
        dict_entry.custom_code = cand_code .. ' '
        if #cand_comment > 0 and (T.allcase_comment or case_tips_on) then
            dict_entry.comment = cand_comment
        elseif T.disable_comment then
            dict_entry.comment = ''
            -- else -> return auto generated comment
        end
        return Phrase( T.mem, 'autocap', seg.start, seg._end, dict_entry ):toCandidate()
    else
        --- Candidate(type, start, end, text, comment)
        local cmt
        if #cand_comment > 0 and (T.allcase_comment or case_tips_on) then
            cmt = cand_comment
        elseif T.disable_comment then
            cmt = ''
            -- else -> return auto generated comment
        end
        return Candidate( 'autocap', seg.start, seg._end, cand_text, cmt )
    end

end

-- 自动大小写
function T.func( inp, seg, env )

    if not T.mem then return end

    local inputAllCase = false
    local inputCase = false
    local inputLowerCase = false
    local search_code = inp:lower()
    local input_code = env.engine.context.input
    local commit_text = env.engine.context:get_commit_text()

    if T.skip_when_find and T.skip_when_find ~= '' and input_code:find( '^[' .. T.skip_when_find .. ']' ) then return end

    -- if input_code ~= commit_text then return end

    if #inp == 1 then
        return
    elseif inp == inp:lower() then
        inputLowerCase = true
    elseif inp == inp:upper() then
        inputAllCase = true
    elseif inp:find( '^[0-9]*[A-Z]' ) then
        inputCase = true
    else
        return
    end

    local case_tips_on = env.engine.context:get_option( 'case_tips' )
    local pureInp = inp:gsub( '[%s%p]', '' )

    T.mem:dict_lookup( search_code, true, 100 )
    for dictentry in T.mem:iter_dict() do
        local text = dictentry.text
        local pureText = text:gsub( '[%s%p]', '' )
        local code = table.concat( T.mem:decode( dictentry.code ), '' )
        local upperCode = code:upper()

        if pureText:find( '^' .. pureInp ) or ((not code:find( '%d' )) and code == upperCode and (not inputLowerCase)) then
            -- or ( inputLowerCase and code == code:lower())
            goto continue
        end

        local cand
        if inputLowerCase and code:find( '%u' ) then
            cand = T.gen_cand( text:lower(), text:lower(), text, case_tips_on, seg )
        elseif inputAllCase then
            cand = T.gen_cand( text:upper(), upperCode, text, case_tips_on, seg )
        elseif inputCase and not pureText:find( '^%u' ) then
            local cand_text = text:gsub( '^%a', string.upper )
            local cand_code = code:gsub( '^%a', string.upper )
            cand = T.gen_cand( cand_text, cand_code, '', false, seg )
        else
            goto continue
        end
        yield( cand )
        ::continue::
    end
end

return T
