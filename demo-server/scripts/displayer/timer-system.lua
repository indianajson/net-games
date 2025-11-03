-- Timer System with Global and Player-specific Timers
Timer = {}
Timer.__index = Timer

function Timer:init()
    self.timers = {} -- Player-specific timers
    self.countdowns = {} -- Player-specific countdowns
    self.global_timers = {} -- Global timers for all players
    self.global_countdowns = {} -- Global countdowns for all players
    self.player_data = {} -- Track player states
    
    -- Handle player joining
    Net:on("player_join", function(event)
        self:handlePlayerJoin(event.player_id)
    end)
    
    -- Handle timer updates every tick
    Net:on("tick", function(event)
        self:updateTimers(event.delta)
    end)
    
    -- Handle player leaving
    Net:on("player_disconnect", function(event)
        self:handlePlayerLeave(event.player_id)
    end)
    
    return self
end

function Timer:handlePlayerJoin(player_id)
    -- Initialize player data
    self.player_data[player_id] = {
        connected = true,
        join_time = os.time()
    }
    
    -- Initialize player-specific timers
    self.timers[player_id] = {}
    self.countdowns[player_id] = {}
    
    -- Sync global timers with new player
    self:syncGlobalTimers(player_id)
end

function Timer:handlePlayerLeave(player_id)
    -- Clean up player-specific timers
    self.timers[player_id] = nil
    self.countdowns[player_id] = nil
    self.player_data[player_id] = nil
end

function Timer:updateTimers(delta)
    -- Update player-specific timers
    for player_id, player_timers in pairs(self.timers) do
        for timer_id, timer_data in pairs(player_timers) do
            if not timer_data.paused then
                timer_data.elapsed = timer_data.elapsed + delta
                timer_data.current = timer_data.elapsed
                
                -- Check for timer completion
                if timer_data.duration and timer_data.elapsed >= timer_data.duration then
                    if timer_data.callback then
                        timer_data.callback(player_id, timer_id, timer_data.elapsed)
                    end
                    if not timer_data.loop then
                        self.timers[player_id][timer_id] = nil
                    else
                        timer_data.elapsed = 0
                    end
                end
            end
        end
    end
    
    -- Update player-specific countdowns
    for player_id, player_countdowns in pairs(self.countdowns) do
        for countdown_id, countdown_data in pairs(player_countdowns) do
            if not countdown_data.paused then
                countdown_data.remaining = countdown_data.remaining - delta
                countdown_data.current = countdown_data.remaining
                
                -- Check for countdown completion
                if countdown_data.remaining <= 0 then
                    if countdown_data.callback then
                        countdown_data.callback(player_id, countdown_id, 0)
                    end
                    if not countdown_data.loop then
                        self.countdowns[player_id][countdown_id] = nil
                    else
                        countdown_data.remaining = countdown_data.duration
                    end
                end
            end
        end
    end
    
    -- Update global timers
    for timer_id, timer_data in pairs(self.global_timers) do
        if not timer_data.paused then
            timer_data.elapsed = timer_data.elapsed + delta
            timer_data.current = timer_data.elapsed
            
            -- Check for timer completion
            if timer_data.duration and timer_data.elapsed >= timer_data.duration then
                if timer_data.callback then
                    timer_data.callback(nil, timer_id, timer_data.elapsed)
                end
                if not timer_data.loop then
                    self.global_timers[timer_id] = nil
                    self:emitToAllPlayers("timer_global_remove", {timer_id = timer_id})
                else
                    timer_data.elapsed = 0
                end
            end
        end
    end
    
    -- Update global countdowns
    for countdown_id, countdown_data in pairs(self.global_countdowns) do
        if not countdown_data.paused then
            countdown_data.remaining = countdown_data.remaining - delta
            countdown_data.current = countdown_data.remaining
            
            -- Check for countdown completion
            if countdown_data.remaining <= 0 then
                if countdown_data.callback then
                    countdown_data.callback(nil, countdown_id, 0)
                end
                if not countdown_data.loop then
                    self.global_countdowns[countdown_id] = nil
                    self:emitToAllPlayers("countdown_global_remove", {countdown_id = countdown_id})
                else
                    countdown_data.remaining = countdown_data.duration
                end
            end
            
            -- Sync global countdown with all players every second
            if math.fmod(countdown_data.elapsed or 0, 1.0) < delta then
                self:syncGlobalCountdown(countdown_id)
            end
        end
    end
end

-- Helper function to emit to all connected players
function Timer:emitToAllPlayers(event_name, data)
    for player_id, _ in pairs(self.player_data) do
        Net:emit(event_name, player_id, data)
    end
end

-- Global Timer Methods
function Timer:createGlobalTimer(timer_id, duration, callback, loop)
    loop = loop or false
    self.global_timers[timer_id] = {
        duration = duration,
        callback = callback,
        loop = loop,
        elapsed = 0,
        current = 0,
        paused = false
    }
    
    self:emitToAllPlayers("timer_global_create", {
        timer_id = timer_id,
        duration = duration,
        loop = loop
    })
end

function Timer:createGlobalCountdown(countdown_id, duration, callback, loop)
    loop = loop or false
    self.global_countdowns[countdown_id] = {
        duration = duration,
        callback = callback,
        loop = loop,
        remaining = duration,
        current = duration,
        paused = false
    }
    
    self:emitToAllPlayers("countdown_global_create", {
        countdown_id = countdown_id,
        duration = duration,
        loop = loop
    })
end

function Timer:pauseGlobalTimer(timer_id)
    if self.global_timers[timer_id] then
        self.global_timers[timer_id].paused = true
        self:emitToAllPlayers("timer_global_pause", {timer_id = timer_id})
    end
end

function Timer:resumeGlobalTimer(timer_id)
    if self.global_timers[timer_id] then
        self.global_timers[timer_id].paused = false
        self:emitToAllPlayers("timer_global_resume", {timer_id = timer_id})
    end
end

function Timer:pauseGlobalCountdown(countdown_id)
    if self.global_countdowns[countdown_id] then
        self.global_countdowns[countdown_id].paused = true
        self:emitToAllPlayers("countdown_global_pause", {countdown_id = countdown_id})
    end
end

function Timer:resumeGlobalCountdown(countdown_id)
    if self.global_countdowns[countdown_id] then
        self.global_countdowns[countdown_id].paused = false
        self:emitToAllPlayers("countdown_global_resume", {countdown_id = countdown_id})
    end
end

function Timer:removeGlobalTimer(timer_id)
    self.global_timers[timer_id] = nil
    self:emitToAllPlayers("timer_global_remove", {timer_id = timer_id})
end

function Timer:removeGlobalCountdown(countdown_id)
    self.global_countdowns[countdown_id] = nil
    self:emitToAllPlayers("countdown_global_remove", {countdown_id = countdown_id})
end

function Timer:getGlobalTimer(timer_id)
    return self.global_timers[timer_id] and self.global_timers[timer_id].current or 0
end

function Timer:getGlobalCountdown(countdown_id)
    return self.global_countdowns[countdown_id] and self.global_countdowns[countdown_id].current or 0
end

-- Sync methods for new players
function Timer:syncGlobalTimers(player_id)
    for timer_id, timer_data in pairs(self.global_timers) do
        Net:emit("timer_global_create", player_id, {
            timer_id = timer_id,
            duration = timer_data.duration,
            loop = timer_data.loop,
            current = timer_data.current
        })
        
        if timer_data.paused then
            Net:emit("timer_global_pause", player_id, {timer_id = timer_id})
        end
    end
    
    for countdown_id, countdown_data in pairs(self.global_countdowns) do
        Net:emit("countdown_global_create", player_id, {
            countdown_id = countdown_id,
            duration = countdown_data.duration,
            loop = countdown_data.loop,
            current = countdown_data.current
        })
        
        if countdown_data.paused then
            Net:emit("countdown_global_pause", player_id, {countdown_id = countdown_id})
        end
    end
end

function Timer:syncGlobalCountdown(countdown_id)
    local countdown_data = self.global_countdowns[countdown_id]
    if countdown_data then
        self:emitToAllPlayers("countdown_global_update", {
            countdown_id = countdown_id,
            current = countdown_data.current
        })
    end
end

-- Player-specific timer methods
function Timer:createPlayerTimer(player_id, timer_id, duration, callback, loop)
    if not self.timers[player_id] then
        self.timers[player_id] = {}
    end
    
    loop = loop or false
    self.timers[player_id][timer_id] = {
        duration = duration,
        callback = callback,
        loop = loop,
        elapsed = 0,
        current = 0,
        paused = false
    }
    
    Net:emit("timer_create", player_id, {
        timer_id = timer_id,
        duration = duration,
        loop = loop
    })
end

function Timer:createPlayerCountdown(player_id, countdown_id, duration, callback, loop)
    if not self.countdowns[player_id] then
        self.countdowns[player_id] = {}
    end
    
    loop = loop or false
    self.countdowns[player_id][countdown_id] = {
        duration = duration,
        callback = callback,
        loop = loop,
        remaining = duration,
        current = duration,
        paused = false
    }
    
    Net:emit("countdown_create", player_id, {
        countdown_id = countdown_id,
        duration = duration,
        loop = loop
    })
end

-- Additional utility methods
function Timer:getAllGlobalTimers()
    return self.global_timers
end

function Timer:getAllGlobalCountdowns()
    return self.global_countdowns
end

function Timer:clearAllGlobalTimers()
    for timer_id, _ in pairs(self.global_timers) do
        self:removeGlobalTimer(timer_id)
    end
end

function Timer:clearAllGlobalCountdowns()
    for countdown_id, _ in pairs(self.global_countdowns) do
        self:removeGlobalCountdown(countdown_id)
    end
end

-- Initialize the timer system
local timerSystem = setmetatable({}, Timer)
timerSystem:init()

return timerSystem