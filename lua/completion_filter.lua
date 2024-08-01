local F = {}

function F.func( input, env )
    local input_code = env.engine.context.input -- 输入的编码
    local completion_cand_count = 0
    local disable_completion = env.engine.context:get_option( 'completion' )

    for cand in input:iter() do
        local type = cand.type -- 类型
        local text = cand.text -- 候选文字

        -- 汉语多音节补全，个数限定为 1；且提供开关
        if type == 'completion' and not text:find( '%a' ) then
            completion_cand_count = completion_cand_count + 1
            if disable_completion or completion_cand_count > 1 then goto skip end
        end

        -- 删除用标点开头的候选
        if input_code:find( '^%p' ) and text:find( '^[%p]' ) and type == 'completion' then goto skip end

        yield( cand )
        ::skip::
    end
end

function F.tags_match( seg, env ) if seg.tags['abc'] then return true end end

return F
