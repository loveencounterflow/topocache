


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
@_touch = ( path, handler ) ->
  ### TAINT must properly escape path unless you know what you're doing ###
  TC.HELPERS.shell "touch #{path}", handler

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
  T.ok g[ 'stamper' ] is TC.HELPERS.file_stamper
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "register file objects" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    g           = TC.new_cache()
    TC.register g, 'test-data/f.coffee', 'test-data/f.js', 'bash:coffee -c test-data'
    boxed_chart = TC.get_boxed_chart g
    urge '55444', boxed_chart
    urge '55444', '\n' + rpr yield TC.fetch_boxed_trend g, resume
    warn yield TC.find_first_fault  g, resume
    urge yield TC.find_faults       g, resume
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "find fault(s) (simple case)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    yield @_touch ( PATH.resolve __dirname, '../test-data/f.coffee' ), resume
    #.......................................................................................................
    g           = TC.new_cache()
    home        = PATH.resolve __dirname, '..'
    #.......................................................................................................
    TC.register g, 'test-data/f.coffee', 'test-data/f.js', 'bash:coffee -c test-data'
    boxed_chart =         TC.get_boxed_chart g
    boxed_trend = yield TC.fetch_boxed_trend g, resume
    first_fault = yield TC.find_first_fault  g, resume
    faults      = yield TC.find_faults       g, resume
    urge JSON.stringify boxed_chart
    urge JSON.stringify boxed_trend
    urge JSON.stringify first_fault
    urge JSON.stringify faults
    T.eq boxed_chart, [["test-data/f.coffee"],["test-data/f.js"]]
    T.eq boxed_trend, [["test-data/f.js"],["test-data/f.coffee"]]
    T.eq first_fault, {"reference":"test-data/f.js","comparison":"test-data/f.coffee","fix":"bash:coffee -c test-data"}
    T.eq faults,      [{"reference":"test-data/f.js","comparison":"test-data/f.coffee","fix":"bash:coffee -c test-data"}]
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "fix fault(s) (simple case) (1)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    yield @_touch ( PATH.resolve __dirname, '../test-data/f.coffee' ), resume
    #.......................................................................................................
    g           = TC.new_cache()
    home        = PATH.resolve __dirname, '..'
    #.......................................................................................................
    # fix_1    = -> TC.HELPERS.shell 'coffee -c test-data'
    fix_1       = 'bash:coffee -c test-data'
    TC.register g, 'test-data/f.coffee', 'test-data/f.js', fix_1
    fault_2     = yield TC.find_first_fault  g, resume
    if fault_2? then fix_2 = fault_2[ 'fix' ]
    else             fix_2 = undefined
    debug '76765', fault_2, fix_2
    #.......................................................................................................
    T.eq fix_1, fix_2
    #.......................................................................................................
    if fix_2 is fix_1
      fix = fix_2.replace /^bash:\s*/, ''
      { stderr, stdout, } = yield TC.HELPERS.shell fix, resume
      T.eq stderr, ''
      T.eq stdout, ''
      fault_3 = yield TC.find_first_fault g, resume
      T.eq fault_3, null
    #.......................................................................................................
    else
      T.fail "expected #{rpr fix_1}, got #{rpr fix_2}"
    #.......................................................................................................
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "fix fault(s) (simple case) (2)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    yield @_touch ( PATH.resolve __dirname, '../test-data/f.coffee' ), resume
    #.......................................................................................................
    g           = TC.new_cache()
    #.......................................................................................................
    protocol_1  = 'bash'
    fix_1    = 'coffee -c test-data'
    TC.register g, 'test-data/f.coffee', 'test-data/f.js', [ protocol_1, fix_1, ]
    fault_2     = yield TC.find_first_fault g, resume
    # if fault_2? then { fix: [ protocol_2, fix_2, ], } = fault_2
    # else                    [ protocol_2, fix_2, ] = [ undefined, undefined, ]
    # debug '76765', fault_2, protocol_2, fix_2
    # #.......................................................................................................
    # T.eq protocol_1,  protocol_2
    # T.eq fix_1,    fix_2
    # #.......................................................................................................
    # if protocol_2 is protocol_1
    #   debug '33425', yield TC.HELPERS.shell fix_2, resume
    #   fault_3 = yield TC.find_first_fault  g, resume
    #   T.eq fault_3, null
    # #.......................................................................................................
    # else
    #   T.fail "expected #{rpr protocol_1}, got #{rpr protocol_2}"
    #.......................................................................................................
    done()



############################################################################################################
unless module.parent?
  include = [
    "create cache object"
    "register file objects"
    "find fault(s) (simple case)"
    "fix fault(s) (simple case) (1)"
    # # "fix fault(s) (simple case) (2)"
    ]
  @_prune()
  @_main()

  # debug '5562', JSON.stringify key for key in Object.keys @

  # CND.run =>
  #   @[ "fix fault(s) (simple case) (2)" ] null, -> warn "not tested"


  # debug PATH.resolve '/here', '/there'
  # debug PATH.resolve '/here', 'there'
  # debug PATH.resolve '', '/there'
  # debug PATH.resolve '', 'there'
  # debug PATH.resolve ''
  # debug PATH.resolve '.'
  # debug PATH.resolve '..'
  # debug PATH.resolve 'foo/../bar'
  # debug PATH.resolve()
  # g = TC.new_cache()
  # help TC.URL.join g, [ 'file', ( ( require 'querystring' ).escape 'foo/bar/baz.js' ), ]...

  # T = @
  # step ( resume ) ->
  #   yield T._touch '/home/flow/io/mingkwai-rack/topocache/test-data/a.json',   resume
  #   yield T._touch '/home/flow/io/mingkwai-rack/topocache/test-data/f.coffee', resume
  #   yield T._touch '/home/flow/io/mingkwai-rack/topocache/test-data/f.js',     resume


