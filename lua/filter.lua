-- 是否同时包含中文和英文数字
local function is_mixed_cn_en_num( s ) return s:find( '([\228-\233][\128-\191]-)' ) and s:find( '[%a%d]' ) end

-- 在中文字符后和英文字符前插入空格
-- 在英文字符后和中文字符前插入空格
local function add_spaces( s )
    s = s:gsub( '([\228-\233][\128-\191]-)([%w%p])', '%1 %2' )
    s = s:gsub( '([%w%p])([\228-\233][\128-\191]-)', '%1 %2' )
    return s
end

-- 在英文后添加空格
local function add_space_to_english_word( input )
    input = input:gsub( '(%a+\'?%a*)', '%1 ' )
    return input
end

local F = {}

function F.init( env )
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub( '^*', '' )

    F.show_in_comment = config:get_list( env.name_space .. '/show_in_comment' )
    if F.show_in_comment then return end
    F.add_space_cn_en = config:get_bool( env.name_space .. '/add_space_cn_en' )
    F.add_space_en = config:get_bool( env.name_space .. '/add_space_en' )
    F.mark_user_dict = config:get_bool( env.name_space .. '/mark_user_dict' )
    F.recode_cn_en = config:get_bool( env.name_space .. '/recode_cn_en' )
    local case_tip = config:get_bool( env.name_space .. '/case_tip' )
    if F.recode_cn_en or case_tip then
        local schema = config:get_string( env.name_space .. '/en_schema' ) or 'en'
        F.en_dict = Memory( env.engine, Schema( schema ) )
    end

    local cmt_list = config:get_list( env.name_space .. '/comment_format' )
    if cmt_list then
        F.projection = Projection()
        F.projection:load( cmt_list )
    end

    if F.recode_cn_en and F.en_dict then
        env.commit_notifier = env.engine.context.commit_notifier:connect(
                                  function( ctx )
                local cand = ctx:get_selected_candidate()
                local commit_text = ctx:get_commit_text()
                local commit_code = ctx.input

                if (cand and cand.text == commit_text) then
                    -- 直选，上屏了一个候选
                    if (cand.type == 'sentence' or cand.type == 'raw') and
                        ((commit_text:find( '%a' ) and commit_text:find( '%d' )) or (commit_text:find( '^%a+$' ))) then
                        log.info( '- record: ' .. commit_text )
                        F.update_dict_entry( commit_text, commit_code )
                    end
                elseif (cand and cand.text ~= commit_text) then
                    -- 多个候选的组合
                    if (utf8.len( commit_text ) ~= #commit_text and commit_text:find( '%a' )) then
                        log.info( '+ record: ' .. commit_text )
                        F.update_dict_entry( commit_text, commit_code )
                    end
                else
                    return
                end
            end
                               )
    end
end

function F.update_dict_entry( text, code )
    if #text == 0 then return end
    local e = DictEntry()
    e.text = text
    e.custom_code = code .. ' '
    F.en_dict:update_userdict( e, 1, '' )
end

function F.func( input, env )
    -- local example = env.engine.context:get_option("example")
    local input_code = env.engine.context.input -- 输入的编码
    -- local codeLen = #input_code -- 输入码的长
    -- local commit_text = env.engine.context:get_commit_text()
    -- local index = 0 -- 候选排列次序

    for cand in input:iter() do
        local type = cand.type -- 类型
        local text = cand.text -- 候选文字
        local search_text = text:gsub( '%s', '' )
        -- local preedit = cand.preedit -- preedit 后的编码
        -- local index = index + 1

        if (env.engine.context:get_option( 'completion' ) and not text:find( '%a' ) and type == 'completion') then
            goto skip
        end

        -- 用作在注释中显示候选的各种信息
        if F.show_in_comment then
            local list = F.show_in_comment
            local info = '/' .. 'input_code: ' .. input_code
            local key
            local value
            for i = 0, list.size - 1 do
                key = list:get_value_at( i ).value
                if key:find( '%(%)$' ) then
                    local func, err = load(
                                          'return cand:' .. key, nil, 't', {
                            cand = cand,
                         }
                                       )
                    if func then
                        value = func()
                    else
                        value = 'error'
                    end
                else
                    value = cand[key]
                end
                key = '/' .. key .. ': '
                info = info .. key .. value
            end
            cand.comment = cand.comment .. info
            goto yield
        end

        -- 删除用标点开头的候选
        if input_code:find( '^%p' ) and text:find( '^[%p]' ) and type == 'completion' then goto skip end

        -- case_tips
        if F.en_dict and env.engine.context:get_option( 'case_tips' ) and (type == 'user_table' or type == 'completion') and
            (text == text:lower() or text == text:upper()) and not F.en_dict:dict_lookup( search_text, false, 1 ) and
            F.en_dict:user_lookup( search_text, false ) then
            search_text = search_text:lower()
            if F.en_dict:dict_lookup( search_text, false, 1 ) then
                for e in F.en_dict:iter_dict() do
                    local code = table.concat( F.en_dict:decode( e.code ), '' )
                    cand.comment = code
                    break
                end
            end
        end

        -- 给用户词标记
        if F.mark_user_dict and type == 'user_phrase' then cand.comment = cand.comment .. '•' end

        -- 给所有的注释加上特定的字符
        if F.projection and cand.comment and #cand.comment > 0 then
            if cand:get_dynamic_type() == 'Shadow' then
                cand = ShadowCandidate( cand:get_genuine(), type, text, F.projection:apply( cand.comment, true ) )
            else
                cand.comment = F.projection:apply( cand.comment, true )
            end
        end

        -- 在英文后添加空格
        if F.add_space_en then
            if text:match( '^[%a\']+[%a\']*$' ) then
                text = add_space_to_english_word( text )
                cand = cand:to_shadow_candidate( type, text, cand.comment )
            end
        end

        -- 在中英文之间加空格
        if F.add_space_cn_en then
            if is_mixed_cn_en_num( text ) then
                text = add_spaces( text )
                cand = cand:to_shadow_candidate( type, text, cand.comment )
            end
        end

        ::yield::
        yield( cand )
        ::skip::
    end
end

function F.fina( env ) if F.recode_cn_en and F.en_dict then env.commit_notifier:disconnect() end end

return F
