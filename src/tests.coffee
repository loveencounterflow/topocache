


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
@_delay = ( handler ) -> setTimeout handler, 100

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
  test @, 'timeout': 5000

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
    yield TC.HELPERS.touch g, 'f.coffee', resume; yield @_delay resume
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
    yield TC.HELPERS.touch g, 'f.coffee', resume; yield @_delay resume
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
    yield TC.HELPERS.touch g, 'f.coffee', resume; yield @_delay resume
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
@[ "find multiple faults" ] = ( T, done ) ->
  step ( resume ) =>
    g = TC.new_cache home: PATH.resolve __dirname, '../test-data'
    @_procure_test_files()
    #.......................................................................................................
    fix_1       = 'bash:coffee -c f.coffee'
    fix_2       = 'bash:coffee -c g.coffee'
    TC.register g, 'f.coffee', 'f.js', fix_1
    TC.register g, 'g.coffee', 'g.js', fix_2
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'f.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'g.js',     resume; yield @_delay resume
    urge '44300', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'f.coffee' ], [ 'g.coffee' ], [ 'f.js' ], [ 'g.js' ] ]
    T.eq ( yield TC.find_faults g, resume ), []
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'g.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'f.coffee', resume; yield @_delay resume
    urge '44300', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'g.coffee' ], [ 'g.js' ], [ 'f.js' ], [ 'f.coffee' ], ]
    faults = yield TC.find_faults g, resume
    # debug '32210', JSON.stringify faults
    T.eq faults, [{"reference":"f.js","comparison":"f.coffee","fix":"bash:coffee -c f.coffee"}]
    help JSON.stringify fault for fault in faults
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'g.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'f.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'g.coffee', resume; yield @_delay resume
    urge '44300', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'g.js' ], [ 'f.js' ], [ 'f.coffee' ], [ 'g.coffee' ], ]
    faults = yield TC.find_faults g, resume
    # debug '32210', JSON.stringify faults
    T.eq faults, [{"reference":"f.js","comparison":"f.coffee","fix":"bash:coffee -c f.coffee"},{"reference":"g.js","comparison":"g.coffee","fix":"bash:coffee -c g.coffee"}]
    help JSON.stringify fault for fault in faults
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'g.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'f.coffee', resume; yield @_delay resume
    urge '44300', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'g.js' ], [ 'f.js' ], [ 'g.coffee' ], [ 'f.coffee' ], ]
    # faults = yield TC.find_faults g, resume
    # # debug '32210', JSON.stringify faults
    # T.eq faults, [{"reference":"f.js","comparison":"f.coffee","fix":"bash:coffee -c f.coffee"},{"reference":"g.js","comparison":"g.coffee","fix":"bash:coffee -c g.coffee"}]
    # help JSON.stringify fault for fault in faults
    # #.......................................................................................................
    # fault_2     = yield TC.find_first_fault g, resume
    # if fault_2? then fix_2 = fault_2[ 'fix' ]
    # else             fix_2 = undefined
    # debug '88810', fault_2, fix_2
    # #.......................................................................................................
    done()

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


############################################################################################################
unless module.parent?
  include = [
    "create cache object"
    "register file objects"
    "find fault(s) (1)"
    "find fault(s) (non-existent file)"
    "fix fault(s) (simple case) (1)"
    "find multiple faults"
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

  # ls = ( me, path, handler ) =>
  #   step ( resume ) =>
  #     locator = PATH.resolve me[ 'home' ], path
  #     try
  #       stat  = yield ( require 'fs' ).stat locator, resume
  #       # Z     = Math.max +stat[ 'mtime' ], +stat[ 'atime' ], +stat[ 'ctime' ]
  #       Z     = +stat[ 'mtime' ]
  #     catch error
  #       throw error unless error[ 'code' ] is 'ENOENT'
  #       ### TAINT use special value to signal file missing ###
  #       Z = null
  #     handler null, Z

  # X = @
  # step ( resume ) ->
  #   g = TC.new_cache home: PATH.resolve __dirname, '../test-data'
  #   TC.register g, 'f.coffee', 'f.js', 'coffee -c f.coffee'
  #   TC.register g, 'g.coffee', 'g.js', 'coffee -c g.coffee'
  #   yield TC.HELPERS.touch g, 'f.coffee', resume; yield X._delay resume
  #   yield TC.HELPERS.touch g, 'g.coffee', resume; yield X._delay resume
  #   yield TC.HELPERS.touch g, 'g.js',     resume; yield X._delay resume
  #   yield TC.HELPERS.touch g, 'f.js',     resume; yield X._delay resume
  #   paths = [ 'f.coffee', 'f.js', 'g.coffee', 'g.js', ]
  #   paths_and_times = []
  #   #.......................................................................................................
  #   for path in paths
  #     time = yield ls g, path, resume
  #     paths_and_times.push [ path, time, ]
  #   #.......................................................................................................
  #   paths_and_times.sort ( a, b ) ->
  #     t_a = +a[ 1 ]
  #     t_b = +b[ 1 ]
  #     return +1 if t_a > t_b
  #     return -1 if t_a < t_b
  #     return  0
  #   #.......................................................................................................
  #   for [ path, time, ] in paths_and_times
  #     path_txt  = path
  #     path_txt += ' ' while path_txt.length < 20
  #     help path_txt, time
  #   #.......................................................................................................
  #   debug yield TC.fetch_boxed_trend g, resume

