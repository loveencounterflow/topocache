


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/TESTS'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
info                      = CND.get_logger 'info',      badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
whisper                   = CND.get_logger 'whisper',   badge
echo                      = CND.echo.bind CND
#...........................................................................................................
test                      = require 'guy-test'
TC                        = require './main'
LTSORT                    = require 'ltsort'
PATH                      = require 'path'
FS                        = require 'fs'
{ step, }                 = require 'coffeenode-suspend'
#...........................................................................................................
test_data_home            = PATH.resolve __dirname, '../test-data'
templates_home            = PATH.resolve test_data_home, 'templates'
# test_filenames            = [ 'f.coffee', 'f.js', 'a.json', ]
CP                        = require 'child_process'


#===========================================================================================================
# HELPERS
#-----------------------------------------------------------------------------------------------------------
@_prune = ->
  for name, value of @
    continue if name.startsWith '_'
    delete @[ name ] unless name in include
  return null

#-----------------------------------------------------------------------------------------------------------
@_procure_test_files = ->
  for filename in FS.readdirSync templates_home
    source_path = PATH.resolve templates_home, filename
    target_path = PATH.resolve test_data_home, filename
    byte_count  = @_copy_file_sync source_path, target_path
    whisper """
      copied #{byte_count} bytes
      from #{source_path}
      to   #{target_path}"""

#-----------------------------------------------------------------------------------------------------------
@_copy_file_sync = ( source_path, target_path ) ->
  FS.writeFileSync target_path, source = FS.readFileSync source_path
  return source.length

#-----------------------------------------------------------------------------------------------------------
@_get_source = ( path ) -> FS.readFileSync path, encoding: 'utf-8'

#-----------------------------------------------------------------------------------------------------------
@_require_file = ( path ) ->
  ### Inhibit caching: ###
  delete require[ 'cache' ][ path ]
  return require path

#-----------------------------------------------------------------------------------------------------------
@_main = ->
  # debug @_get_source PATH.resolve test_data_home, 'f.coffee'
  # debug @_require_file PATH.resolve test_data_home, 'f.js'
  test @, 'timeout': 3000

# #-----------------------------------------------------------------------------------------------------------
# f = ->
# f.apply TC = {}

#===========================================================================================================
# TESTS
#-----------------------------------------------------------------------------------------------------------
@[ "create cache object" ] = ( T, done ) ->
  g           = TC.new_cache()
  home        = PATH.resolve __dirname, '..'
  file_anchor = TC.URL.anchor g, 'file', home
  T.eq g[ 'anchors' ][ 'file' ],  home
  T.eq file_anchor,               home
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "register file objects" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    #.......................................................................................................
    g           = TC.new_cache()
    home        = PATH.resolve __dirname, '..'
    file_anchor = TC.URL.anchor g, 'file', home
    #.......................................................................................................
    urls =
    #   f_coffee_template:  TC.URL.join g, 'test-data/templates/f.coffee'
    #   a_json_template:    TC.URL.join g, 'test-data/templates/a.json'
      f_coffee:           TC.URL.join g, 'test-data/f.coffee'
      f_js:               TC.URL.join g, 'test-data/f.js'
    #   a_json:             TC.URL.join g, 'test-data/a.json'
    #   cache_f:            TC.URL.join g, 'cache', 'foo'
    # #.......................................................................................................
    # help yield TC.timestamp_from_url g, urls.f_coffee_template, resume
    # help yield TC.timestamp_from_url g, urls.f_coffee, resume
    # #.......................................................................................................
    TC.register g, urls.f_coffee, urls.f_js, [ 'bash', 'coffee -c test-data', ]
    boxed_chart = TC.get_boxed_chart g
    urge '55444', boxed_chart
    # T.eq boxed_chart, [ [ 'file:///home/flow/io/mingkwai-rack/topocache/test-data/f.coffee' ], [ 'file:///home/flow/io/mingkwai-rack/topocache/test-data/f.js' ] ]
    urge '55444', '\n' + rpr yield TC.fetch_boxed_trend g, resume
    # T.eq g[ 'anchors' ][ 'file' ], __dirname
    done()


############################################################################################################
unless module.parent?
  include = [
    "create cache object"
    "register file objects"
    ]
  # @_prune()
  @_main()

  # debug '5562', JSON.stringify key for key in Object.keys @

  # CND.run =>
  # @[ "demo" ] null, -> warn "not tested"

