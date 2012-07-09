local string = require "string"
local eutil  = require "ENV.utils"

local IS_WINDOWS = (package.config:sub(1,1) == '\\')

local environ 
local getenv  
local expenv  
local setenv  
local update  

local get_env_t = function (as_table)
  if not environ then return nil, 'not supported' end
  local t      = environ()
  local result = {}
  for _, str in ipairs(t) do
    local k, v = string.match(str,"^(=?[^=]*)%=(.*)$")
    if as_table then
      result[string.upper(k)] = {value = v, name = k, type = 1} -- always expanded
    else
      result[string.upper(k)] = v
    end
  end
  return result
end

local FOUND = false

if not FOUND then -- ENV
  local ok, core = pcall (require, "ENV.core") 
  if ok then
    FOUND       = true
    local set 
    if core.get_win then
      environ   = core.environ_win
      expenv    = core.expand_win
      getenv    = core.get_win
      set       = core.set_win
      update    = core.update_win
    else
      environ   = core.environ
      getenv    = core.get_s or core.get
      expenv    = eutil.os_expand;
      set       = core.set
      update    = function() end
    end
    setenv = function(k, v)
      if type(v) == 'string' then v = expenv(v) end
      return set(k,v)
    end
    get_env_t = function(as_table)
      local t = environ(true)
      if not as_table then return t end
      local r = {}
      for k,v in pairs(t) do r[k] = {value = v, name = k, type = 1} end
      return r
    end
  end
end

if not FOUND then -- afxLua
  local ok, afx = pcall(require, "afx")
  if ok then 
    FOUND     = true
    environ   = nil
    expenv    = afx.expenv
    getenv    = afx.getenv
    setenv = function(k, v)
      if type(v) == 'string' then v = expenv(v) end
      if v == nil then 
        if not afx.getenv(k) then return true end
      end
      return afx.setenv(k,v)
    end
    updateenv = afx.updateenv
  end
end

if not FOUND then -- winapi
  local ok, winapi = pcall(require, "winapi")
  assert(ok, winapi )
  if ok then 
    FOUND     = true
    environ   = nil
    getenv    = os.getenv
    expenv    = nil
    setenv = function(k, v)
      return winapi.setenv(k,v)
    end
    update    = function() end
  end
end

if not FOUND then -- posix
  local ok, posix = pcall (require, "posix") 
  if ok then
    FOUND       = true
    environ   = function() posix.getenv() end
    expenv    = nil
    getenv    = posix.getenv
    setenv    = posix.setenv
    update    = function() end
    get_env_t = function(as_table)
      local t = environ()
      if not as_table then return t end
      local r = {}
      for k,v in pairs(t) do r[k] = {value = v, name = k, type = 1} end
      return r
    end
  end
end

local function clear(t)
  local k = next(t)
  while k do t[k]=nil; k=next(t)end
  return t
end

function init_module(_M)
  return setmetatable(clear(_M),{
    __index = function(self, key) return getenv(key) end;
    __newindex = function(self, key, value) return setenv(key,value) end;
    __call = function(self, ...) return get_env_t(...) end
  });
end

return {
  expand  = expenv;
  update  = update;

  environ = get_env_t;
  getenv  = getenv;
  setenv  = setenv;
  init_module = init_module;
}
