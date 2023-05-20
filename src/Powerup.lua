Powerup = Class {}

function Powerup:init(params)
  -- initialize params with an empty object by default
  params = params or {}
  -- 8 is a viewport padding
  -- 15 - is a width of a Powerup
  self.x = params.x and params.x or math.random(8, VIRTUAL_WIDTH - 8 - 15)
  self.y = params.y and params.y or VIRTUAL_HEIGHT / 4
  self.dy = 0.25
  self.width = 16
  self.height = 16

  self.type = params.type and params.type or 9

  self.inPlay = false
end

function Powerup:collides(target)
  if self.y + self.height >= target.y then
    if self.x >= target.x and self.x <= target.x + target.width then
      return true
    end
  end

  return false
end

function Powerup:update(dt)
  if self.inPlay then
    self.y = self.y + self.dy
  end
end

function Powerup:render()
  if self.inPlay then
    love.graphics.draw(gTextures['main'],
      gFrames['powerups'][self.type],
      self.x, self.y)
  end
end
