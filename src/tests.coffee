


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
# D                         = require 'pipedreams'
# { $, $async, }            = D
{ step, }                 = require 'coffeenode-suspend'
#...........................................................................................................
test_data_home            = PATH.resolve __dirname, '../test-data'
templates_home            = PATH.resolve test_data_home, 'templates'


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
@_delay = ( handler ) -> setTimeout handler, 10
# @_delay = ( handler ) -> setTimeout handler, 1500

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
  # debug @_require_file PATH.resolve test_data_home, 'file::f.js'
  test @, 'timeout': 5000

# #-----------------------------------------------------------------------------------------------------------
# f = ->
# f.apply TC = {}

#===========================================================================================================
# TESTS
#-----------------------------------------------------------------------------------------------------------
@[ "create cache object" ] = ( T, done ) ->
  home        = PATH.resolve __dirname, '..'
  g           = TC.new_cache { home, }
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "register file objects" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    home        = PATH.resolve __dirname, '../test-data'
    g           = TC.new_cache { home, }
    TC.register_fix g, 'file::f.coffee', 'file::f.js', 'shell::coffee -c test-data'
    # debug '30020', g
    boxed_chart = TC.get_boxed_chart g
    urge '55444', boxed_chart
    urge '55444', '\n' + rpr yield TC.fetch_boxed_trend g, resume
    warn yield TC.find_first_fault  g, resume
    urge yield TC.find_faults       g, resume
    done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "register file objects with complex keys" ] = ( T, done ) ->
  @_procure_test_files()
  home        = PATH.resolve __dirname, '../test-data'
  g           = TC.new_cache { home, }
  T.throws "expected a text, got a list", -> TC.register_fix g, [ 'file', 'f.coffee', ], [ 'file', 'f.js', ], [ 'shell', 'coffee -c test-data', ]
  urge '55444', g
  done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "find fault(s) (1)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    #.......................................................................................................
    home        = PATH.resolve __dirname, '../test-data'
    g           = TC.new_cache { home, }
    yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    #.......................................................................................................
    TC.register_fix g, 'file::f.coffee', 'file::f.js', 'shell::coffee -c .'
    boxed_chart =         TC.get_boxed_chart g
    boxed_trend = yield TC.fetch_boxed_trend g, resume
    first_fault = yield TC.find_first_fault  g, resume
    faults      = yield TC.find_faults       g, resume
    urge JSON.stringify boxed_chart
    urge JSON.stringify boxed_trend
    urge JSON.stringify first_fault
    urge JSON.stringify faults
    # T.eq boxed_chart, [["file::f.coffee"],["file::f.js"]]
    # T.eq boxed_trend, [["file::f.js"],["file::f.coffee"]]
    # T.eq first_fault, {"cause":"file::f.coffee","effect":"file::f.js","fix":"shell::coffee -c test-data"}
    # T.eq faults,      [{"cause":"file::f.coffee","effect":"file::f.js","fix":"shell::coffee -c test-data"}]
    done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "find fault(s) (non-existent file)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    #.......................................................................................................
    home        = PATH.resolve __dirname, '../test-data'
    g           = TC.new_cache { home, }
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    #.......................................................................................................
    TC.register_fix g, 'file::f.coffee', 'file::no-such-file.js', 'shell::coffee -c test-data'
    # boxed_chart =         TC.get_boxed_chart g
    # T.throws "expected an integer number, got null", -> yield TC.fetch_boxed_trend g, resume
    try
      yield TC.fetch_boxed_trend g, resume
    catch error
      debug JSON.stringify error[ 'message' ]
      T.eq error[ 'message' ], "expected a number for timestamp of 'file::no-such-file.js', got null"
    # first_fault = yield TC.find_first_fault  g, resume
    # faults      = yield TC.find_faults       g, resume
    # urge JSON.stringify boxed_chart
    # urge JSON.stringify boxed_trend
    # urge JSON.stringify first_fault
    # urge JSON.stringify faults
    # T.eq boxed_chart, [["file::f.coffee"],["file::f.js"]]
    # T.eq boxed_trend, [["file::f.js"],["file::f.coffee"]]
    # T.eq first_fault, {"effect":"file::f.js","cause":"file::f.coffee","fix":"shell::coffee -c test-data"}
    # T.eq faults,      [{"effect":"file::f.js","cause":"file::f.coffee","fix":"shell::coffee -c test-data"}]
    done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "find single fault" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    #.......................................................................................................
    home        = PATH.resolve __dirname, '../test-data'
    g           = TC.new_cache { home, }
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    #.......................................................................................................
    fix_1       = 'shell::coffee -c .'
    TC.register_fix g, 'file::f.coffee', 'file::f.js', fix_1
    fault_2     = yield TC.find_first_fault g, resume
    if fault_2? then fix_2 = fault_2[ 'fix' ]
    else             fix_2 = undefined
    #.......................................................................................................
    T.eq fix_1, fix_2
    #.......................................................................................................
    if fix_2 is fix_1
      fix = fix_2.replace /^shell::\s*/, ''
      output = yield TC.HELPERS.shell g, fix, resume
      T.eq output, ''
      fault_3 = yield TC.find_first_fault g, resume
      T.eq fault_3, null
    #.......................................................................................................
    else
      T.fail "expected #{rpr fix_1}, got #{rpr fix_2}"
    #.......................................................................................................
    done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "find multiple faults" ] = ( T, done ) ->
  step ( resume ) =>
    home = PATH.resolve __dirname, '../test-data'
    g = TC.new_cache { home, }
    @_procure_test_files()
    #.......................................................................................................
    fix_1 = 'shell::coffee -c f.coffee'
    fix_2 = 'shell::coffee -c g.coffee'
    TC.register_fix g, 'file::f.coffee', 'file::f.js', fix_1
    TC.register_fix g, 'file::g.coffee', 'file::g.js', fix_2
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.js',     resume; yield @_delay resume
    urge '44300-1', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'file::f.coffee' ], [ 'file::g.coffee' ], [ 'file::f.js' ], [ 'file::g.js' ] ]
    T.eq ( yield TC.find_faults g, resume ), []
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'file::g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    urge '44300-2', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'file::g.coffee' ], [ 'file::g.js' ], [ 'file::f.js' ], [ 'file::f.coffee' ], ]
    faults = yield TC.find_faults g, resume
    # debug '32210', JSON.stringify faults
    T.eq faults, [{"effect":"file::f.js","cause":"file::f.coffee","fix":"shell::coffee -c f.coffee"}]
    help JSON.stringify fault for fault in faults
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'file::g.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.coffee', resume; yield @_delay resume
    urge '44300-3', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'file::g.js' ], [ 'file::f.js' ], [ 'file::f.coffee' ], [ 'file::g.coffee' ], ]
    faults = yield TC.find_faults g, resume
    # debug '32210', JSON.stringify faults
    T.eq faults, [{"cause":"file::f.coffee","effect":"file::f.js","fix":"shell::coffee -c f.coffee"},{"cause":"file::g.coffee","effect":"file::g.js","fix":"shell::coffee -c g.coffee"}]
    help JSON.stringify fault for fault in faults
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'file::g.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    urge '44300-4', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'file::g.js' ], [ 'file::f.js' ], [ 'file::g.coffee' ], [ 'file::f.coffee' ], ]
    help JSON.stringify fault for fault in faults
    #.......................................................................................................
    done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "align multiple faults (1)" ] = ( T, done ) ->
  step ( resume ) =>
    home = PATH.resolve __dirname, '../test-data'
    g = TC.new_cache { home, }
    @_procure_test_files()
    #.......................................................................................................
    fix_1       = 'shell::coffee -c f.coffee'
    fix_2       = 'shell::coffee -c g.coffee'
    TC.register_fix g, 'file::f.coffee',  'file::f.js', fix_1
    TC.register_fix g, 'file::g.coffee',  'file::g.js', fix_2
    TC.register_fix g, 'file::g.js',      'file::f.js', fix_1
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.js',     resume; yield @_delay resume
    urge '44300', boxed_trend = yield TC.fetch_boxed_trend g, resume
    T.eq boxed_trend, [ [ 'file::f.coffee' ], [ 'file::g.coffee' ], [ 'file::f.js' ], [ 'file::g.js' ] ]
    faults = yield TC.find_faults g, resume
    debug '22122', JSON.stringify faults
    T.eq faults, [{"cause":"file::g.js","effect":"file::f.js","fix":"shell::coffee -c f.coffee"}]
    help JSON.stringify fault for fault in faults
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    urge '44300', boxed_trend = yield TC.fetch_boxed_trend g, resume
    # T.eq boxed_trend, [ [ 'file::f.coffee' ], [ 'file::g.coffee' ], [ 'file::f.js' ], [ 'file::g.js' ] ]
    faults = yield TC.find_faults g, resume
    debug '22122', JSON.stringify faults
    T.eq faults, [{"cause":"file::g.coffee","effect":"file::g.js","fix":"shell::coffee -c g.coffee"},{"cause":"file::f.coffee","effect":"file::f.js","fix":"shell::coffee -c f.coffee"},{"cause":"file::g.js","effect":"file::f.js","fix":"shell::coffee -c f.coffee"}]
    first_fault = yield TC.find_first_fault g, resume
    T.eq first_fault, faults[ 0 ]
    help JSON.stringify fault for fault in faults
    #.......................................................................................................
    fix_count = 0
    while ( fault = yield TC.find_first_fault g, resume )?
      urge fault
      fix_count += +1
      if fix_count > 10
        T.fail "runaway loop?"
        break
      { fix, }  = fault
      [ protocol, command, ]  = TC.split_key g, fix
      if protocol is 'shell'
        output = yield TC.HELPERS.shell g, command, resume
        T.eq output, ''
      else
        T.fail "expected protocol to be 'shell', got #{rpr protocol} from key #{rpr fail}"
      help yield TC.HELPERS.shell g, "ls -l -tr ./", resume
      # help yield TC.HELPERS.shell g, "ls -l -tr --full-time ./", resume
    #.......................................................................................................
    T.eq fix_count, 2
    info TC.get_boxed_chart g
    help g
    done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "align multiple faults (2)" ] = ( T, done ) ->
  step ( resume ) =>
    home = PATH.resolve __dirname, '../test-data'
    g = TC.new_cache { home, }
    @_procure_test_files()
    #.......................................................................................................
    TC.register_fix g, 'file::f.coffee',  'file::f.js', [ 'shell', [ 'coffee', '-c', 'f.coffee', ], ]
    TC.register_fix g, 'file::g.coffee',  'file::g.js', [ 'shell', 'coffee -c g.coffee', ]
    TC.register_fix g, 'file::g.js',      'file::f.js', [ 'shell', [ 'coffee', '-c', 'f.coffee', ], ]
    #.......................................................................................................
    yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.js',     resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::g.coffee', resume; yield @_delay resume
    yield TC.HELPERS.touch g, 'file::f.coffee', resume; yield @_delay resume
    # urge '44300', boxed_trend = yield TC.fetch_boxed_trend g, resume
    # T.eq boxed_trend, [ [ 'file::f.coffee' ], [ 'file::g.coffee' ], [ 'file::f.js' ], [ 'file::g.js' ] ]
    fault = yield TC.find_first_fault g, resume
    # debug JSON.stringify fault
    T.eq fault, {"cause":"file::g.coffee","effect":"file::g.js","fix":["shell","coffee -c g.coffee"]}
    #.....................................................................................................
    report = yield TC.align g, resume
    info report
    T.eq report[ 'runs' ]?.length, 2
    T.eq report[ 'runs' ]?[ 0 ]?[ 'cause' ], 'file::g.coffee'
    T.eq report[ 'runs' ]?[ 1 ]?[ 'cause' ], 'file::f.coffee'
    T.eq report[ 'runs' ]?[ 0 ]?[ 'kind'  ], 'shell'
    T.eq report[ 'runs' ]?[ 1 ]?[ 'kind'  ], 'shell'
    help yield TC.HELPERS.shell g, "ls -l -tr ./", resume
    # help yield TC.HELPERS.shell g, "ls -l -tr --full-time ./", resume
    done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "fixes can be strings, lists" ] = ( T, done ) ->
  step ( resume ) =>
    home = PATH.resolve __dirname, '../test-data'
    g = TC.new_cache { home, }
    #.......................................................................................................
    TC.register_fix g, 'file::f.coffee',  'file::f.js', [ 'shell', [ 'coffee', '-c', 'f.coffee', ], ]
    TC.register_fix g, 'file::f.coffee',  'file::f.js', [ 'shell', 'coffee -c g.coffee', ]
    TC.register_fix g, 'file::f.coffee',  'file::f.js', 'shell::coffee -c g.coffee'
    #.......................................................................................................
    fixes = [
      [ 'shell', [ 'coffee', '-c', 'f.coffee', ], ]
      [ 'shell', 'coffee -c g.coffee', ]
      'shell::coffee -c g.coffee'
      ]
    for fix in fixes
      urge ( CND.orange rpr fix ), ( CND.steel rpr "json::#{JSON.stringify fix}" )
    #.......................................................................................................
    done()
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@[ "toytrain demo" ] = require './toytrain-demo'


#-----------------------------------------------------------------------------------------------------------
@[ "catalog" ] = ( T, done ) ->
  # f = ->
  #   @compile_catalog = ( me, handler ) ->
  #     step ( resume ) =>
  #       for path in paths
  # f.apply TC.FILEWATCHER
  step ( resume ) =>
    home = PATH.resolve __dirname, '../test-data'
    g = TC.new_cache { home, }
    #.......................................................................................................
    TC.register_fix g, 'x::foo',  'x::bar'
    TC.register_fix g, 'file::f.coffee',  'file::f.js', [ 'shell', [ 'coffee', '-c', 'f.coffee', ], ]
    TC.register_fix g, 'file::f.coffee',  'file::f.js', [ 'shell', 'coffee -c g.coffee', ]
    TC.register_fix g, 'file::f.coffee',  'file::f.js', 'shell::coffee -c g.coffee'
    debug TC.get_ids        g
    debug TC.get_file_ids   g
    debug TC.get_file_paths g
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "toposort of fixes" ] = ( T, done ) ->
  throw new Error "test not ready"
  step ( resume ) =>
    g = TC.new_cache home: PATH.resolve __dirname, '../test-data'
    # @_procure_test_files()
    #.......................................................................................................
    fix_1       = [ 'shell', 'coffee -c f.coffee', ]
    fix_2       = [ 'shell', 'coffee -c g.coffee', ]
    TC.register_fix g, 'f.coffee',  'file::f.js', fix_1
    TC.register_fix g, 'file::g.coffee',  'file::g.js', fix_2
    TC.register_fix g, 'file::g.js',      'file::f.js', fix_1
    # #.......................................................................................................
    # yield TC.HELPERS.touch g, 'file::f.js',     resume; yield @_delay resume
    # yield TC.HELPERS.touch g, 'file::g.js',     resume; yield @_delay resume
    # yield TC.HELPERS.touch g, 'file::g.coffee', resume; yield @_delay resume
    # yield TC.HELPERS.touch g, 'f.coffee', resume; yield @_delay resume
    # faults = yield TC.find_faults g, resume
    # help JSON.stringify fault for fault in faults
    #.......................................................................................................
    info TC.get_boxed_chart g
    # help g
    fxg = TC.new_cache()
    for _, relation of g[ 'fixes' ]
      { cause, effect, fix, } = relation
      whisper "#{rpr cause} >—— #{rpr fix} ——> #{rpr effect}"
      fix_txt = if CND.isa_text fix then fix else JSON.stringify fix
      TC.register_fix fxg, cause,   fix_txt
      TC.register_fix fxg, fix_txt, effect
    urge TC.get_boxed_chart fxg
    done()
  #.........................................................................................................
  return null


############################################################################################################
unless module.parent?
  include = [
    # "create cache object"
    # "register file objects"
    # "register file objects with complex keys"
    # "find fault(s) (1)"
    # "find fault(s) (non-existent file)"
    # "find single fault"
    # "find multiple faults"
    # "align multiple faults (1)"
    # "align multiple faults (2)"
    # "fixes can be strings, lists"
    # "toytrain demo"
    "catalog"
    # # "toposort of fixes"
    ]
  @_prune()
  # @_main()
  @[ "catalog" ]()

  test_timer_resolution = ->
    step ( resume ) ->
      g = TC.new_cache()
      now1 = Date.now
      now = require './monotimestamp'
      d1 = [ now1(), now1(), now1(), now1(), now1(), now1(), now1(), ]
      d2 = [ now(), now(), now(), now(), now(), now(), now(), ]
      help d1
      help d2
      t0 = now()
      yield TC.HELPERS.touch g, 'file::test-data/f.coffee', resume
      yield TC.HELPERS.touch g, 'file::test-data/g.coffee', resume
      t1 = now()
      t_f = ( yield FS.stat 'test-data/f.coffee', resume ).mtime.getTime()
      t_g = ( yield FS.stat 'test-data/g.coffee', resume ).mtime.getTime()
      urge t0
      help t_f
      help t_g
      urge t1
      info CND.truth t0 < t_f < t_g < t1

  # debug '5562', JSON.stringify key for key in Object.keys @

  # CND.run =>
  #   @[ "find multiple faults" ] null, -> warn "not tested"

###
  step ( resume ) ->
    # stamper = ( me, id, handler ) ->
    #   debug rpr id
    #   process.exit()
    #.......................................................................................................
    f = ->
      if ( R = TC.get graph, 'result of f()' )?
        whisper "result of f(): from cache"
        return R
      whisper "result of f(): computed"
      return TC.set graph, 'result of f()', 42 * 2

    #.......................................................................................................
    # stamper = TC.HELPERS.cache_stamper
    # graph   = TC.new_cache { stamper, }
    graph   = TC.new_cache()
    TC.register_fix graph, [ 'cache', 'definition of f', ], [ 'cache', 'result of f()', ], [ 'call', ( => TC.delete graph, 'result of f()' ), ]
    TC.register_change graph, 'definition of f'
    #.......................................................................................................
    debug 'trend:', yield TC.fetch_boxed_trend  graph, resume
    help  'faults:', yield TC.find_faults        graph, resume
    #.......................................................................................................
    urge graph[ 'store' ]
    urge graph[ 'store' ]
    #.......................................................................................................
    debug 'trend:', yield TC.fetch_boxed_trend  graph, resume
    help  'faults:', yield TC.find_faults        graph, resume
    #.......................................................................................................
    debug f()
    debug f()
    #.......................................................................................................
    debug 'trend:', yield TC.fetch_boxed_trend  graph, resume
    help  'faults:', yield TC.find_faults        graph, resume
    #.......................................................................................................
    TC.register_change graph, 'definition of f'
    #.......................................................................................................
    debug 'trend:', yield TC.fetch_boxed_trend  graph, resume
    help  'faults:', yield TC.find_faults        graph, resume
    #.......................................................................................................
    info yield TC.align graph, resume
    urge graph[ 'store' ]
    #.......................................................................................................
    debug f()
    debug f()
    #.......................................................................................................
    urge graph[ 'store' ]
###

