-- leveldb.lua


-- - lua_translator@*leveldb@dict
--
-- dict:
--   dictionary: lua
--   initial_quality: 1.5


db_pool_ = {}

local function opendb( name )
    local db = db_pool_[name]
    if not db then
        db = LevelDb( name )
        if not db then return nil end
        db_pool_[name] = db
    end
    if not db:loaded() then db:open() end
    return db
end

local function update_entry( text, code, db )
    if #text == 0 then return end
    db:update( code, text )
end

local M = {}

function M.init( env )
    local config = env.engine.schema.config
    local dbname = config:get_string( env.name_space .. '/dictionary' ) or 'lua'
    env.quality = tonumber( config:get_string( env.name_space .. '/initial_quality' ) ) or 1
    env.db = assert( opendb( dbname ), 'init leveldb failed' )

    env.commit_notifier = env.engine.context.commit_notifier:connect(
                              function( ctx )
            local commit_text = ctx:get_commit_text()
            local commit_code = ctx.input
            local cand = ctx:get_selected_candidate()
            local cand_text = cand.text
            if (cand and cand_text == commit_text and cand.type == 'new') then
                commit_code = commit_code:gsub( '*$', '' )
                print( '- record: ' .. commit_text .. ' | ' .. commit_code )
                update_entry( commit_text, commit_code, env.db )
            end

            if (cand and cand_text == commit_text and cand_text == 'export_lua') then
                local user_data_dir = string.gsub( rime_api:get_user_data_dir(), '/', '//' )
                local content = {}
                env.file = io.open( user_data_dir .. '/' .. dbname .. '.txt', 'w' )
                for k, v in env.db:query( '' ):iter() do
                    if not k:find( '^\1' ) then table.insert( content, k .. '\t' .. v ) end
                end
                env.file:write( table.concat( content, '\n' ) )
                env.file:close()
            end

            if (cand and cand_text == commit_text and cand_text == 'import_lua') then
                local user_data_dir = string.gsub( rime_api:get_user_data_dir(), '/', '//' )
                local content = {}
                env.file = io.open( user_data_dir .. '/' .. dbname .. '.txt', 'r' )
                for line in env.file:lines() do
                    local k, v = line:match( '^(.-)\t(.*)$' )
                    if k and v then update_entry( k, v, env.db ) end
                end
                env.file:close()
            end
        end
                           )
end

function M.fini( env )
    env.db:close()
    env.commit_notifier:disconnect()
end

function M.func( inp, seg, env )
    if inp == 'exportlua' then
        local cand = Candidate( 'command', seg.start, seg._end, 'export_lua', '>_' )
        cand.quality = 99
        yield( cand )
    elseif inp == 'importlua' then
        local cand = Candidate( 'command', seg.start, seg._end, 'import_lua', '>_' )
        cand.quality = 99
        yield( cand )
    end
    if inp:find( '*$' ) then
        local cand = Candidate( 'new', seg.start, seg._end, inp:gsub( '*$', '' ), '+' )
        yield( cand )
    end
    for _, v in env.db:query( inp ):iter() do
        local type = 'lua'
        local cand = Candidate( type, seg.start, seg._end, v, '#' )
        cand.quality = env.quality
        yield( cand )
    end
end

return M
