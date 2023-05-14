Powerup = Class {}

function Powerup:init(x, y, type)
  self.x = x
  self.y = y
  self.dy = 50
  self.width = 15
  self.height = 15

  self.type = type and type or 1

  self.inPlay = true

  -- self.timer = 0
end

function Powerup:collides(target)
  if self.y + self.height >= target.y then
    return true
  end

  return false
end

function Powerup:upadte(dt)
  -- self.timer =

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
