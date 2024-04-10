-- Copyright (C) Mirtle
-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)

-- 将此翻译器放在最后，让产生的候选排序在后面
-- 请将 translator 中设定 initial_quality 为 1 以上
-- 转义特殊字符
local function alt_lua_punc( s )
    if s then
        return s:gsub( '([%.%+%-%*%?%[%]%^%$%(%)%%])', '%%%1' )
    else
        return ''
    end
end

-- 主函数
local echo = {}

-- 读取设置
-- parrot_translator:
--     always_on: bool # 是否始终开启此翻译器
--     remove_punct:   # 在编码中删除这些符号
--     comment:        # 注释
--     space_pattern:  # 用以替代空格的符号（特殊字符需要 % 转义）
--     schema:         # 操作的方案（用户词典写入的方案）
function echo.init( env )
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub( '^*', '' )

    echo.always_on = config:get_bool( env.name_space .. '/always_on' )
    echo.remove_punct = alt_lua_punc( config:get_string( env.name_space .. '/remove_punct' ) ) or ''
    echo.comment = config:get_string( env.name_space .. '/comment' ) or '+'
    echo.space_pattern = alt_lua_punc( config:get_string( env.name_space .. '/space_alt' ) ) or '%.%.'
    echo.skip_when_find = alt_lua_punc( config:get_string( env.name_space .. '/ignore_string' ) )

    local schema_name = config:get_string( env.name_space .. '/schema' )
    if schema_name then
        env.mem = Memory( env.engine, Schema( schema_name ) )
    else
        env.mem = Memory( env.engine, env.engine.schema )
    end
    if env.mem.dict then env.dict = env.mem.dict end

    local list = config:get_list( env.name_space .. '/ignore_pattern' )
    if not list then return end
    echo.ignore_pattern = {}
    for i = 0, list.size - 1 do
        local v = list:get_value_at( i ).value
        if v then table.insert( echo.ignore_pattern, v ) end
    end
end

function echo.change_inp( s )
    s = s:gsub( echo.space_pattern, ' ' )
    return s:gsub( '[%s' .. echo.remove_punct .. ']', '' )
end

function echo.get_match_input( s ) return s:gsub( echo.space_pattern, ' ' ) end

function echo.if_skip_echo( s )
    if s:find( '^%p' ) then
        return true -- 以标点开头
    elseif (s:find( '%p$' ) and not s:find( echo.space_pattern .. '$' )) then
        return true -- 以标点结尾
        -- elseif s:find("%d") then
        --     return true -- 有数字
    elseif echo.skip_when_find and #echo.skip_when_find > 0 and s:find( '[' .. echo.skip_when_find .. ']' ) then
        return true
    elseif echo.ignore_pattern then
        for i, v in ipairs( echo.ignore_pattern ) do if s:match( v ) then return true end end
    else
        return false
    end
end

function echo.new_dictentry( text, code, cmt )
    if not cmt then cmt = echo.comment end
    local DictEntry = DictEntry()
    DictEntry.text = text
    DictEntry.custom_code = code .. ' '
    DictEntry.comment = cmt
    DictEntry.preedit = text
    return DictEntry
end

function echo.func( inp, seg, env )
    local input_code = env.engine.context.input
    local commit_text = env.engine.context:get_commit_text()
    local is_open = env.engine.context:get_option( 'parrot_translator' )
    local with_space_alt = inp:find( '^.+' .. echo.space_pattern )
    local input = echo.change_inp( inp )
    local match = echo.get_match_input( inp )

    -- if commit_text ~= input_code then return end

    if inp:find( '%p' ) then
        if env.mem:user_lookup( inp, true ) then
            for entry in env.mem:iter_user() do
                entry.comment = ''
                yield( Phrase( env.mem, 'echo', seg.start, seg._end, entry ):toCandidate() )
            end
        end
        if env.mem:dict_lookup( inp, true, 100 ) then
            for entry in env.mem:iter_dict() do
                entry.comment = ''
                yield( Phrase( env.mem, 'echo', seg.start, seg._end, entry ):toCandidate() )
            end
        end
    end

    if with_space_alt then goto echo_phrase_with_space_start end

    if (not is_open) and (not echo.always_on) then return end

    ::echo_phrase_with_space_start::
    -- input 是去除空格和符号（用户指定的除外）的编码

    -- 如果含有空格替换符，检索用户词典，上屏含空格的词组
    if not inp:find( echo.space_pattern ) then goto echo_phrase_with_space_done end

    if env.mem:user_lookup( input, true ) then
        for entry in env.mem:iter_user() do
            if entry.text:find( '^' .. match ) then
                entry.comment = ''
                -- entry.comment = '&'
                yield( Phrase( env.mem, 'echo', seg.start, seg._end, entry ):toCandidate() )
            end
        end
    end
    if env.mem:dict_lookup( input, true, 100 ) then
        for entry in env.mem:iter_dict() do
            if entry.text:find( '^' .. match ) or entry.text:lower():find( '^' .. match ) then
                entry.comment = ''
                -- entry.comment = '&'
                yield( Phrase( env.mem, 'echo', seg.start, seg._end, entry ):toCandidate() )
            end
        end
    end
    ::echo_phrase_with_space_done::

    if (not is_open) and (not echo.always_on) then return end

    -- 学舌功能：开始
    -- inp 满足一定条件不学舌
    if echo.if_skip_echo( input_code ) then return end

    -- dict_lookup function refactor in <https://github.com/hchunhui/librime-lua/commit/474b9d95e94e59af3e6d7f7c1b306bce6dae1b62>

    -- local i = 0
    -- -- in newer librime-lua, env.mem:dict_lookup(inp, false, 1) will always return an object
    -- if env.dict then
    --     for e in env.dict:lookup_words(inp, false, 1):iter() do
    --         i = 1
    --     end
    -- else
    --     if env.mem:dict_lookup(inp, false, 1) then
    --         i = 1
    --     end
    -- end

    -- local do_echo = true
    -- local dict_lookup = env.mem:dict_lookup(inp, false, 2)
    -- if dict_lookup then
    --     for dictentry in env.mem:iter_dict() do
    --         local text = dictentry.text
    --         if text:find('^' .. match) then
    --             do_echo = false
    --         end
    --     end
    -- end

    -- can not find matched DictEntry then make new one
    -- if not env.mem:dict_lookup(inp, false, 1) then
    -- if do_echo then
    local candTable = {}
    -- candidate with space
    local dict = echo.new_dictentry( inp:gsub( echo.space_pattern, ' ' ), input )
    table.insert( candTable, dict )
    -- candidate with auto inserted space before cap-letter
    if inp:find( '%l%u+' ) then
        local candText = inp:gsub( echo.space_pattern, ' ' ):gsub( '(%l)(%u+)', '%1 %2' ):gsub( '  ', ' ' )
        local dict2 = echo.new_dictentry( candText, input )
        table.insert( candTable, dict2 )
    end
    -- origin input as candidate
    if inp:find( echo.space_pattern ) then
        local dict3 = echo.new_dictentry( inp, input )
        table.insert( candTable, dict3 )
    end
    -- yield candidate
    for i, entry in ipairs( candTable ) do
        local ph = Phrase( env.mem, 'echo', seg.start, seg._end, entry )
        yield( ph:toCandidate() )
    end
    -- end
end
return echo
