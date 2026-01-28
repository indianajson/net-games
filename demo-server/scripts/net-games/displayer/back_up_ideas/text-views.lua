-- text-views.lua
-- Different text view types using unified character rendering
local TextViews = {}

-- Base TextView class
TextViews.BaseView = {}
TextViews.BaseView.__index = TextViews.BaseView

function TextViews.BaseView:new(character_renderer, layout_engine)
    local view = setmetatable({}, self)
    view.character_renderer = character_renderer
    view.layout_engine = layout_engine
    view.layout = nil
    view.view_id = nil
    view.player_id = nil
    return view
end

function TextViews.BaseView:draw(player_id, text, options)
    self.player_id = player_id
    self.view_id = options.id or ("view_" .. tostring(math.random(10000, 99999)))
    
    -- Create layout
    self.layout = self.layout_engine:layoutText(player_id, text, options)
    
    -- Register with character renderer
    self.character_renderer:registerView(player_id, self.view_id, {
        type = self.view_type,
        characters = self.layout.characters,
        layout = self.layout
    })
    
    return self
end

function TextViews.BaseView:updateText(new_text)
    if not self.layout then return end
    
    -- Remove old characters
    self:destroy()
    
    -- Create new layout with same options
    self.layout = self.layout_engine:layoutText(self.player_id, new_text, self.layout.options)
    
    -- Update registration
    self.character_renderer:registerView(self.player_id, self.view_id, {
        type = self.view_type,
        characters = self.layout.characters,
        layout = self.layout
    })
    
    return self
end

function TextViews.BaseView:setPosition(x, y)
    if not self.layout then return end
    
    local dx = x - self.layout.options.x
    local dy = y - self.layout.options.y
    
    -- Move all characters
    self.character_renderer:moveCharacters(self.player_id, self.layout.characters, dx, dy)
    
    -- Update layout position
    self.layout.options.x = x
    self.layout.options.y = y
    
    -- Update character positions in layout
    for char_id, pos in pairs(self.layout.char_positions) do
        pos.x = pos.x + dx
        pos.y = pos.y + dy
    end
    
    return self
end

function TextViews.BaseView:setOpacity(opacity)
    if not self.layout then return end
    
    self.character_renderer:setCharactersOpacity(self.player_id, self.layout.characters, opacity)
    self.layout.options.opacity = opacity
    
    return self
end

function TextViews.BaseView:setVisible(visible)
    if not self.layout then return end
    
    for _, char_id in ipairs(self.layout.characters) do
        self.character_renderer:updateCharacter(self.player_id, char_id, {
            visible = visible
        })
    end
    
    return self
end

function TextViews.BaseView:destroy()
    if not self.layout then return end
    
    -- Remove all characters
    for _, char_id in ipairs(self.layout.characters) do
        self.character_renderer:removeCharacter(self.player_id, char_id)
    end
    
    -- Unregister view
    self.character_renderer:unregisterView(self.player_id, self.view_id)
    
    self.layout = nil
    return self
end

function TextViews.BaseView:getDimensions()
    if not self.layout then return 0, 0 end
    return self.layout.width, self.layout.height
end

-- Static TextView (no animation)
TextViews.StaticView = setmetatable({}, { __index = TextViews.BaseView })
TextViews.StaticView.view_type = "static"

function TextViews.StaticView:new(character_renderer, layout_engine)
    local view = setmetatable(TextViews.BaseView:new(character_renderer, layout_engine), self)
    view.view_type = "static"
    return view
end

-- Marquee View (scrolling text)
TextViews.MarqueeView = setmetatable({}, { __index = TextViews.BaseView })
TextViews.MarqueeView.view_type = "marquee"

function TextViews.MarqueeView:new(character_renderer, layout_engine)
    local view = setmetatable(TextViews.BaseView:new(character_renderer, layout_engine), self)
    view.view_type = "marquee"
    view.speed = 60  -- pixels per second
    view.direction = -1  -- -1 for left, 1 for right
    view.loop = true
    view.is_scrolling = false
    view.scroll_position = 0
    view.bounds = { left = 0, right = 240 }  -- Screen bounds
    return view
end

function TextViews.MarqueeView:draw(player_id, text, options)
    TextViews.BaseView.draw(self, player_id, text, options)
    
    -- Marquee-specific setup
    self.speed = options.speed or 60
    self.direction = options.direction or -1
    self.loop = options.loop ~= false
    self.bounds = options.bounds or { left = 0, right = 240 }
    
    -- Position text off-screen to the right for left-scrolling
    if self.direction == -1 then
        local width = self.layout.width
        self:setPosition(self.bounds.right, self.layout.options.y)
        self.scroll_position = self.bounds.right
    end
    
    self.is_scrolling = true
    
    return self
end

function TextViews.MarqueeView:update(delta)
    if not self.is_scrolling or not self.layout then return end
    
    local movement = self.speed * delta * self.direction
    self.scroll_position = self.scroll_position + movement
    
    -- Update position of all characters
    self:setPosition(self.scroll_position, self.layout.options.y)
    
    -- Check bounds for looping
    if self.direction == -1 then
        -- Left scrolling
        if self.scroll_position + self.layout.width < self.bounds.left then
            if self.loop then
                self.scroll_position = self.bounds.right
            else
                self:stop()
            end
        end
    else
        -- Right scrolling
        if self.scroll_position > self.bounds.right then
            if self.loop then
                self.scroll_position = self.bounds.left - self.layout.width
            else
                self:stop()
            end
        end
    end
    
    return self
end

function TextViews.MarqueeView:start()
    self.is_scrolling = true
    return self
end

function TextViews.MarqueeView:stop()
    self.is_scrolling = false
    return self
end

function TextViews.MarqueeView:setSpeed(speed)
    self.speed = speed
    return self
end

-- Text Box View (typewriter effect with paging)
TextViews.TextBoxView = setmetatable({}, { __index = TextViews.BaseView })
TextViews.TextBoxView.view_type = "textbox"

function TextViews.TextBoxView:new(character_renderer, layout_engine)
    local view = setmetatable(TextViews.BaseView:new(character_renderer, layout_engine), self)
    view.view_type = "textbox"
    view.current_page = 1
    view.current_char = 0
    view.typing_speed = 30  -- characters per second
    view.is_typing = false
    view.is_complete = false
    view.pages = {}
    view.pause_marks = {}
    view.timer = 0
    view.char_delay = 1 / 30
    return view
end

function TextViews.TextBoxView:draw(player_id, text, options)
    TextViews.BaseView.draw(self, player_id, text, options)
    
    -- TextBox-specific setup
    self.typing_speed = options.typing_speed or 30
    self.char_delay = 1 / self.typing_speed
    self.auto_advance = options.auto_advance or false
    self.auto_advance_delay = options.auto_advance_delay or 2.0
    
    -- Hide all characters initially
    self:setVisible(false)
    
    -- Parse text into pages if needed
    self:parsePages(text, options)
    
    -- Show first page
    self:showPage(1)
    
    return self
end

function TextViews.TextBoxView:parsePages(text, options)
    self.pages = {}
    self.pause_marks = {}
    
    -- Simple page splitting by line count
    local max_lines = options.max_lines or 4
    local lines = {}
    
    for line in text:gmatch("[^\n]+") do
        table.insert(lines, line)
        
        if #lines >= max_lines then
            table.insert(self.pages, table.concat(lines, "\n"))
            lines = {}
        end
    end
    
    if #lines > 0 then
        table.insert(self.pages, table.concat(lines, "\n"))
    end
    
    -- If no pages were created, use entire text as one page
    if #self.pages == 0 then
        self.pages[1] = text
    end
end

function TextViews.TextBoxView:showPage(page_num)
    if page_num < 1 or page_num > #self.pages then return end
    
    self.current_page = page_num
    self.current_char = 0
    self.is_typing = true
    self.is_complete = false
    self.timer = 0
    
    -- Update text with current page
    self:updateText(self.pages[page_num])
    
    -- Hide all characters initially
    self:setVisible(false)
    
    return self
end

function TextViews.TextBoxView:update(delta)
    if not self.is_typing or self.is_complete then return end
    
    self.timer = self.timer + delta
    
    while self.timer >= self.char_delay do
        self.timer = self.timer - self.char_delay
        self.current_char = self.current_char + 1
        
        -- Make current character visible
        if self.current_char <= #self.layout.characters then
            local char_id = self.layout.characters[self.current_char]
            self.character_renderer:updateCharacter(self.player_id, char_id, {
                visible = true
            })
            
            -- Check for pause marks
            if self.pause_marks[self.current_char] then
                self.timer = self.timer - self.pause_marks[self.current_char]
                self.pause_marks[self.current_char] = nil
            end
        else
            -- End of page
            self.is_typing = false
            self.is_complete = true
            
            if self.auto_advance and self.current_page < #self.pages then
                -- Schedule auto-advance
                self.auto_advance_timer = self.auto_advance_delay
            end
            
            break
        end
    end
    
    -- Handle auto-advance
    if self.auto_advance_timer then
        self.auto_advance_timer = self.auto_advance_timer - delta
        if self.auto_advance_timer <= 0 then
            self:nextPage()
            self.auto_advance_timer = nil
        end
    end
    
    return self
end

function TextViews.TextBoxView:nextPage()
    if self.current_page < #self.pages then
        self:showPage(self.current_page + 1)
        return true
    end
    return false
end

function TextViews.TextBoxView:previousPage()
    if self.current_page > 1 then
        self:showPage(self.current_page - 1)
        return true
    end
    return false
end

function TextViews.TextBoxView:skipToEnd()
    if not self.is_complete then
        -- Make all characters visible
        for _, char_id in ipairs(self.layout.characters) do
            self.character_renderer:updateCharacter(self.player_id, char_id, {
                visible = true
            })
        end
        
        self.is_typing = false
        self.is_complete = true
        self.current_char = #self.layout.characters
    end
    
    return self
end

function TextViews.TextBoxView:addPause(char_position, seconds)
    self.pause_marks[char_position] = seconds
    return self
end

function TextViews.TextBoxView:setTypingSpeed(speed)
    self.typing_speed = speed
    self.char_delay = 1 / speed
    return self
end

function TextViews.TextBoxView:isTypingComplete()
    return self.is_complete
end

function TextViews.TextBoxView:getCurrentPage()
    return self.current_page, #self.pages
end

-- Utility function to create different view types
TextViews.create = function(view_type, character_renderer, layout_engine)
    if view_type == "static" then
        return TextViews.StaticView:new(character_renderer, layout_engine)
    elseif view_type == "marquee" then
        return TextViews.MarqueeView:new(character_renderer, layout_engine)
    elseif view_type == "textbox" then
        return TextViews.TextBoxView:new(character_renderer, layout_engine)
    else
        error("Unknown view type: " .. tostring(view_type))
    end
end

return TextViews