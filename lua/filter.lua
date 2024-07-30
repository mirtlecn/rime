local F = {}

local function update_dict_entry( text, code, mem )
    if #text == 0 then return end
    local e = DictEntry()
    e.text = text
    e.custom_code = code .. ' '
    if mem.start_session then mem:start_session() end -- new on librime 2024.05
    mem:update_userdict( e, 1, '' )
    if mem.finish_session then mem:finish_session() end -- new on librime 2024.05
end

function F.init( env )
    local config = env.engine.schema.config
    env.name_space = env.name_space:gsub( '^*', '' )

    env.show_in_comment = config:get_list( env.name_space .. '/show_in_comment' )
    if env.show_in_comment then return end
    env.mark_user_dict = config:get_bool( env.name_space .. '/mark_user_dict' )
    env.recode_cn_en = config:get_bool( env.name_space .. '/recode_cn_en' )
    if env.recode_cn_en then
        local schema = config:get_string( env.name_space .. '/en_schema' ) or 'en'
        env.mem = Memory( env.engine, Schema( schema ) )
    end

    local cmt_list = config:get_list( env.name_space .. '/comment_format' )
    if cmt_list then
        env.projection = Projection()
        env.projection:load( cmt_list )
    end

    if env.recode_cn_en and env.mem then
        env.commit_notifier = env.engine.context.commit_notifier:connect(
                                  function( ctx )
                local cand = ctx:get_selected_candidate()
                local commit_text = ctx:get_commit_text()
                local commit_code = ctx.input:gsub( '%s', '' )
                if (cand and cand.text == commit_text) then
                    -- 直选，上屏了一个候选
                    if (cand.type == 'sentence' or cand.type == 'raw') and
                        ((commit_text:find( '%a' ) and commit_text:find( '%d' )) or (commit_text:find( '^%a+$' ))) then
                        log.info( '- record: ' .. commit_text )
                        update_dict_entry( commit_text, commit_code, env.mem )
                    end
                elseif (cand and cand.text ~= commit_text) then
                    -- 多个候选的组合
                    if (utf8.len( commit_text ) ~= #commit_text and commit_text:find( '%a' )) then
                        log.info( '+ record: ' .. commit_text )
                        update_dict_entry( commit_text, commit_code, env.mem )
                    end
                else
                    return
                end
            end
                               )
    end
end

function F.func( input, env )
    -- local example = env.engine.context:get_option("example")
    local input_code = env.engine.context.input -- 输入的编码
    -- local codeLen = #input_code -- 输入码的长
    -- local commit_text = env.engine.context:get_commit_text()
    -- local index = 0 -- 候选排列次序
    local completion_cand_count = 0
    local disable_completion = env.engine.context:get_option( 'completion' )

    for cand in input:iter() do
        local type = cand.type -- 类型
        local text = cand.text -- 候选文字
        local search_text = text:gsub( '%s', '' )
        -- local preedit = cand.preedit -- preedit 后的编码
        -- local index = index + 1

        -- 汉语多音节补全，个数限定为 1；且提供开关
        if type == 'completion' and not text:find( '%a' ) then
            completion_cand_count = completion_cand_count + 1
            if disable_completion or completion_cand_count > 1 then
                goto skip
            end
        end

        -- 用作在注释中显示候选的各种信息
        if env.show_in_comment then
            local list = env.show_in_comment
            local info = '/' .. 'input: ' .. input_code
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

        -- 给用户词标记
        if env.mark_user_dict and (type == 'user_phrase' or type == 'user_table') then
            cand.comment = cand.comment .. '^'
        end

        -- 给所有的注释加上特定的字符
        if env.projection and cand.comment and #cand.comment > 0 then
            if cand:get_dynamic_type() == 'Shadow' then
                cand = ShadowCandidate( cand:get_genuine(), type, text, env.projection:apply( cand.comment, true ) )
            else
                cand.comment = env.projection:apply( cand.comment, true )
            end
        end

        ::yield::
        yield( cand )
        ::skip::
    end
end

function F.fini( env )
    if env.recode_cn_en and env.mem then
        env.commit_notifier:disconnect()
        env.mem = nil
        collectgarbage( 'collect' )
    end
end

return F
