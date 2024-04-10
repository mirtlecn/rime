-- Copyright (C) Mirtle
-- License: CC BY-SA 4.0 (https://creativecommons.org/licenses/by-sa/4.0/)
local F = {}

function F.init( env )
    -- local config = env.engine.schema.config
    -- env.name_space = env.name_space:gsub("^*", "")
    -- local option = config:get_string(env.name_space .. '/opencc_config') or 't2s.json'
    F.t2s = Opencc( 't2s.json' )
    -- F.tw2s = Opencc('tw2s.json')
end

function F.func( input, env )
    local reverse_simp = env.engine.context:get_option( 'reverse_simp' )
    -- local index = 0 -- 候选排列次序
    for cand in input:iter() do
        if reverse_simp then
            local oldText = cand.text -- 候选文字
            local newText = F.t2s:convert( oldText )
            -- newText = F.tw2s:convert(newText)
            if oldText == newText then
                yield( cand )
            else
                local cmt = oldText .. ' ' .. cand.comment
                local newCand = ShadowCandidate( cand, cand.type, newText, cmt )
                yield( newCand )
            end
        else
            yield( cand )
        end
    end
end

function F.tags_match( seg, env )
    if seg.tags['reverse_lookup'] or seg.tags['stroke_lookup'] or seg.tags['radical_lookup'] then return true end
    return false
end

function F.fini( env ) F.t2s = nil end

return F
