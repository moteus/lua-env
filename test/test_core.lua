local lunit  = require "lunit"
local ENV    = require "ENV.core"
local eutil  = require "ENV.utils"
local tutil  = require "test_utils"

local TEST_CASES = {
  { NAME = ' (CAN NOT FAIL)WIN';
    GETS = {
      ['env.get_win']       = ENV.get_win;
    };

    SETS = {
      ['env.set_win']       = ENV.set_win;
    };

    ENVIRONS = {
      ['env.environ_win']   = ENV.environ_win;
    };

    EXPANDS = {
      ['env.expand_win']    = ENV.expand_win;
    };
  };
  { NAME = ' (CAN NOT FAIL)LIB';
    GETS = {
      ['env.get']           = ENV.get;
      ['env.get_s']         = ENV.get_s;
    };

    SETS = {
      ['env.set']           = ENV.set;
    };

    ENVIRONS = {
      ['env.environ']       = ENV.environ;
    };

    EXPANDS = {
    };
  };
  { NAME = ' (CAN FAIL) ANY'; IGNORE = false;
    GETS = {
      ['env.get']       = ENV.get;
      ['env.get_s']     = ENV.get_s;
      ['env.get_win']   = ENV.get_win;
      ['os_getenv']     = eutil.os_getenv;
      ['os.getenv']     = os.getenv;
    };

    SETS = {
      ['env.set']       = ENV.set;
      ['env.set_win']   = ENV.set_win;
    };

    ENVIRONS = {
      ['env.environ']       = ENV.environ;
      ['env.environ_win']   = ENV.environ_win;
    };

    EXPANDS = {
      ['env.expand_win'] = ENV.expand_win;
      ['os_expand']      = eutil.os_expand;
    };
  };
}

for _, case in ipairs(TEST_CASES) do
  if not case.IGNORE then
    module( case.NAME, package.seeall, lunit.testcase )
    tutil.gen_base_tests(_M, case.GETS, case.SETS, case.EXPANDS, case.ENVIRONS)

    module( case.NAME .. '(EMPTY VALUE)' , package.seeall, lunit.testcase)
    tutil.gen_empty_tests(_M, case.GETS, case.SETS, case.EXPANDS, case.ENVIRONS)
  end
end
