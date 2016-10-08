


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
  file_count = 0
  for filename in FS.readdirSync templates_home
    file_count += +1
    source_path = PATH.resolve templates_home, filename
    target_path = PATH.resolve test_data_home, filename
    byte_count  = @_copy_file_sync source_path, target_path
    # whisper """
    #   copied #{byte_count} bytes
    #   from #{source_path}
    #   to   #{target_path}"""
  whisper "copied #{file_count} files"

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
    home        = PATH.resolve __dirname, '../test-data'
    g           = TC.new_cache { home, }
    TC.register g, 'f.coffee', 'f.js', 'bash:coffee -c test-data'
    boxed_chart = TC.get_boxed_chart g
    urge '55444', boxed_chart
    urge '55444', '\n' + rpr yield TC.fetch_boxed_trend g, resume
    warn yield TC.find_first_fault  g, resume
    urge yield TC.find_faults       g, resume
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "find fault(s) (1)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    #.......................................................................................................
    home        = PATH.resolve __dirname, '../test-data'
    g           = TC.new_cache { home, }
    yield TC.HELPERS.touch g, 'f.coffee', resume
    #.......................................................................................................
    TC.register g, 'f.coffee', 'f.js', 'bash:coffee -c test-data'
    boxed_chart =         TC.get_boxed_chart g
    boxed_trend = yield TC.fetch_boxed_trend g, resume
    first_fault = yield TC.find_first_fault  g, resume
    faults      = yield TC.find_faults       g, resume
    urge JSON.stringify boxed_chart
    urge JSON.stringify boxed_trend
    urge JSON.stringify first_fault
    urge JSON.stringify faults
    T.eq boxed_chart, [["f.coffee"],["f.js"]]
    T.eq boxed_trend, [["f.js"],["f.coffee"]]
    T.eq first_fault, {"reference":"f.js","comparison":"f.coffee","fix":"bash:coffee -c test-data"}
    T.eq faults,      [{"reference":"f.js","comparison":"f.coffee","fix":"bash:coffee -c test-data"}]
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "find fault(s) (non-existent file)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    #.......................................................................................................
    home        = PATH.resolve __dirname, '../test-data'
    g           = TC.new_cache { home, }
    yield TC.HELPERS.touch g, 'f.coffee', resume
    #.......................................................................................................
    TC.register g, 'f.coffee', 'no-such-file.js', 'bash:coffee -c test-data'
    # boxed_chart =         TC.get_boxed_chart g
    # T.throws "expected an integer number, got null", -> yield TC.fetch_boxed_trend g, resume
    try
      yield TC.fetch_boxed_trend g, resume
    catch error
      debug JSON.stringify error[ 'message' ]
      T.eq error[ 'message' ], "expected a number for timestamp of 'no-such-file.js', got null"
    # first_fault = yield TC.find_first_fault  g, resume
    # faults      = yield TC.find_faults       g, resume
    # urge JSON.stringify boxed_chart
    # urge JSON.stringify boxed_trend
    # urge JSON.stringify first_fault
    # urge JSON.stringify faults
    # T.eq boxed_chart, [["f.coffee"],["f.js"]]
    # T.eq boxed_trend, [["f.js"],["f.coffee"]]
    # T.eq first_fault, {"reference":"f.js","comparison":"f.coffee","fix":"bash:coffee -c test-data"}
    # T.eq faults,      [{"reference":"f.js","comparison":"f.coffee","fix":"bash:coffee -c test-data"}]
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "fix fault(s) (simple case) (1)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    #.......................................................................................................
    home        = PATH.resolve __dirname, '../test-data'
    g           = TC.new_cache { home, }
    yield TC.HELPERS.touch g, 'f.coffee', resume
    #.......................................................................................................
    fix_1       = 'bash:coffee -c .'
    TC.register g, 'f.coffee', 'f.js', fix_1
    fault_2     = yield TC.find_first_fault g, resume
    if fault_2? then fix_2 = fault_2[ 'fix' ]
    else             fix_2 = undefined
    #.......................................................................................................
    T.eq fix_1, fix_2
    #.......................................................................................................
    if fix_2 is fix_1
      fix = fix_2.replace /^bash:\s*/, ''
      { stderr, stdout, } = yield TC.HELPERS.shell g, fix, resume
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
@[ "fix multiple faults" ] = ( T, done ) ->
  step ( resume ) =>
    g = TC.new_cache home: PATH.resolve __dirname, '../test-data'
    @_procure_test_files()
    yield TC.HELPERS.touch g, 'f.coffee', resume
    yield TC.HELPERS.touch g, 'g.coffee', resume
    yield TC.HELPERS.touch g, 'f.js',     resume
    yield TC.HELPERS.touch g, 'g.js',     resume
    #.......................................................................................................
    fix_1       = 'bash:coffee -c f.coffee'
    fix_2       = 'bash:coffee -c g.coffee'
    TC.register g, 'f.coffee', 'f.js', fix_1
    TC.register g, 'g.coffee', 'g.js', fix_1
    T.eq ( yield TC.find_faults g, resume ), []
    yield TC.HELPERS.touch g, 'f.coffee', resume
    help '40201', TC.get_boxed_chart g
    urge '40201', yield TC.fetch_boxed_trend g, resume
    # debug '40201', ( yield TC.find_faults g, resume )
    for fault in yield TC.find_faults g, resume
      help JSON.stringify fault
    fault_2     = yield TC.find_first_fault g, resume
    if fault_2? then fix_2 = fault_2[ 'fix' ]
    else             fix_2 = undefined
    debug '88810', fault_2, fix_2
    # #.......................................................................................................
    # T.eq fix_1, fix_2
    # #.......................................................................................................
    # if fix_2 is fix_1
    #   fix = fix_2.replace /^bash:\s*/, ''
    #   { stderr, stdout, } = yield TC.HELPERS.shell g, fix, resume
    #   T.eq stderr, ''
    #   T.eq stdout, ''
    #   fault_3 = yield TC.find_first_fault g, resume
    #   T.eq fault_3, null
    # #.......................................................................................................
    # else
    #   T.fail "expected #{rpr fix_1}, got #{rpr fix_2}"
    # #.......................................................................................................
    done()



############################################################################################################
unless module.parent?
  include = [
    "create cache object"
    "register file objects"
    "find fault(s) (1)"
    "find fault(s) (non-existent file)"
    "fix fault(s) (simple case) (1)"
    "fix multiple faults"
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



