local IS_WINDOWS = (package.config:sub(1,1) == '\\')
local io = require "io"

local function D(s)
  return IS_WINDOWS and ('%' .. s .. '%') or '$' .. s
end

local function os_getenv(e)
  local str = D(e)
  local f = assert(io.popen('echo A' .. str .. 'A', 'r'))
  local val = f:read("*all")
  f:close()
  if val then val = string.gsub(val, '\n$',''):sub(2,-2) end
  if val == str then return nil end
  return val
end

local function os_expand(e)  
  if not string.find(e, "%S") then return e end
  local f = assert(io.popen('echo A' .. e .. 'A', 'r'))
  local val = f:read("*all"):gsub('\n$',''):sub(2,-2)
  f:close()
  return val
end

return {
  IS_WINDOWS = IS_WINDOWS;
  D = D;
  os_getenv = os_getenv;
  os_expand = os_expand;
}