-- 中文或者英文后，再输入英文单词自动添加空格
local F = {}

local function add_spaces( s )
    -- 在中文字符后和英文字符前插入空格
    s = s:gsub( '([\228-\233][\128-\191]-)([%w%p])', '%1 %2' )
    -- 在英文字符后和中文字符前插入空格
    s = s:gsub( '([%w%p])([\228-\233][\128-\191]-)', '%1 %2' )
    return s
end

-- 是否同时包含中文和英文数字
local function is_mixed_cn_en_num( s ) return s:find( '([\228-\233][\128-\191]-)' ) and s:find( '[%a%d]' ) end

function F.init( env )
    env.cn_punct = Set(
                       {
            '。', '，', '；', '？', '：', '—', '！', '《', '》', '‘', '’', '“', '”', '、', '¥',
            '…', '（', '）', '【', '】', '「', '」', '『', '』',
        }
                    )
    env.commit_notifier = env.engine.context.commit_notifier:connect(
                              function( ctx )
            local cand = ctx:get_selected_candidate()
            if cand and cand.type == 'en_spacer' then
                env.add_space = true
            elseif env.add_space then
                env.add_space = false
            end
        end
                           )
end

function F.func( input, env )
    local if_disabled = env.engine.context:get_option( 'en_spacer' )
    if if_disabled then
        for cand in input:iter() do yield( cand ) end
        return
    end

    local latest_text = env.engine.context.commit_history:latest_text()
    if latest_text and #latest_text > 0 and not latest_text:find( '[%p%s]$' ) and not env.cn_punct[latest_text] then
        for cand in input:iter() do
            if cand.text:match( "^[%a][%a:_./'%-]*$" ) then
                cand = cand:to_shadow_candidate( 'en_spacer', cand.text:gsub( '.*', ' %1' ), cand.comment )
            elseif env.add_space or latest_text:match( "^[%a][%a:_./'%-]*$" ) or latest_text:match('%d$') then
                if not cand.text:find( '[%p%s]$' ) and not env.cn_punct[cand.text] then
                    cand = cand:to_shadow_candidate( cand.type, cand.text:gsub( '.*', ' %1' ), cand.comment )
                end
            end
            if is_mixed_cn_en_num( cand.text ) then
                cand = cand:to_shadow_candidate( cand.type, add_spaces( cand.text ), cand.comment )
            end
            yield( cand )
        end
    else
        for cand in input:iter() do
            if is_mixed_cn_en_num( cand.text ) then
                cand = cand:to_shadow_candidate( cand.type, add_spaces( cand.text ), cand.comment )
            end
            yield( cand )
        end
    end
end

function F.fini( env ) env.commit_notifier:disconnect() end

return F
