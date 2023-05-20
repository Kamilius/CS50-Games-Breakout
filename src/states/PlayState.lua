--[[
    GD50
    Breakout Remake

    -- PlayState Class --

    Author: Colton Ogden
    cogden@cs50.harvard.edu

    Represents the state of the game in which we are actively playing;
    player should control the paddle, with the ball actively bouncing between
    the bricks, walls, and the paddle. If the ball goes below the paddle, then
    the player should lose one point of health and be taken either to the Game
    Over screen if at 0 health or the Serve screen otherwise.
]]

PlayState = Class{__includes = BaseState}

local POWERUP_FROM_SECONDS = 5
local POWERUP_TO_SECONDS = 10

-- the next powerup will appear between FROM_SECONDS and TO_SECONDS time
local function getNextPowerupTime()
    return math.random(POWERUP_FROM_SECONDS, POWERUP_TO_SECONDS)
end

local function initPowerup(levelHasLockedBricks, playerHasKey)
    local shouldIncludeKeyPowerup = levelHasLockedBricks and not playerHasKey

    return Powerup({
        -- at the moment only powerups 9 and 10 are implemented:
        -- 9 - two extra balls
        -- 10 - the key for destroying the locked blocks
        type = shouldIncludeKeyPowerup and math.random(9, 10) or 9
    })
end

--[[
    We initialize what's in our PlayState via a state table that we pass between
    states as we go from playing to serving.
]]
function PlayState:enter(params)
    self.paddle = params.paddle
    self.bricks = params.bricks
    self.levelHasLockedBricks = LevelMaker.hasLockedBrick(self.bricks)
    self.health = params.health
    self.score = params.score
    self.highScores = params.highScores
    self.balls = params.balls
    self.level = params.level

    self.recoverPoints = params.recoverPoints and params.recoverPoints or 5000
    self.growPaddlePoints = params.growPaddlePoints and params.growPaddlePoints or 1000

    -- represents either player has got the key powerup or not
    self.playerHasKey = false

    -- responsible for counting down the time till next powerup
    self.powerupTimer = 0
    -- responsible for storing the next powerup appearance time
    self.nextPowerupTime = getNextPowerupTime()

    self.powerup = initPowerup(self.levelHasLockedBricks, self.playerHasKey)

    -- give ball random starting velocity
    self.balls[1]:initVelocity()
end

function PlayState:update(dt)
    if self.paused then
        if love.keyboard.wasPressed('space') then
            self.paused = false
            gSounds['pause']:play()
        else
            return
        end
    elseif love.keyboard.wasPressed('space') then
        self.paused = true
        gSounds['pause']:play()
        return
    end

    -- update positions based on velocity
    self.paddle:update(dt)
    for _, ball in pairs(self.balls) do
        ball:update(dt)
    end
    self.powerup:update(dt)

    for _, ball in pairs(self.balls) do
        if ball:collides(self.paddle) then
            -- raise ball above paddle in case it goes below it, then reverse dy
            ball.y = self.paddle.y - 8
            ball.dy = -ball.dy

            --
            -- tweak angle of bounce based on where it hits the paddle
            --

            -- if we hit the paddle on its left side while moving left...
            if ball.x < self.paddle.x + (self.paddle.width / 2) and self.paddle.dx < 0 then
                ball.dx = -50 + -(8 * (self.paddle.x + self.paddle.width / 2 - ball.x))

            -- else if we hit the paddle on its right side while moving right...
            elseif ball.x > self.paddle.x + (self.paddle.width / 2) and self.paddle.dx > 0 then
                ball.dx = 50 + (8 * math.abs(self.paddle.x + self.paddle.width / 2 - ball.x))
            end

            gSounds['paddle-hit']:play()
        end
    end

    -- detect collision across all bricks with the ball
    for k, brick in pairs(self.bricks) do
        for _, ball in pairs(self.balls) do
            -- only check collision if we're in play
            if brick.inPlay and ball:collides(brick) then

                -- add bonus points to score in case the locked brick is unlocked and hit
                local scoreForUnlockingTheLockedBrick = 0

                if brick.isLocked and self.playerHasKey then
                    scoreForUnlockingTheLockedBrick = 2000
                end

                self.score = self.score + (brick.tier * 200 + brick.color * 25) + scoreForUnlockingTheLockedBrick

                -- trigger the brick's hit function, which unlocks or removes it from play
                brick:hit(self.playerHasKey)

                -- if we have enough points, recover a point of health
                if self.score > self.recoverPoints then
                    -- can't go above 3 health
                    self.health = math.min(3, self.health + 1)

                    -- multiply recover points by 2
                    self.recoverPoints = math.min(100000, self.recoverPoints * 2)

                    -- play recover sound effect
                    gSounds['recover']:play()
                end

                -- if you have enough points to grow the paddle
                if self.score > self.growPaddlePoints then
                    -- grow the paddle
                    self.paddle:grow()

                    -- set the new grow points "checkpoint" to be
                    -- between current score + 2500-5000 points on top of that
                    self.growPaddlePoints = self.score + math.min(2500, 5000)
                end

                -- go to our victory screen if there are no more bricks left
                if self:checkVictory() then
                    gSounds['victory']:play()

                    gStateMachine:change('victory', {
                        level = self.level,
                        paddle = self.paddle,
                        health = self.health,
                        score = self.score,
                        highScores = self.highScores,
                        recoverPoints = self.recoverPoints
                    })
                end

                --
                -- collision code for bricks
                --
                -- we check to see if the opposite side of our velocity is outside of the brick;
                -- if it is, we trigger a collision on that side. else we're within the X + width of
                -- the brick and should check to see if the top or bottom edge is outside of the brick,
                -- colliding on the top or bottom accordingly
                --

                -- left edge; only check if we're moving right, and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                if ball.x + 2 < brick.x and ball.dx > 0 then

                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x - 8

                -- right edge; only check if we're moving left, , and offset the check by a couple of pixels
                -- so that flush corner hits register as Y flips, not X flips
                elseif ball.x + 6 > brick.x + brick.width and ball.dx < 0 then

                    -- flip x velocity and reset position outside of brick
                    ball.dx = -ball.dx
                    ball.x = brick.x + 32

                -- top edge if no X collisions, always check
                elseif ball.y < brick.y then

                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y - 8

                -- bottom edge if no X collisions or top collision, last possibility
                else

                    -- flip y velocity and reset position outside of brick
                    ball.dy = -ball.dy
                    ball.y = brick.y + 16
                end

                -- slightly scale the y velocity to speed up the game, capping at +- 150
                if math.abs(ball.dy) < 150 then
                    ball.dy = ball.dy * 1.02
                end

                -- only allow colliding with one brick, for corners
                break
            end
        end
    end

    -- if ball goes below bounds, revert to serve state and decrease health
    local ballToRemove = nil


    for ballIndex, ball in pairs(self.balls) do
        -- if on of the balls reached the bottom boundary
        if ball.y >= VIRTUAL_HEIGHT then
            -- if there is only one ball left
            if self.balls[2] == nil then
                self.health = self.health - 1
                self.paddle:shrink()
                gSounds['hurt']:play()

                if self.health == 0 then
                    gStateMachine:change('game-over', {
                        score = self.score,
                        highScores = self.highScores
                    })
                else
                    gStateMachine:change('serve', {
                        paddle = self.paddle,
                        bricks = self.bricks,
                        health = self.health,
                        score = self.score,
                        balls = {Ball()},
                        highScores = self.highScores,
                        level = self.level,
                        recoverPoints = self.recoverPoints,
                        growPaddlePoints = self.growPaddlePoints
                    })
                end
            else
                ballToRemove = ballIndex
            end
        end
    end

    if ballToRemove then
        table.remove(self.balls, ballToRemove)
    end

    if self.powerup.inPlay then
        -- if powerup collides with our paddle - apply powerup effect by type
        if self.powerup:collides(self.paddle) then
            self.powerup.inPlay = false

            -- add two more balls
            if self.powerup.type == 9 then
                local ball1 = Ball()
                ball1:initVelocity()

                local ball2 = Ball()
                ball2:initVelocity()

                table.insert(self.balls, ball1)
                table.insert(self.balls, ball2)
            elseif self.powerup.type == 10 then
                self.playerHasKey = true
            end

            -- reset powerup after processing it's effect
            self.powerup = initPowerup(self.levelHasLockedBricks, self.playerHasKey)
        -- if powerup is out of bounds - reset powerup
        elseif self.powerup.y > VIRTUAL_HEIGHT then
            self.powerup = initPowerup(self.levelHasLockedBricks, self.playerHasKey)
        end
    else
        self.powerupTimer = self.powerupTimer + dt

        if self.powerupTimer >= self.nextPowerupTime then
            self.powerup.inPlay = true
            self.powerupTimer = 0
            self.nextPowerupTime = getNextPowerupTime()
        end
    end

    -- for rendering particle systems
    for k, brick in pairs(self.bricks) do
        brick:update(dt)
    end

    if love.keyboard.wasPressed('escape') then
        love.event.quit()
    end
end

function PlayState:render()
    -- render bricks
    for k, brick in pairs(self.bricks) do
        brick:render()
    end

    -- render all particle systems
    for k, brick in pairs(self.bricks) do
        brick:renderParticles()
    end

    self.paddle:render()

    for _, ball in pairs(self.balls) do
        ball:render()
    end

    self.powerup:render()

    renderScore(self.score)
    renderHealth(self.health)

    -- pause text, if paused
    if self.paused then
        love.graphics.setFont(gFonts['large'])
        love.graphics.printf("PAUSED", 0, VIRTUAL_HEIGHT / 2 - 16, VIRTUAL_WIDTH, 'center')
    end
end

function PlayState:checkVictory()
    for k, brick in pairs(self.bricks) do
        if brick.inPlay then
            return false
        end
    end

    return true
end
