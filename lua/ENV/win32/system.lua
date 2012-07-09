----------------------------------------------------------------------
-- Реализует функции для работы с переменными окружения через реестр 
----------------------------------------------------------------------
local string = require"string"

local string = require "string"
local assert, type = 
      assert, type

local get_int_valtype, get_env_type
do

function get_int_valtype(type_name)
  if type(type_name) == 'number' then
    return type_name
  end
  return assert(({
    ["sz"]        = 1;  -- A null-terminated string string 
    ["expand_sz"] = 2;  -- A null-terminated string that contains unexpanded references to environment variables, for example "%PATH%" string 
    ["binary"]    = 3;  -- Binary data in any form string 
    ["dword"]     = 4;  -- A 32-bit number number 
    ["multi_sz"]  = 7;  -- 
  })[string.lower(type_name)])
end

function get_env_type(value)
  if nil ~= string.find(value, '%', 1, true) then
    return get_int_valtype"expand_sz"
  end
  return get_int_valtype"sz"
end

assert(get_int_valtype("sz")        == 1)
assert(get_int_valtype("expand_sz") == 2)
assert(get_int_valtype("binary")    == 3)
assert(get_int_valtype("dword")     == 4)
assert(get_int_valtype("multi_sz")  == 7)

assert(get_int_valtype("expand_sz") == get_env_type("%LAU_DIR%"))
assert(get_int_valtype("expand_sz") == get_env_type("%KLJLJK%"))
assert(get_int_valtype("expand_sz") == get_env_type("%"))
assert(get_int_valtype("sz")        == get_env_type("LAU_DIR"))
end

---
-- Registry function
--
local get_reg_key,set_reg_key,del_reg_key,get_reg_keys

local winreg = require"winreg"
do

function regopen(k, mode)
  mode = mode or 'r'
  return winreg.openkey(k, mode)
end

function get_reg_key(path, key)
  local ok, hkey = pcall(regopen, path)
  local result, type
  if ok and hkey then
    for name in hkey:enumvalue() do
      if string.upper(key) == string.upper(name) then
        result, type = hkey:getvalue(name)
      end
    end
    hkey:close()
    return result, type
  end
  return nil, hkey
end

function set_reg_key(path, key, value, value_type)
  local v, vt = get_reg_key(path, key)

  if v ~= nil and v == value and (value_type == nil or get_int_valtype(value_type) == get_int_valtype(vt)) then
    return v, vt
  end

  if value_type == nil then
    value_type = vt
  end

  local ok, hkey = pcall(regopen, path, 'w')
  if ok and hkey then
    local ok, err = pcall(hkey.setvalue, hkey, key, value, value_type)
    hkey:close()
    if not ok then
      return nil, err
    end
  end
  return get_reg_key(path, key)
end

function del_reg_key(path, key)
  local v, vt = get_reg_key(path, key)
  if v == nil then
    return vt == nil, vt 
  end
  local ok, hkey = pcall(regopen, path, 'w')
  if ok and hkey then
    local ok, err = pcall(hkey.deletevalue, hkey, key)
    hkey:close()
    if not ok then
      return nil, err
    end
  end
  return true
end

function get_reg_keys(path)
  local ok, hkey = pcall(regopen, path)
  local result = {}
  if ok and hkey then
    for name in hkey:enumvalue() do
      local value, type = hkey:getvalue(name)
      result[name] = {value = value; type = type}
    end
    hkey:close()
  end
  return result
end

end

local type, assert, pcall, pairs = 
      type, assert, pcall, pairs 

---
-- Environment function
--
local PATHS = {
  user      = [[HKEY_CURRENT_USER\Environment]];
  sys       = [[HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Session Manager\Environment]];
  volatile  = [[HKEY_CURRENT_USER\Volatile Environment]];
}

local function get_raw_env(path, name)
  path = assert(PATHS[string.lower(path)])
  return get_reg_key(path, name)
end

local function set_raw_env(path, name, value)
  path = assert(PATHS[string.lower(path)])
  return set_reg_key(path, name, value, get_env_type(value))
end

local function del_raw_env(path, name)
  path = assert(PATHS[string.lower(path)])
  return del_reg_key(path, name)
end

local function get_raw_env_t(path, as_table)
  path = assert(PATHS[string.lower(path)])
  local t = get_reg_keys(path)
  local result = {}
  for k, v in pairs(t) do
    if as_table then
      v.name = k
      result[string.upper(k)] = v
    else
      result[string.upper(k)] = v.value
    end
  end
  return result
end

local function init_reg_env(o, ENV_TYPE)
  local path = assert(PATHS[string.lower(ENV_TYPE)])
  local k = next(o) while k do o[k]=nil; k=next(o) end
  return setmetatable(o, {
    __index = function(self, key) return get_raw_env(ENV_TYPE, key) end;
    __newindex = function(self, key, value)
      if value == nil then del_raw_env(ENV_TYPE, key)
      else set_raw_env(ENV_TYPE,key,value) end
    end;
    __call = function(self, ...) return get_raw_env_t(ENV_TYPE, ...) end;
  })
end

return {
  environ     = get_raw_env_t;
  getenv      = get_raw_env;
  setenv      = set_raw_env;
  init_module = init_reg_env;
}
