


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
touch                     = require 'touch'


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
@_touch_sync = ( path ) -> touch.sync path, { mtime: true, }

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
  TC.URL.set_anchor g, 'file', home
  T.eq g[ 'anchors' ][ 'file' ],  home
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "register file objects" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    #.......................................................................................................
    g           = TC.new_cache()
    home        = PATH.resolve __dirname, '..'
    TC.URL.set_anchor g, 'file', home
    #.......................................................................................................
    urls =
      f_coffee:           TC.URL.join g, 'test-data/f.coffee'
      f_js:               TC.URL.join g, 'test-data/f.js'
    #.......................................................................................................
    TC.register g, urls.f_coffee, urls.f_js, [ 'bash', 'coffee -c test-data', ]
    boxed_chart = TC.get_boxed_chart g
    urge '55444', boxed_chart
    urge '55444', '\n' + rpr yield TC.fetch_boxed_trend g, resume
    warn yield TC.find_first_fault  g, resume
    urge yield TC.find_faults       g, resume
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "can not set anchor after adding dependencies" ] = ( T, done ) ->
  g           = TC.new_cache()
  TC.register g, 'file:///test-data/f.coffee', 'file:///test-data/f.js', [ 'bash', 'coffee -c test-data', ]
  T.throws "unable to set anchor after adding dependency", -> TC.URL.set_anchor g, 'file', '/baz'
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "relative paths are roundtrip-invariant" ] = ( T, done ) ->
  g           = TC.new_cache()
  #.........................................................................................................
  probes = [
    { anchor: '/somewhere',   path_1: '/foo/bar/baz',   }
    { anchor: '/foo',         path_1: '/foo/bar/baz',   }
    { anchor: '/baz',         path_1: '/foo/bar/baz',   }
    { anchor: '/somewhere',   path_1: 'foo/bar/baz',    }
    { anchor: '/foo',         path_1: 'foo/bar/baz',    }
    { anchor: '/baz',         path_1: 'foo/bar/baz',    }
    ]
  #.........................................................................................................
  for { anchor, path_1, } in probes
    is_absolute = path_1.startsWith '/'
    rel_path    = TC.URL._get_relative_path null, anchor, path_1
    path_2      = TC.URL._get_absolute_path null, anchor, rel_path
    path_2      = PATH.relative anchor, path_2 unless is_absolute
    #.......................................................................................................
    warn '77687', ( CND.red path_1 ), ( CND.gold anchor ), ( CND.green rel_path ), ( CND.steel path_2 )
    # help '77687', rel_path
    # warn '77687', path_2
    T.eq path_1, path_2
  #.........................................................................................................
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "file URLs are roundtrip-invariant" ] = ( T, done ) ->
  implicit_anchor = PATH.resolve '.'
  #.........................................................................................................
  probes = [
    { anchor: '/somewhere',   path_1: 'foo',            }
    { anchor: '/somewhere',   path_1: '/foo',           }
    { anchor: null,           path_1: 'foo',            }
    { anchor: null,           path_1: '/foo',           }
    { anchor: '/somewhere',   path_1: '/foo/bar/baz',   }
    { anchor: '/foo',         path_1: '/foo/bar/baz',   }
    { anchor: '/baz',         path_1: '/foo/bar/baz',   }
    { anchor: '/somewhere',   path_1: 'foo/bar/baz',    }
    { anchor: '/foo',         path_1: 'foo/bar/baz',    }
    { anchor: '/baz',         path_1: 'foo/bar/baz',    }
    ]
  #.........................................................................................................
  for { anchor, path_1, matcher, } in probes
    g               = TC.new_cache()
    TC.URL.set_anchor g, 'file', anchor if anchor?
    is_relative     = not path_1.startsWith '/'
    url             = TC.URL.join g, path_1
    [ _, path_2, ]  = TC.URL.split g, url
    matcher         = PATH.resolve ( anchor ? implicit_anchor ), path_1
    #.......................................................................................................
    warn '77687', ( CND.red path_1 ), ( CND.gold anchor ), ( CND.green url ), ( CND.steel path_2 )
    # debug '77687', JSON.stringify { anchor, path_1, matcher: path_2, }
    T.eq path_2, matcher
  #.........................................................................................................
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "only file URLs are relativized / absolutized" ] = ( T, done ) ->
  g               = TC.new_cache()
  TC.URL.set_anchor g, 'file', anchor if anchor?
  T.eq ( TC.URL.join  g,                 [ 'bash', 'coffee -c test-data', ]... ), 'bash:///~coffee -c test-data'
  T.eq ( TC.URL.split g, TC.URL.join g,  [ 'bash', 'coffee -c test-data', ]... ), [ 'bash', 'coffee -c test-data', ]
  #.........................................................................................................
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "find fault(s) (simple case)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    @_touch_sync PATH.resolve __dirname, '../test-data/f.js'
    # @_touch_sync PATH.resolve __dirname, '../test-data/f.coffee'
    #.......................................................................................................
    g           = TC.new_cache()
    home        = PATH.resolve __dirname, '..'
    TC.URL.set_anchor g, 'file', home
    #.......................................................................................................
    urls =
      f_coffee:           TC.URL.join g, 'test-data/f.coffee'
      f_js:               TC.URL.join g, 'test-data/f.js'
    #.......................................................................................................
    TC.register g, urls.f_coffee, urls.f_js, [ 'bash', 'coffee -c test-data', ]
    boxed_chart =         TC.get_boxed_chart g
    boxed_trend = yield TC.fetch_boxed_trend g, resume
    first_fault = yield TC.find_first_fault  g, resume
    faults      = yield TC.find_faults       g, resume
    urge JSON.stringify boxed_chart
    urge JSON.stringify boxed_trend
    urge JSON.stringify first_fault
    urge JSON.stringify faults
    T.eq boxed_chart, [["file:///~test-data/f.coffee"],["file:///~test-data/f.js"]]
    T.eq boxed_trend, [["file:///~test-data/f.js"],["file:///~test-data/f.coffee"]]
    T.eq first_fault, {"reference":"file:///~test-data/f.js","comparison":"file:///~test-data/f.coffee","fix":["bash","coffee -c test-data"]}
    T.eq faults,      [{"reference":"file:///~test-data/f.js","comparison":"file:///~test-data/f.coffee","fix":["bash","coffee -c test-data"]}]
    done()

#-----------------------------------------------------------------------------------------------------------
@[ "fix fault(s) (simple case)" ] = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    @_touch_sync PATH.resolve __dirname, '../test-data/f.js'
    # @_touch_sync PATH.resolve __dirname, '../test-data/f.coffee'
    #.......................................................................................................
    g           = TC.new_cache()
    home        = PATH.resolve __dirname, '..'
    TC.URL.set_anchor g, 'file', home
    #.......................................................................................................
    urls =
      f_coffee:           TC.URL.join g, 'test-data/f.coffee'
      f_js:               TC.URL.join g, 'test-data/f.js'
    #.......................................................................................................
    protocol_1  = 'bash'
    advice_1    = 'coffee -c test-data'
    TC.register g, urls.f_coffee, urls.f_js, [ protocol_1, advice_1, ]
    fault_2     = yield TC.find_first_fault  g, resume
    if fault_2? then { fix: [ protocol_2, advice_2, ], } = fault_2
    else                    [ protocol_2, advice_2, ] = [ undefined, undefined, ]
    debug '76765', fault_2, protocol_2, advice_2
    #.......................................................................................................
    T.eq protocol_1,  protocol_2
    T.eq advice_1,    advice_2
    #.......................................................................................................
    if protocol_2 is protocol_1
      debug '33425', yield TC._shell advice_2, resume
      #.......................................................................................................
      fault_3 = yield TC.find_first_fault  g, resume
      T.eq fault_3, null
    #.......................................................................................................
    else
      T.fail "expected #{rpr protocol_1}, got #{rpr protocol_2}"
    #.......................................................................................................
    done()



############################################################################################################
unless module.parent?
  include = [
    "create cache object"
    "register file objects"
    "can not set anchor after adding dependencies"
    "relative paths are roundtrip-invariant"
    "file URLs are roundtrip-invariant"
    "only file URLs are relativized / absolutized"
    "find fault(s) (simple case)"
    "fix fault(s) (simple case)"
    ]
  @_prune()
  @_main()

  # debug '5562', JSON.stringify key for key in Object.keys @

  # CND.run =>
  # @[ "demo" ] null, -> warn "not tested"


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

