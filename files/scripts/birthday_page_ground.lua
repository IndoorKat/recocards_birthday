local e = GetUpdatedEntityID()
if e == nil or e == 0 or not EntityGetIsAlive(e) then return end

local x,y = EntityGetTransform(e)
local hit,hx,hy = RaytracePlatforms(x,y,x,y+8)

if hit then
    EntitySetTransform(e,x,hy-4,0)
    local v = EntityGetFirstComponentIncludingDisabled(e,"VelocityComponent")
    if v ~= nil then
        ComponentSetValue2(v,"mVelocity",0,0)
        EntitySetComponentIsEnabled(e,v,false)
    end
end
