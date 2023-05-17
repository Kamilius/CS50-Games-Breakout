Powerup = Class {}

function Powerup:init(x, y, type)
  self.x = x
  self.y = y
  self.dy = 0.25
  self.width = 16
  self.height = 16

  self.type = type and type or 1

  self.inPlay = true

  -- self.timer = 0
end

-- TODO: Imlpement AABB Collision detection
function Powerup:collides(target)
  if self.y + self.height >= target.y then
      if self.x >= target.x or self.x <= target.x + target.width then
      return true
    end
  end

  return false
end

function Powerup:update(dt)
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
