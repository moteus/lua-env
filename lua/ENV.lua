local eutil = require"ENV.utils"
local putil = require"ENV.utils.process"

local ENV = {}

ENV.PROC     = require ("ENV.PROC"     )

if eutil.IS_WINDOWS then
  ENV.SYS      = require ("ENV.SYS"      )
  ENV.USER     = require ("ENV.USER"     )
  ENV.VOLATILE = require ("ENV.VOLATILE" )
end

ENV.expand = putil.expand
ENV.update = putil.update

return ENV