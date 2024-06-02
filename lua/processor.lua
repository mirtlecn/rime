local P = {}

-- 处理提供的规则，用了特殊符号搭桥
local function c( s )
    s = s:gsub( '%%(%w)', '➋%1' )
    s = s:gsub( '(%w)%-(%w)', '%1➌%2' )
    s = s:gsub( '([%.%+%-%*%?%[%]%^%$%(%)%%])', '%%%1' )
    s = s:gsub( [[\\]], [[/]] )
    s = s:gsub( '➋', '%%' )
    s = s:gsub( '➌', '-' )
    -- log.error(s)
    return s
end

-- 提取规则中的文本
local function r( s ) return s:gsub( '^' .. '%%%%', '' ):gsub( ' %d+$', '' ) end

-- 判断是否符合自定义规则
local function r_match( str, pattern )
    if pattern:find( '^%%%%' ) then
        return str:find( '[' .. c( r( pattern ) ) .. ']$' )
    else
        return str:find( c( r( pattern ) ) .. '$' )
    end
    return false
end

-- 判断是否以中文结尾
local function endsWithChinese( str )
    -- 使用UTF-8编码，中文字符的最高位二进制表示是"110"
    local pattern = '[\xe4-\xe9][\x80-\xbf]+$'
    -- 使用string.match函数检查字符串是否以中文结尾
    return string.match( str, pattern )
end

-- 不处理的按键序列
local function except( s )
    if s:find( 'BackSpace%|BackSpace' ) then -- 按下两次退格
        return true
    elseif s:find( 'Control%+a%|BackSpace' ) then -- 全选退格
        return true
    end
    return false
end

function P.init( env )

    env.KEYTABLE = {}
    env.COMMITHISTTORY = {}
    env.KEYS = ''
    env.COMMITHISTTORY[2] = ''
    env.COMMITHISTTORY[0] = ''
    env.COMMITHISTTORY[1] = ''

    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub( '^*', '' )
    env.history_key = config:get_string( env.name_space .. '/commit_history_key' ) or ''
    env.search_key = config:get_string( 'key_binder/search' ) or config:get_string( env.name_space .. '/key' )
    env.debug = config:get_bool( env.name_space .. '/debug' )

    env.first_key = config:get_string( 'key_binder/select_first_character' )
    env.last_key = config:get_string( 'key_binder/select_last_character' )
    env.length_limit = config:get_int( env.name_space .. '/length_limit' ) or 50

    -- 检测到相关按键，推入一个空历史，重置输入状态
    local key_list = config:get_list( env.name_space .. '/clear_history_key' )
    env.key_list = Set( { 'Up', 'Down', 'Escape', 'Shift+Return', 'Tab', 'Shift+Tab', 'Control+BackSpace' } )
    if key_list then
        for i = 0, key_list.size - 1 do
            local k = key_list:get_value_at( i ).value
            if k and #k > 0 then env.key_list[k] = true end
        end
    end

    -- 中文后的符号转换规则，和 rime 的算法规则一致
    local cn_rules = config:get_list( env.name_space .. '/cn_rules' )
    if cn_rules then
        env.projection = Projection()
        env.projection:load( cn_rules )
    end

    -- ascii/[历史字符]/按键/
    local list = config:get_list( env.name_space .. '/ascii_rules' )
    if list then
        env.ascii = {}
        env.commit = ''
        for i = 0, list.size - 1 do
            local configString = list:get_value_at( i ).value
            local key, value = configString:match( '^ascii/(.*)/(.*)/$' )
            -- log.warning(key .. ' | ' .. value)
            if key and value and #key > 0 and #value > 0 then
                key = c( key )
                value = c( value )
                env.ascii[key] = value
                -- log.warning(key .. ' = ' .. value)
            elseif key and value and #key == 0 and #value > 0 then
                env.commit = env.commit .. value
            end
        end
        if #env.commit > 0 then
            env.commit = '[' .. c( env.commit ) .. ']'
        else
            env.commit = nil
        end
    end

    -- # fnr/历史字符/按键/上屏内容/
    local c_rules = config:get_list( env.name_space .. '/custom_rules' )
    if c_rules then
        -- 设置三个表，绕开 utf-8 处理的麻烦
        env.c_rules_match = {}
        env.c_rules = {}
        env.match = '' -- 方便先匹配一次
        for i = 0, c_rules.size - 1 do
            local configString = c_rules:get_value_at( i ).value
            local m, k, v = configString:match( '^fnr/(.+)/(.+)/(.+)/$' )
            if m and k and v and #m > 0 and #k > 0 and #v > 0 then
                m = m:gsub( [[\\]], [[/]] )
                k = k:gsub( [[\\]], [[/]] )
                v = v:gsub( [[\\]], [[/]] )
                -- log.error( m .. k .. v)
                env.match = env.match .. m:gsub( '^%%%%', '' )
                m = m .. ' ' .. i -- 添加 i 以标记不同的规则
                k = k .. ' ' .. i
                env.c_rules_match[m] = k
                env.c_rules[k] = v
            end
        end
        env.match = '[' .. c( env.match ) .. ']'
        -- log.error(env.match)
    end

    -- 判断是否无规则
    if not list and not cn_rules and c_rules then env.no_rules = true end
end

function P.func( key, env )
    local engine = env.engine
    local context = env.engine.context
    local latest_text = context.commit_history:latest_text()
    -- 获取当前的 key 所代表的符号，只处理字母和符号区域的按键
    local ascii_str = ''
    local input = context.input
    if key.keycode > 0x20 and key.keycode < 0x7f then ascii_str = string.char( key.keycode ) end

    if env.history_key and #env.history_key > 0 and input:find( '^' .. env.history_key .. '$' ) then
        context:clear()
        env.engine:commit_text( env.COMMITHISTTORY[2] )
        return 1
    end

    if not key:release() and (context:is_composing() or context:has_menu()) then
        -- 限制输入长度
        if (string.len( input ) > env.length_limit) then
            context:pop_input( 1 )
            return 1
        end

        if nil then
        elseif key:repr() == 'Escape' or key:repr() == 'Control+c' then
            context:clear()
            return 1
            -- elseif input:find('^%.$') and ascii_str == '.' then
            --     env.engine:process_key(KeyEvent("Down"))
            --     return 1
            -- elseif input:find( '^%_$' ) and ascii_str == '_' then
            --     env.engine:process_key( KeyEvent( 'Down' ) )
            --     return 1
        elseif env.search_key and #env.search_key > 0 and input:find( '^[a-z;]+' .. env.search_key .. '.*' .. env.search_key ) and
            ascii_str == env.search_key then
            return 1
        end

        -- 以词定字
        local text = input
        if context:get_selected_candidate() then text = context:get_selected_candidate().text end
        if utf8.len( text ) and utf8.len( text ) > 1 then
            local a = text:sub( 1, utf8.offset( text, 2 ) - 1 )
            local b = text:sub( utf8.offset( text, -1 ) )
            if (key:repr() == env.first_key or key:repr()=='Home') then
                engine:commit_text( a )
                context:clear()
                return 1
            elseif (key:repr() == env.last_key or key:repr()=='End') then
                engine:commit_text( b )
                context:clear()
                return 1
            end
        elseif utf8.len( text ) and utf8.len( text ) == 1 then
            if (key:repr() == env.first_key) or (key:repr() == env.last_key or key:repr()=='End' or key:repr()=='Home') then
                engine:commit_text( text )
                context:clear()
                return 1
            end
        end
    end

    -- 以下规则，不处理释放按键事件、编码或有菜单时也不处理
    if key:release() or context:is_composing() or context:has_menu() then return 2 end

    -- 记录最近三个按键和两个提交记录，
    -- 用于规避空格、退格清空历史，作用为，按下退格后，仍使用退格前的提交判断
    local Pattern = '.+%|BackSpace'
    -- key|space|BackSpace
    if env.KEYS:find( '%|' .. Pattern .. '$' ) and not except( env.KEYS ) then latest_text = env.COMMITHISTTORY[1] end
    -- space|BackSpace|Shift+Shift_L：这是以 Shift 引导的按键
    if env.KEYS:find( '^' .. Pattern .. '%|Shift' ) and not except( env.KEYS ) then
        latest_text = env.COMMITHISTTORY[0]
    end

    -- 词组处理，如果输入了中英文词组，将最后一个字符视为历史提交
    if utf8.len( latest_text ) > 1 then
        env.COMMITHISTTORY[0] = latest_text:sub( utf8.offset( latest_text, -1 ) )
        local latest_text_re = latest_text:gsub( env.COMMITHISTTORY[0] .. '$','')
        env.COMMITHISTTORY[1] = latest_text_re:sub( utf8.offset( latest_text_re, -1 ) )
    else
        env.COMMITHISTTORY[1] = env.COMMITHISTTORY[0] or ''
        env.COMMITHISTTORY[0] = latest_text
    end

    if (env.COMMITHISTTORY[0] and #env.COMMITHISTTORY[0] > 0 and env.COMMITHISTTORY[0] ~= ' ') then
        env.COMMITHISTTORY[2] = env.COMMITHISTTORY[0]
    end

    env.KEYTABLE[2] = env.KEYTABLE[1] or '-' -- 赋值以规避 error log 的产生
    env.KEYTABLE[1] = env.KEYTABLE[0] or '-'
    env.KEYTABLE[0] = key:repr() or '-'
    env.KEYS = env.KEYTABLE[2] .. '|' .. env.KEYTABLE[1] .. '|' .. env.KEYTABLE[0]

    if env.debug then
        -- log.warning('history Liter: ' .. context.commit_history:repr())
        -- log.warning('latest_text: ' .. context.commit_history:latest_text())
        log.warning( 'KEYS_sequence: ' .. env.KEYS )
        log.warning( 'COMMITHISTTORY: ' .. env.COMMITHISTTORY[0] .. '|' .. env.COMMITHISTTORY[1] )
        -- log.warning('key_string: ' .. ascii_str)
    end

    -- 检测到相关按键，推入一个空历史，重置输入状态
    if env.key_list and env.key_list[key:repr()] then context.commit_history:push( 'lua', '' ) end

    -- 下面开始处理按键规则

    -- 无论如何，直接上屏的按键
    if key:ctrl() or key:alt() or key:super() then -- 不处理按下 ctrl() alt() 或者 super()
        return 2
    else
        -- if env.commit and env.commit[ascii_str] then
        if env.commit and ascii_str:find( env.commit ) then
            env.engine:commit_text( ascii_str )
            return 1
        end
    end

    -- 不处理的情况
    if env.no_rules -- 不指定规则
    -- or key:ctrl() or key:alt() or key:super() -- 按下 ctrl() alt() 或者 super()
    or #ascii_str == 0 -- 无按键
    or #latest_text == 0 -- 上一次输入未记住
    or (latest_text:find( '^%s+$' )) -- 上一次输入了空字符串
    then return 2 end

    -- 首先处理自定义规则
    if env.c_rules_match and env.c_rules and latest_text:find( env.match ) then
        for m, v in pairs( env.c_rules_match ) do
            if r_match( latest_text, m ) and r_match( ascii_str, v ) then
                local str = env.c_rules[v]
                if str:find( '^%%%%1' ) then
                    return 1 -- 禁用
                elseif str:find( '^%%%%0' ) then
                    return 0 -- 停止处理，让系统处理
                elseif str:find( '^%%%%2' ) then
                    return 2 -- 放行
                else
                    env.engine:commit_text( str )
                    return 1
                end
            end
        end
    end

    -- 处理中文规则：有相关规则；上一次以中文结尾；输入的为标点
    if env.projection and endsWithChinese( latest_text ) and not ascii_str:find( '%w' ) then
        -- log.error('key: ' .. ascii_str .. ' c: ' .. env.projection:apply(ascii_str))
        local c = env.projection:apply( ascii_str )
        if c and c ~= '' then
            env.engine:commit_text( c )
            return 1
        end
    end

    -- 处理 ascii 规则
    if not env.ascii then return 2 end
    for k, v in pairs( env.ascii ) do
        if latest_text:match( '[' .. k .. ']$' ) and ascii_str:match( '[' .. v .. ']' ) then
            -- 一种解决办法，直接用 commit_text 方法
            env.engine:commit_text( ascii_str )
            return 1

            -- 当 return 0 使用系统处理按键时
            -- 含有 Shift 键的键顶掉历史，因而获取到的记录将为空，可以手动推进去
            -- if ascii_str:find('[{(<>)}]') then
            --     context.commit_history:push(env.engine.context.composition, ascii_str)
            -- end
            -- return 0
        end
    end
    return 2
end

function P.fini( env )
    -- 清空
    env.KEYTABLE = nil
    env.COMMITHISTTORY = nil
end

return P
