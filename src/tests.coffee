


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
#...........................................................................................................
test_data_home            = PATH.resolve __dirname, '../test-data'
templates_home            = PATH.resolve test_data_home, 'templates'
test_filenames            = [ 'f.coffee', 'f.js', 'a.json', ]


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
  for filename in test_filenames
    source_path = PATH.resolve templates_home, filename
    target_path = PATH.resolve test_data_home, filename
    @_copy_file_sync source_path, target_path

#-----------------------------------------------------------------------------------------------------------
@_copy_file_sync = ( source_path, target_path ) ->
  FS.writeFileSync target_path, source = FS.readFileSync source_path
  debug source
  return source.length

#-----------------------------------------------------------------------------------------------------------
@_main = ->
  @_procure_test_files()
  test @, 'timeout': 3000

# #-----------------------------------------------------------------------------------------------------------
# f = ->
# f.apply TC = {}

#===========================================================================================================
# TESTS
#-----------------------------------------------------------------------------------------------------------
@[ "create cache object" ] = ( T, done ) ->
  g = TC.new_cache()
  TC.URL.anchor g, 'file', __dirname
  T.eq g[ 'anchors' ][ 'file' ], __dirname
  done()

############################################################################################################
unless module.parent?
  include = [
    "create cache object"
    ]
  @_prune()
  @_main()

  # debug '5562', JSON.stringify key for key in Object.keys @

  # CND.run =>
  # @[ "demo" ] null, -> warn "not tested"


