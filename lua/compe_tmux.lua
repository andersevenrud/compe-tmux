--
-- compe-tmux
-- author: andersevenrud@gmail.com
-- license: MIT
--

local compe = require'compe'
local compe_config = require'compe.config'

--
-- Tmux implementation
--

local Tmux = {}

function Tmux.new(config)
    local self = setmetatable({}, { __index = Tmux })
    self.has_tmux = vim.fn.executable('tmux')
    self.is_tmux = os.getenv('TMUX')
    self.config = config
    return self
end

function Tmux.is_enabled(self)
    return self.has_tmux and self.is_tmux
end

function Tmux.get_current_pane()
    return os.getenv('TMUX_PANE')
end

function Tmux.get_panes(self, current_pane)
    local cmd = 'tmux list-panes -F \'#{pane_id}\''
    if self.config.all_panes then
        cmd = cmd .. ' -a'
    end

    local h = io.popen(cmd)
    local data = h:read('*all')
    local result = {}

    for p in string.gmatch(data, '%%%d+') do
        if current_pane ~= p then
            table.insert(result, p)
        end
    end

    return result
end

function Tmux.get_pane_data(self, pane)
    local h = io.popen('tmux capture-pane -p -t ' .. pane)

    if h ~= nil then
        return h:read('*all')
    end

    return nil
end

function Tmux.get_completion_items(self, current_pane, input)
    local panes = self:get_panes(current_pane)
    local result = {}
    local input_lower = input:lower()

    for _, p in ipairs(panes) do
        local data = self:get_pane_data(p)
        if data ~= nil then
            for word in string.gmatch(data, '[%w%d_:/.%-~]+') do
                local word_lower = word:lower()

                if word_lower:match(input_lower) then
                    table.insert(result, {
                        word = word:gsub('[:.]+$', '')
                    })

                    for sub_word in string.gmatch(word, '[%w%d]+') do
                        table.insert(result, {
                            word = sub_word
                        })
                    end
                end
            end
        end
    end

    return result
end

function Tmux.complete(self, input)
    if not self:is_enabled() then
        return nil
    end

    local current_pane = self:get_current_pane()
    if not current_pane then
        return nil
    end

    return self:get_completion_items(current_pane, input)
end

--
-- Compe implementation
--

local Source = {}

function Source.new()
    local c = compe_config.get()
    local all_panes = c.source.tmux.all_panes and c.source.tmux.all_panes or false
    local self = setmetatable({}, { __index = Source })
    self.tmux = Tmux.new({
        all_panes = all_panes
    })
    return self
end

function Source.get_metadata(self)
    return {
        priority = 100,
        dup = 0,
        menu = '[tmux]'
    }
end

function Source.determine(self, context)
    return compe.helper.determine(context)
end

function Source.complete(self, args)
    local items = self.tmux:complete(args.input)
    if items == nil then
        return args.abort()
    end

    args.callback({
        incomplete = true,
        items = items
    })
end

return Source.new()
