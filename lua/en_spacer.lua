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
    env.cn_punct = Set({'。', '，', '；', '？', '：', '—', '！', '《', '》', '‘', '’', '“', '”', '、', '¥','…', '（', '）', '【', '】', '「', '」', '『', '』',})
    env.commit_notifier = env.engine.context.commit_notifier:connect(
                              function( ctx )
            local cand = ctx:get_selected_candidate()
            -- 上屏后，重置候选项的 en_spacer 属性
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
    local input_code = env.engine.context.input
    local commit_text = env.engine.context:get_commit_text()

    -- 在候选中添加前置空格的前提条件
    -- 1. （避免造词的情况）输入码和上屏的编码相同
    -- 2. （避免候选在句首的情况）上一次的输入编码不为空，且不是 nil，不是空字符、标点、特定中文标点（en.cn_punct）
    if input_code == commit_text and latest_text and #latest_text > 0 and not latest_text:find( '%s$' ) and
        not latest_text:match( '%p$' ) and not env.cn_punct[latest_text] then
        for cand in input:iter() do
            -- 前面自动添加空格，为候选添加 en_spacer 属性，让它的后面也加空格
            -- 条件：**完全**由英文/数字/特定符号组成的候选

            -- 只前置空格，后面不需要空格
            -- 条件：
            -- * 上一次上屏的是 en_spacer 属性的候选
            -- * （英文+中文的中英混合词「X轴」、「AAA级」）候选以英文数字开头，以非英文、数字、符号结尾
            -- * 上一次上屏的是候选文本是以英文数字或者符号结尾（例如：中文+英文混合词，「大A」、「嫌疑人X」）
            -- * 上一次上屏的是候选文本是以数字结尾（「相约1998」）
            if cand.text:match( '^[%w][%w:_./\'%-]*$' ) then
                cand = cand:to_shadow_candidate( 'en_spacer', cand.text:gsub( '.*', ' %1' ), cand.comment )
            elseif env.add_space or cand.text:match( '^[%w][%w:_./\'%-]*[^%w%p]+$' ) or
                latest_text:match( '[%w][%w:_./\'%-]*$' ) or latest_text:match( '%d$' ) then
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
