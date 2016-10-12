


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/TOYTRAIN-DEMO'
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
PATH                      = require 'path'
FS                        = require 'fs'
{ step, }                 = require 'coffeenode-suspend'
#...........................................................................................................
D                         = require 'pipedreams'
{ $, $async, }            = D
require 'pipedreams/lib/plugin-tsv'
#...........................................................................................................
CACHE                     = require './main'



#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
read_sims = ( version, handler ) ->
  throw new Error "unknown version #{rpr version}" unless version in [ 'A', 'B', ]
  path  = PATH.resolve __dirname, '../test-data', 'sims.txt'
  input = D.new_stream { path, }
  Z     = null
  whisper "reading #{path}"
  input
    .pipe D.new_stream pipeline: get_read_sims_pipeline version
    .pipe D.$show()
    .pipe $ ( collector ) -> Z = collector
    .pipe $ 'finish', -> handler null, Z
  return null

#-----------------------------------------------------------------------------------------------------------
read_variantusage = ( version, handler ) ->
  throw new Error "unknown version #{rpr version}" unless version in [ 'A', ] # 'B', ]
  path  = PATH.resolve __dirname, '../test-data', 'variants-and-usages.txt'
  input = D.new_stream { path, }
  Z     = null
  whisper "reading #{path}"
  input
    .pipe D.new_stream pipeline: get_read_variantusage_pipeline version
    .pipe D.$show()
    .pipe $ ( collector ) -> Z = collector
    .pipe $ 'finish', -> handler null, Z
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
get_read_sims_pipeline = ( version ) ->
  throw new Error "unknown version #{rpr version}" unless version in [ 'A', 'B', ]
  Z = {}
  R = []
  #.........................................................................................................
  R.push D.$split_tsv()
  #.........................................................................................................
  R.push $ ( record, send ) ->
    ### discard extra fields ###
    [ _, target, _, source, ] = record
    send [ target, source, ]
  #.........................................................................................................
  if version is 'B'
    R.push $ ( record, send ) ->
      ### discard tags ###
      [ target, source, ] = record
      source = source.replace /!.*$/g, ''
      send [ target, source, ]
  #.........................................................................................................
  R.push $ 'null', ( record, send ) ->
    ### collect all records into single mapping ###
    if record?
      [ target, source, ] = record
      Z[ source ]         = target
    else
      send Z
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
get_read_variantusage_pipeline = ( version ) ->
  throw new Error "unknown version #{rpr version}" unless version in [ 'A', ] # 'B', ]
  Z = {}
  R = []
  #.........................................................................................................
  ###
  * unwrap line
  * split line at whitespace, resulting in multiple entries per line
  * separate each entry into CJK glyph, alphabetic usage letters
  ###
  R.push D.$split_tsv()
  R.push $ ( [ line, ], send ) -> send line
  R.push $ (   line,    send ) -> send line.split /\s+/
  R.push $ ( entries,   send ) -> send ( ( entry.split /([^a-zA-Z]+)/ )[ 1 .. 2 ] for entry in entries )
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
module.exports = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    t_ = Date.now()
    #.......................................................................................................
    set_cache = ( g, key, method, parameters..., handler ) ->
      step ( resume ) ->
        # do ( key ) -> urge "#{key}; #{(t0 - t_).toFixed 3}" for key, { t0, } of g[ 'store' ]
        whisper "retrieving data for #{key}"
        result = yield method parameters..., resume
        CACHE.set g, key, result
        # urge 'faults:', yield CACHE.find_faults g, resume
        # do ( key ) -> urge "#{key}; #{(t0 - t_).toFixed 3}" for key, { t0, } of g[ 'store' ]
        handler()
        return null
    #.......................................................................................................
    g = CACHE.new_cache home: PATH.resolve __dirname, '../test-data'
    info "stampers:", ( Object.keys g[ 'stampers' ] ).join ', '
    info "aligners:", ( Object.keys g[ 'aligners' ] ).join ', '
    # CACHE.register_fix g, 'cache::sim', 'cache::variantusage', [ 'call', read_sims, 'A', ]
    # CACHE.register_fix g, 'cache::sim', 'cache::variantusage', [ 'call', set_cache, g, 'sim', read_sims, 'A', ]
    fixes = [
      [ 'cache::base -> cache::sim',          ( handler ) -> set_cache g, 'sim', read_sims, 'A', handler ]
      [ 'cache::sim -> cache::variantusage',  ( handler ) -> set_cache g, 'variantusage', read_variantusage, 'A', handler ]
      ]
    for [ cause_and_effect, fix, ] in fixes
      [ cause, effect, ] = cause_and_effect.split /\s*->\s*/
      CACHE.register_fix g, cause, effect, fix
    for box in ( CACHE.get_boxed_chart g ).reverse()
      for entry in box
        [ kind, key, ] = entry.split '::'
        ### TAINT use `CACHE.touch` ###
        continue unless kind is 'cache'
        debug key, CACHE.set g, key, null
    urge 'chart:', CACHE.get_boxed_chart g
    urge 'faults:', yield CACHE.find_faults g, resume
    report = yield CACHE.align g, { report: yes, progress: yes, }, resume
    # info report
    #.......................................................................................................
    # cache_sims
    # yield write_sims,         resume
    # yield read_formulas,      resume
    # yield write_formulas,     resume
    # yield read_variantusage,  resume
    # yield write_variantusage, resume
    # sims = yield read_sims_version_A resume
    f = ->
      #.......................................................................................................
      sims                = yield read_sims 'A', resume
      sim_count           = ( Object.keys sims ).length
      whisper "read #{sim_count} SIMs"
      #.......................................................................................................
      sims                = yield read_sims 'B', resume
      sim_count           = ( Object.keys sims ).length
      whisper "read #{sim_count} SIMs"
      #.......................................................................................................
      variantusage        = yield read_variantusage 'A', resume
      variantusage_count  = ( Object.keys variantusage ).length
      whisper "read #{variantusage_count} entries for variants & usages"
    #.......................................................................................................
    done()
  #.........................................................................................................
  return null











