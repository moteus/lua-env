local lunit = require "lunit"

if _VERSION >= 'Lua 5.2' then _ENV = lunit.module('ENV_TEST','seeall') 
else module( 'ENV_TEST' , package.seeall, lunit.testcase ) end

local ENV   = require"ENV"
local eutil = require"ENV.utils"
local D = eutil.D

local function clear_env()

  if ENV.USER then 
    ENV.USER.XXX = nil;
    ENV.USER.YYY = nil;
  end

  if ENV.SYS then 
    ENV.SYS.XXX = nil;
    ENV.SYS.YYY = nil;
  end

  if ENV.PROC then 
    ENV.PROC.XXX = nil;
    ENV.PROC.YYY = nil;
  end


end

function setup()
  assert_not_nil(ENV)

  if ENV.USER then 
    assert_nil(ENV.USER.XXX)
    assert_nil(ENV.USER.YYY)
  end

  if ENV.SYS then 
    assert_nil(ENV.SYS.XXX)
    assert_nil(ENV.SYS.YYY)
  end

end

function teardown()
  clear_env()
end

function test_expand()
  if not ENV.expand then return fail("expand do not support!") end
  assert_equal('', ENV.expand(''))
  assert_equal('', eutil.os_expand(''))

  ENV.PROC.XXX = 'hello'
  assert_equal('hello',           ENV.expand(D('xxx'))                       )
  assert_equal('hello, world!!!', ENV.expand(D('xxx')..', world!!!')         )
  assert_equal('hello\\world!!!', ENV.expand(D('xxx')..'\\world!!!')         )
  assert_equal('hello/world!!!',  ENV.expand(D('xxx').. '/world!!!')         )
  assert_equal('helloworld!!!',   ENV.expand(D('xxx').. 'world!!!')          )
  assert_equal('worldhelloworld', ENV.expand('world' .. D('xxx') ..'world')  )
  assert_equal('hello',           eutil.os_expand(D('xxx')))

  ENV.PROC.XXX = nil
  assert_equal(D('xxx')                       ,ENV.expand(D('xxx'))                       )
  assert_equal(D('xxx')..', world!!!'         ,ENV.expand(D('xxx')..', world!!!')         )
  assert_equal(D('xxx')..'\\world!!!'         ,ENV.expand(D('xxx')..'\\world!!!')         )
  assert_equal(D('xxx').. '/world!!!'         ,ENV.expand(D('xxx').. '/world!!!')         )
  assert_equal(D('xxx').. 'world!!!'          ,ENV.expand(D('xxx').. 'world!!!')          )
  assert_equal('world' .. D('xxx') ..'world'  ,ENV.expand('world' .. D('xxx') ..'world')  )
  assert_equal(D('xxx'),                       eutil.os_expand(D('xxx')))

  ENV.PROC.XXX = ''
  assert_equal(''                   ,ENV.expand(D('xxx'))                       )
  assert_equal(', world!!!'         ,ENV.expand(D('xxx')..', world!!!')         )
  assert_equal('\\world!!!'         ,ENV.expand(D('xxx')..'\\world!!!')         )
  assert_equal('/world!!!'          ,ENV.expand(D('xxx').. '/world!!!')         )
  assert_equal('world!!!'           ,ENV.expand(D('xxx').. 'world!!!')          )
  assert_equal('worldworld'         ,ENV.expand('world' .. D('xxx') ..'world')  )
  assert_equal(D('xxx'),            eutil.os_expand(D('xxx')))
end

function test_proc()
  if not ENV.PROC then return fail("ENV.PROC do not support") end
  ENV.PROC.XXX = 'hello'
  assert_equal('hello', ENV.PROC.XXX)
  assert_equal('hello', ENV.PROC.xxx)
  ENV.PROC.YYY = '%xxx%'
  assert_equal('hello', ENV.PROC.YYY)
  ENV.PROC.YYY = '%xxx%world'
  assert_equal('helloworld', ENV.PROC.YYY)
  assert_equal('hello',      eutil.os_getenv('xxx'))

  local s = ('1'):rep(4097)
  ENV.PROC.XXX = s
  assert_equal(s, ENV.PROC.XXX)
  assert_equal(s, eutil.os_getenv('xxx'))

  local s = (' '):rep(4097)
  ENV.PROC.XXX = s
  assert_equal(s, ENV.PROC.XXX)
  assert_equal(s, eutil.os_getenv('xxx'))

  ENV.PROC.XXX = ''
  assert_equal('', ENV.PROC.XXX, 'Empty value does not support.')
  local t = assert_table(ENV.PROC())
  assert_equal(ENV.PROC.XXX, t.XXX)
end

function test_proc_environ()
  if not ENV.PROC then return fail("ENV.PROC do not support") end
  ENV.PROC.XXX = 'hello'
  local t = assert_table(ENV.PROC(true))
  assert_table(t.XXX)
  assert_equal(ENV.PROC.XXX, t.XXX.value)
  assert_equal(1, t.XXX.type)

  ENV.PROC.XXX = nil
  assert_nil(ENV.PROC.XXX)
  local t = assert_table(ENV.PROC())
  assert_nil(t.XXX)
  local t = assert_table(ENV.PROC(true))
  assert_nil(t.XXX)
end

local function test_reg(E, fail_msg)
  if not E then return fail(fail_msg) end
  E.XXX='hello'
  assert_equal('hello', E.XXX)
  assert_equal('hello', E.xxx)

  E.YYY = '%xxx%'
  assert_equal('%xxx%', E.YYY)
  E.YYY = '%xxx%world'
  assert_equal('%xxx%world', E.YYY)

  local t = E()
  assert_equal(E.YYY, t.YYY)
  assert_equal(E.XXX, t.XXX)

  local t = E(true)
  assert_equal(E.YYY, t.YYY.value)
  assert_equal(E.XXX, t.XXX.value)
  assert_equal(1, t.XXX.type) -- str
  assert_equal(2, t.YYY.type) -- expand

  E.XXX = ''
  assert_equal('', E.XXX)
  E.YYY = nil
  assert_nil(E.YYY)

  -- assert_equal('hello', get_env('xxx'), "value isn't inherited by process")
  assert_equal(nil, eutil.os_getenv('xxx'), "value is inherited by process")
end

function test_user()
  test_reg(ENV.USER, "ENV.USER do not support")
end

function test_sys()
  test_reg(ENV.SYS, "ENV.SYS do not support")
end

function test_sys()
  test_reg(ENV.VOLATILE, "ENV.VOLATILE do not support")
end
