



############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/STAMPERS'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
# info                      = CND.get_logger 'info',      badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
alert                     = CND.get_logger 'alert',     badge
# whisper                   = CND.get_logger 'whisper',   badge
# echo                      = CND.echo.bind CND
#...........................................................................................................
PATH                      = require 'path'
D                         = require 'pipedreams'
{ $, $async, }            = D
{ step, }                 = require 'coffeenode-suspend'
TC                        = require './main'


#-----------------------------------------------------------------------------------------------------------
### TAINT improve dispatching logic ###
###
@stamper = ( me, fix, handler ) ->
  try
    [ kind, command, ] = TC._kind_and_command_from_fix me, fix
  catch error
    return handler error
  switch kind
    when 'file'   then return @HELPERS.file_stamper   me, command, handler
    when 'cache'  then return @HELPERS.cache_stamper  me, command, handler
  handler new Error "unable to stamp entries of kind #{rpr kind}"
###

#-----------------------------------------------------------------------------------------------------------
@file = ( me, path, handler ) ->
  step ( resume ) =>
    locator = PATH.resolve me[ 'home' ], path
    try
      stat  = yield ( require 'fs' ).stat locator, resume
      Z     = +stat[ 'mtime' ]
    catch error
      throw error unless error[ 'code' ] is 'ENOENT'
      ### TAINT use special value to signal file missing ###
      Z = -1
    handler null, Z
  return null

#-----------------------------------------------------------------------------------------------------------
@cache = ( me, key, handler ) ->
  ### TAINT use special value to signal entry missing ###
  setImmediate =>
    # debug '33490', key, TC.get_cache_entry me, key
    handler null, ( TC.get_cache_entry me, key )?[ 't0' ] ? -1
  return null




