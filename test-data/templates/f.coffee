

FS = require 'fs'
TC = require '..'


#-----------------------------------------------------------------------------------------------------------
@_f_from_cache = ->
  FS.readFileSync TC.as_url g, 'cache', 'f'

#-----------------------------------------------------------------------------------------------------------
@_f_recalculate  = ->
  a_url     = TC.as_url g, 'file',  'a.json'
  cache_url = TC.as_url g, 'cache', 'f'
  a_value   = FS.read_json a_url
  FS.write cache_url, a_value[ 'x' ] + 3

#-----------------------------------------------------------------------------------------------------------
@f = ->
  return R if ( R = @_f_from_cache() )?
  return @_f_recalculate()



