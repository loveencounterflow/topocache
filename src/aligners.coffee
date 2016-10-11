



############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/ALIGNERS'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
# info                      = CND.get_logger 'info',      badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
alert                     = CND.get_logger 'alert',     badge
# whisper                   = CND.get_logger 'whisper',   badge
# echo                      = CND.echo.bind CND
#...........................................................................................................
# PATH                      = require 'path'
# D                         = require 'pipedreams'
# { $, $async, }            = D
{ step, }                 = require 'coffeenode-suspend'
TC                        = require './main'


#-----------------------------------------------------------------------------------------------------------
@shell = ( me, command, handler ) ->
  if ( arity = command.length isnt 1 )
    throw new Error "expected single argument, got #{arity} (#{rpr kind}, #{rpr command})"
  command = command[ 0 ]
  TC.HELPERS.shell me, command, ( error, output ) ->
    return handler error if error?
    handler null, output

#-----------------------------------------------------------------------------------------------------------
@call = ( me, method_and_parameters, handler ) ->
  [ method, parameters..., ] = method_and_parameters
  unless ( type = CND.type_of method ) is 'function'
    return handler new Error "expected a function, got a #{type}"
  ### TAINT allow synchronous functions? ###
  method parameters..., ( error, output ) ->
    return handler error if error?
    handler null, output




