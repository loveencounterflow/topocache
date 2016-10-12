


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
read_sims = ( S, version, handler ) ->
  throw new Error "unknown version #{rpr version}" unless version in [ 'A', 'B', ]
  path  = PATH.resolve __dirname, '../test-data', 'sims.txt'
  input = D.new_stream { path, }
  Z     = null
  whisper "reading #{path}"
  input
    .pipe D.new_stream pipeline: get_read_sims_pipeline S, version
    .pipe D.$show()
    .pipe $ ( collector ) -> Z = collector
    .pipe $ 'finish', -> handler null, Z
  return null

#-----------------------------------------------------------------------------------------------------------
read_variantusage = ( S, version, handler ) ->
  throw new Error "unknown version #{rpr version}" unless version in [ 'A', ] # 'B', ]
  path  = PATH.resolve __dirname, '../test-data', 'variants-and-usages.txt'
  input = D.new_stream { path, }
  Z     = null
  whisper "reading #{path}"
  input
    .pipe D.new_stream pipeline: get_read_variantusage_pipeline S, version
    .pipe D.$show()
    .pipe $ ( collector ) -> Z = collector
    .pipe $ 'finish', -> handler null, Z
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
get_read_sims_pipeline = ( S, version ) ->
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
get_read_variantusage_pipeline = ( S, version ) ->
  throw new Error "unknown version #{rpr version}" unless version in [ 'A', ] # 'B', ]
  Z = {}
  R = []
  sims  = CACHE.get S.cache, 'sims'
  debug '34322', sims
  #.........................................................................................................
  ###
  * unwrap line
  * split line at whitespace, resulting in multiple entries per line
  * separate each entry into CJK glyph, alphabetic usage letters
  * apply SIMs
  * discard duplicates as may have arisen from SIM application
  * de-duplify usagecodes
  ###
  R.push D.$split_tsv()
  R.push $ ( [ line, ], send ) -> send line
  R.push $ (   line,    send ) -> send line.split /\s+/
  R.push $ ( entries,   send ) -> send ( ( entry.split /([^a-zA-Z]+)/ )[ 1 .. 2 ] for entry in entries )
  #.........................................................................................................
  R.push $ ( record, send ) ->
    debug '34220-1', record
    for [ source_glyph, usagecode, ], idx in record
      target_glyph = sims[ source_glyph ]
      continue unless target_glyph?
      record[ idx ][ 0 ] = target_glyph
    debug '34220-2', record
    send record
  #.........................................................................................................
  R.push $ ( record, send ) ->
    idx_by_glyph  = {}
    new_record    = []
    for [ glyph, usagecode, ] in record
      unless ( first_idx = idx_by_glyph[ glyph ] )?
        idx_by_glyph[ glyph ] = new_record.length
        new_record.push [ glyph, usagecode, ]
      else
        new_record[ first_idx ][ 1 ] += usagecode
    send new_record
  #.........................................................................................................
  R.push $ ( record, send ) ->
    for [ glyph, usagecode, ], idx in record
      new_usagecode       = ( letter for letter in 'CJKTHM' when letter in usagecode )
      record[ idx ][ 1 ]  = new_usagecode.join ''
    send record
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
module.exports = ( T, done ) ->
  step ( resume ) =>
    @_procure_test_files()
    S = {}
    #.......................................................................................................
    set_cache = ( S, key, method, parameters..., handler ) ->
      step ( resume ) ->
        whisper "retrieving data for #{key}"
        result = yield method parameters..., resume
        CACHE.set S.cache, key, result
        handler()
        return null
      return null
    #.......................................................................................................
    S.cache = CACHE.new_cache home: PATH.resolve __dirname, '../test-data'
    info "stampers:", ( Object.keys S.cache[ 'stampers' ] ).join ', '
    info "aligners:", ( Object.keys S.cache[ 'aligners' ] ).join ', '
    fixes = [
      [ 'cache::base -> cache::sims',          ( handler ) -> set_cache S, 'sims', read_sims, S, 'A', handler ]
      [ 'cache::sims -> cache::variantusage',  ( handler ) -> set_cache S, 'variantusage', read_variantusage, S, 'A', handler ]
      ]
    #.......................................................................................................
    for [ cause_and_effect, fix, ] in fixes
      [ cause, effect, ] = cause_and_effect.split /\s*->\s*/
      CACHE.register_fix S.cache, cause, effect, fix
    #.......................................................................................................
    ### make this a topocache method ###
    for box in ( CACHE.get_boxed_chart S.cache ).reverse()
      for entry in box
        [ kind, key, ] = entry.split '::'
        ### TAINT use `CACHE.touch` ###
        continue unless kind is 'cache'
        debug key, CACHE.set S.cache, key, null
    #.......................................................................................................
    urge 'chart:', CACHE._boxed_series_as_vertical_rpr S.cache, 'chart', CACHE.get_boxed_chart S.cache
    report = yield CACHE.align S.cache, { report: yes, progress: yes, }, resume
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
      sims                = yield read_sims S, 'A', resume
      sim_count           = ( Object.keys sims ).length
      whisper "read #{sim_count} SIMs"
      #.......................................................................................................
      sims                = yield read_sims S, 'B', resume
      sim_count           = ( Object.keys sims ).length
      whisper "read #{sim_count} SIMs"
      #.......................................................................................................
      variantusage        = yield read_variantusage S, 'A', resume
      variantusage_count  = ( Object.keys variantusage ).length
      whisper "read #{variantusage_count} entries for variants & usages"
    #.......................................................................................................
    done()
  #.........................................................................................................
  return null











