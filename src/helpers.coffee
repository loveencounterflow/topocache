



############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/HELPERS'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
# info                      = CND.get_logger 'info',      badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
alert                     = CND.get_logger 'alert',     badge
# whisper                   = CND.get_logger 'whisper',   badge
# echo                      = CND.echo.bind CND
#...........................................................................................................
# LTSORT                    = require 'ltsort'
MAIN                      = require './main'
PATH                      = require 'path'
D                         = require 'pipedreams'
{ $, $async, }            = D
{ step, }                 = require 'coffeenode-suspend'



#-----------------------------------------------------------------------------------------------------------
@shell = ( me, command, handler ) ->
  switch type = CND.type_of command
    when 'text' then @_shell_from_command_text me, command, handler
    when 'list' then @_shell_from_command_list me, command, handler
    else handler new Error "expected a list or a text, got a #{type}"
  return null

#-----------------------------------------------------------------------------------------------------------
@_shell_from_command_text = ( me, command, handler ) ->
  ### TAINT keep output length limitation in mind ###
  settings = { encoding: 'utf-8', cwd: me[ 'home' ], }
  ( require 'child_process' ).exec command, settings, ( error, stdout, stderr ) =>
    return handler error if error?
    return handler new Error stderr if stderr? and stderr.length > 0
    return handler null, stdout

#-----------------------------------------------------------------------------------------------------------
@_shell_from_command_list = ( me, command, handler ) ->
  [ command
    parameters... ] = command
  error_lines       = []
  output_lines      = []
  settings          = { cwd: me[ 'home' ], }
  cp                = ( require 'child_process' ).spawn command, parameters, settings
  #.........................................................................................................
  cp.stdout
    .pipe D.$split()
    .pipe $ ( line ) =>
      output_lines.push line
  #.........................................................................................................
  cp.stderr
    .pipe D.$split()
    .pipe $ ( line ) =>
      error_lines.push line
  #.........................................................................................................
  cp.on 'close', ( code ) =>
    message = ''
    #.......................................................................................................
    if error_lines.length > 0
      message = ( line for line in error_lines ).join '\n'
    #.......................................................................................................
    if ( code isnt 0 ) or ( message.length > 0 )
      message += '\n' if message.length > 0
      message += "command exited with code #{code}: #{command} #{parameters.join ' '}"
      alert message
      return handler new Error message
    #.......................................................................................................
    handler null, output_lines.join '\n'
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@touch = ( me, key, handler ) ->
  ### TAINT must properly escape path unless you know what you're doing ###
  [ protocol, path, ] = MAIN.split_key me, key
  throw new Error "unable to touch using protocol #{protocol}" unless protocol is 'file'
  locator             = PATH.resolve me[ 'home' ], path
  @shell me, "touch #{locator}", handler




















