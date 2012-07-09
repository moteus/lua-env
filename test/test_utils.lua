local lunit = require "lunit"
local eutil = require "ENV.utils"
local D = eutil.D

local function test_expand_(expand, set)
  if not expand then return lunit.fail("expand do not support!") end

  lunit.assert_equal('',           expand(''))

  lunit.assert_not_nil(set('XXX', 'hello'))
  lunit.assert_equal('hello',           expand(D('xxx'))                       )
  lunit.assert_equal('hello, world!!!', expand(D('xxx')..', world!!!')         )
  lunit.assert_equal('hello\\world!!!', expand(D('xxx')..'\\world!!!')         )
  lunit.assert_equal('hello/world!!!',  expand(D('xxx').. '/world!!!')         )
  lunit.assert_equal('helloworld!!!',   expand(D('xxx').. 'world!!!')          )
  lunit.assert_equal('worldhelloworld', expand('world' .. D('xxx') ..'world')  )

  lunit.assert_not_nil(set('XXX', nil))
  lunit.assert_equal(D('xxx')                       ,expand(D('xxx'))                       )
  lunit.assert_equal(D('xxx')..', world!!!'         ,expand(D('xxx')..', world!!!')         )
  lunit.assert_equal(D('xxx')..'\\world!!!'         ,expand(D('xxx')..'\\world!!!')         )
  lunit.assert_equal(D('xxx').. '/world!!!'         ,expand(D('xxx').. '/world!!!')         )
  lunit.assert_equal(D('xxx').. 'world!!!'          ,expand(D('xxx').. 'world!!!')          )
  lunit.assert_equal('world' .. D('xxx') ..'world'  ,expand('world' .. D('xxx') ..'world')  )
end

local function test_expand_empty_(expand, set)
  if not expand then return lunit.fail("expand do not support!") end

  -- windows support empty strings in variable
  lunit.assert_not_nil(set('XXX', ''))
  lunit.assert_equal('',           expand(D('xxx'))                       ,'Empty variable does not support!')
  lunit.assert_equal(', world!!!', expand(D('xxx')..', world!!!')         ,'Empty variable does not support!')
  lunit.assert_equal('\\world!!!', expand(D('xxx')..'\\world!!!')         ,'Empty variable does not support!')
  lunit.assert_equal('/world!!!',  expand(D('xxx').. '/world!!!')         ,'Empty variable does not support!')
  lunit.assert_equal('world!!!',   expand(D('xxx').. 'world!!!')          ,'Empty variable does not support!')
  lunit.assert_equal('worldworld', expand('world' .. D('xxx') ..'world')  ,'Empty variable does not support!')
end                        

local function test_env_(set, get)
  lunit.assert_not_nil(set('XXX', 'hello'))
  lunit.assert_equal('hello', get('XXX'))
  lunit.assert_equal('hello', get('XxX'))

  lunit.assert_not_nil(set('XXX', nil))
  lunit.assert_nil(get('XXX'))
  lunit.assert_nil(get('XxX'))
end

local function test_env_empty_(set, get)
  lunit.assert_not_nil(set('XXX', ''))
  lunit.assert_equal('', get('XXX'), 'Empty variable does not support!')
  lunit.assert_equal('', get('XxX'), 'Empty variable does not support!')
  
  lunit.assert_not_nil(set('XXX', nil))
  lunit.assert_nil(get('XXX'))
  lunit.assert_nil(get('XxX'))
end

local function test_environ_(environ, set)
  lunit.assert_not_nil(set('XXX', 'hello'))
  local t = environ(true)
  lunit.assert_equal('hello', t.XXX)

  lunit.assert_not_nil(set('XXX', nil))
  local t = environ(true)
  lunit.assert_nil(t.XXX)
end

local function test_environ_empty_(environ, set)
  lunit.assert_not_nil(set('XXX', ''))
  local t = environ(true)
  lunit.assert_equal('', t.XXX, 'Empty variable does not support!')
  
  lunit.assert_not_nil(set('XXX', nil))
  local t = environ(true)
  lunit.assert_nil(t.XXX)
end


local function gen_empty_tests(_M, GETS, SETS, EXPANDS, ENVIRONS)
  local setup = _M.setup
  _M.setup = function()
    for _, set in pairs(SETS) do 
      set('XXX', nil)
    end
    if setup then setup() end
  end

  for gn, gf in pairs(GETS) do
    for sn, sf in pairs(SETS) do
      _M['test GET/SET : ' .. sn .. '=>' .. gn ] = function () test_env_empty_(sf,gf) end
    end
  end

  for sn, sf in pairs(SETS) do
    for en, ef in pairs(EXPANDS) do
      _M['test EXPAND : ' .. sn .. '=>' .. en ] = function () test_expand_empty_(ef, sf) end
    end
  end

  for sn, sf in pairs(SETS) do
    for en, ef in pairs(ENVIRONS) do
      _M['test ENVIRON : ' .. sn .. '=>' .. en ] = function () test_environ_empty_(ef, sf) end
    end
  end

end

local function gen_base_tests(_M, GETS, SETS, EXPANDS, ENVIRONS)

  for gn, gf in pairs(GETS) do
    for sn, sf in pairs(SETS) do
      _M['test GET/SET : ' .. sn .. '=>' .. gn ] = function () test_env_(sf,gf) end
    end
  end

  for sn, sf in pairs(SETS) do
    for en, ef in pairs(EXPANDS) do
      _M['test EXPAND : ' .. sn .. '=>' .. en ] = function () test_expand_(ef, sf) end
    end
  end

  for sn, sf in pairs(SETS) do
    for en, ef in pairs(ENVIRONS) do
      _M['test ENVIRON : ' .. sn .. '=>' .. en ] = function () test_environ_(ef, sf) end
    end
  end

end

return {
  os_getenv           = os_getenv;
  os_expand           = os_expand;
  gen_empty_tests     = gen_empty_tests;
  gen_base_tests      = gen_base_tests;
  -- clear_env           = clear_env           ;
  -- test_expand_        = test_expand_        ;
  -- test_expand_empty_  = test_expand_empty_  ;
  -- test_env_           = test_env_           ;
  -- test_env_empty_     = test_env_empty_     ;
  -- test_environ_       = test_environ_       ;
  -- test_environ_empty_ = test_environ_empty_ ;
}