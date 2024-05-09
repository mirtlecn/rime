-- 需要将将此翻译器放在最后，让产生的候选排序在后面，
-- 请将 translator 中设定 initial_quality 为 1 以上，保证去重 filter 删除此翻译器产生的重复候选
local function alt_lua_punc( str )
    -- 转义特殊字符
    if str then
        return str:gsub( '([%.%+%-%*%?%[%]%^%$%(%)%%])', '%%%1' )
    else
        return ''
    end
end

local function if_skip_echo( s, space_pattern, skip_when_find, ignore_pattern )
    -- - 如果输入码满足一定条件，不学舌
    --     - 以标点开头
    --     - 以标点结尾
    --     - 含有用户指定的字符或者符合用户指定的正则表达式
    if s:find( '^%p' ) then
        return true -- 以标点开头
    elseif (s:find( '%p$' ) and not s:find( space_pattern .. '$' )) then
        return true -- 以标点结尾且不以空格替换符结尾
        -- elseif s:find("%d") then
        --     return true -- 有数字
    elseif skip_when_find and #skip_when_find > 0 and s:find( '[' .. skip_when_find .. ']' ) then
        return true
    elseif ignore_pattern and #ignore_pattern > 0 then
        for i, v in ipairs( ignore_pattern ) do if s:match( v ) then return true end end
    else
        return false
    end
end

local function new_dict_entry( text, code, cmt )
    -- 创建新的 dict_entry
    local dict_entry = DictEntry()
    dict_entry.text = text
    dict_entry.custom_code = code .. ' '
    if cmt then dict_entry.comment = cmt end
    dict_entry.preedit = text
    return dict_entry
end

local function yield_entry( mem, seg, inp, match )
    -- 直接上屏候选词
    if mem:user_lookup( inp, true ) then
        -- 上屏用户词典
        for entry in mem:iter_user() do
            if match and entry.text:find( '^' .. match ) then
                entry.comment = ''
                yield( Phrase( mem, 'echo', seg.start, seg._end, entry ):toCandidate() )
            elseif not match then
                entry.comment = ''
                yield( Phrase( mem, 'echo', seg.start, seg._end, entry ):toCandidate() )
            end
        end
    end
    if mem:dict_lookup( inp, true, 100 ) then
        -- 上屏固态词典
        for entry in mem:iter_dict() do
            if match and entry.text:find( '^' .. match ) or entry.text:lower():find( '^' .. match ) then
                entry.comment = ''
                yield( Phrase( mem, 'echo', seg.start, seg._end, entry ):toCandidate() )
            elseif not match then
                entry.comment = ''
                yield( Phrase( mem, 'echo', seg.start, seg._end, entry ):toCandidate() )
            end
        end
    end
end

local echo = {}

function echo.init( env )
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub( '^*', '' )
    local schema_name = config:get_string( env.name_space .. '/schema' )
    if not schema_name then return end

    -- 方案应当使用 table_translator，自用就不做检查了
    env.mem = Memory( env.engine, Schema( schema_name ) )
    env.always_on = config:get_bool( env.name_space .. '/always_on' )
    env.remove_punct = alt_lua_punc( config:get_string( env.name_space .. '/remove_punct' ) ) or ''
    env.comment = config:get_string( env.name_space .. '/comment' ) or '+'
    env.space_pattern = alt_lua_punc( config:get_string( env.name_space .. '/space_alt' ) ) or '~'
    env.skip_when_find = alt_lua_punc( config:get_string( env.name_space .. '/ignore_string' ) )
    local list = config:get_list( env.name_space .. '/ignore_pattern' )
    if list and #list > 0 then
        env.ignore_pattern = {}
        for i = 0, list.size - 1 do
            local v = list:get_value_at( i ).value
            if v then table.insert( env.ignore_pattern, v ) end
        end
    end
end

function echo.func( inp, seg, env )
    if not env.mem then return end

    -- match: 将空格还原
    -- input_code: 原始输入码，inp 会删掉 reverse_lookup_filter 的引导字符
    -- is_open: 是否启用此翻译器
    -- input: 将空格还原，删除标点和空白字符作为编码
    local match = inp:gsub( env.space_pattern, ' ' )
    local input_code = env.engine.context.input
    local is_open = env.engine.context:get_option( 'parrot_translator' )
    local input = inp:gsub( env.space_pattern, ' ' ):gsub( '[%s' .. env.remove_punct .. ']', '' )

    -- 造句时，不学舌
    -- local input_code = env.engine.context.input
    -- local commit_text = env.engine.context:get_commit_text()
    -- if commit_text ~= input_code then return end

    -- 如果输入码含有标点符号或者空格替换符号，检索用户词典，上屏所有词组
    if inp:find( '%p' ) then yield_entry( env.mem, seg, inp ) end
    if inp:find( '^.+' .. env.space_pattern ) then yield_entry( env.mem, seg, input, match ) end

    -- 如果启用了此翻译器且编码满足条件，生成新的候选词组
    if ((is_open or env.always_on) and
        not if_skip_echo( input_code, env.space_pattern, env.skip_when_find, env.ignore_pattern )) or
        (inp:find( env.space_pattern .. '$' ) and
            not if_skip_echo( input_code, env.space_pattern, env.skip_when_find, env.ignore_pattern )) then
        -- 生成新的候选词组
        local candTable = {}
        -- 将空格替换符替换为空格作为候选
        local dict = new_dict_entry( inp:gsub( env.space_pattern, ' ' ):gsub( '%s$', '' ), input, env.comment )
        table.insert( candTable, dict )
        -- 在大写字母前自动插入空格作为候选
        if inp:find( '%l%u+' ) then
            local dict2 = new_dict_entry(
                              inp:gsub( env.space_pattern, ' ' ):gsub( '(%l)(%u+)', '%1 %2' ):gsub( '  ', ' ' ), input,
                              env.comment
                           )
            table.insert( candTable, dict2 )
        end
        -- 原始编码作为候选
        if inp:find( env.space_pattern ) then
            local dict3 = new_dict_entry( inp, input, env.comment )
            table.insert( candTable, dict3 )
        end
        -- 上屏候选
        for i, entry in ipairs( candTable ) do
            local ph = Phrase( env.mem, 'echo', seg.start, seg._end, entry )
            local cand = ph:toCandidate()
            -- cand.quality = 99
            yield( cand )
        end
    end
end

function echo.fini( env )
    if env.mem then
        env.mem = nil
        collectgarbage( 'collect' )
    end
end

return echo
