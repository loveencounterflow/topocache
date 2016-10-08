




############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/MAIN'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
# info                      = CND.get_logger 'info',      badge
warn                      = CND.get_logger 'warn',      badge
# help                      = CND.get_logger 'help',      badge
# urge                      = CND.get_logger 'urge',      badge
# whisper                   = CND.get_logger 'whisper',   badge
# echo                      = CND.echo.bind CND
#...........................................................................................................
LTSORT                    = require 'ltsort'
{ step, }                 = require 'coffeenode-suspend'
PATH                      = require 'path'



#===========================================================================================================
# TOPOCACHE MODEL IMPLEMENTATION
#-----------------------------------------------------------------------------------------------------------
@new_cache = ( settings = null ) ->
  stamper = settings?[ 'stamper'  ] ? @HELPERS.file_stamper
  home    = settings?[ 'home'     ] ? process.cwd()
  #.........................................................................................................
  unless ( type = CND.type_of stamper ) is 'function'
    throw new Error "expected a function, got a #{type}"
  unless ( arity = stamper.length ) is 3
    throw new Error "expected a function with arity 3, got one with arity #{arity}"
  #.........................................................................................................
  R =
    '~isa':       'TOPOCACHE/cache'
    'graph':      LTSORT.new_graph loners: no
    'fixes':      {}
    'store':      {}
    'stamper':    stamper
    'home':       home
    'anchors':    {}
  #.........................................................................................................
  @_reset_chart R
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@_reset_chart = ( me ) ->
  me[ 'boxed-chart'   ] = null
  me[ 'indexed-chart' ] = null
  return me

#-----------------------------------------------------------------------------------------------------------
@_is_fresh = ( me ) -> me[ 'graph' ][ 'precedents' ].size is 0


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@register = ( me, cause, effect, fix = null ) ->
  cause_json              = JSON.stringify cause
  effect_json             = JSON.stringify effect
  rc_key                  = @_get_cause_effect_key me, cause_json, effect_json
  relation                = { cause, effect, fix, }
  me[ 'fixes' ][ rc_key ] = relation
  LTSORT.add me[ 'graph' ], cause_json, effect_json
  @_reset_chart me
  return null

#-----------------------------------------------------------------------------------------------------------
@get_fix = ( me, cause, effect, fallback ) ->
  cause_json  = JSON.stringify cause
  effect_json = JSON.stringify effect
  rc_key      = @_get_cause_effect_key me, cause_json, effect_json
  unless ( R = me[ 'fixes' ][ rc_key ] )?
    throw new Error "no fix for #{rpr rc_key}" if fallback is undefined
    R = fallback
  return R

#-----------------------------------------------------------------------------------------------------------
@_get_cause_effect_key = ( me, cause_json, effect_json ) ->
  ### TAINT wrong way around ###
  return "#{effect_json} -> #{cause_json}"


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@get_boxed_chart = ( me ) ->
  return R if ( R = me[ 'boxed-chart' ] )?
  # LTSORT.linearize me[ 'graph' ]
  R = []
  for box in LTSORT.group me[ 'graph' ]
    target = []
    R.push ( JSON.parse id_json for id_json in box )
  return me[ 'boxed-chart' ] = R

#-----------------------------------------------------------------------------------------------------------
@get_indexed_chart = ( me ) ->
  return R if ( R = me[ 'indexed-chart' ] )?
  return me[ 'indexed-chart' ] = @_indexed_from_boxed_series me, @get_boxed_chart me

#-----------------------------------------------------------------------------------------------------------
@fetch_boxed_trend = ( me, handler ) ->
  #.........................................................................................................
  step ( resume ) =>
    Z         = []
    collector = new Map()
    #.......................................................................................................
    for box in @get_boxed_chart me
      for id in box
        timestamp = yield me[ 'stamper' ] me, id, resume
        unless CND.isa_number timestamp
          return handler new Error "expected a number for timestamp of #{rpr id}, got #{rpr timestamp}"
        unless ( target = collector.get timestamp )?
          target = []
          collector.set timestamp, target
        target.push id
    #.......................................................................................................
    timestamps = Array.from collector.keys()
    timestamps.sort ( a, b ) ->
      return +1 if a > b
      return -1 if a < b
      return  0
    ( Z.push collector.get timestamp ) for timestamp in timestamps
    handler null, Z
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@fetch_indexed_trend = ( me, handler ) ->
  #.........................................................................................................
  step ( resume ) =>
    boxed_trend = yield @fetch_boxed_trend me, resume
    handler null, @_indexed_from_boxed_series me, boxed_trend
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@_indexed_from_boxed_series = ( me, boxed_series ) ->
  R = {}
  for box, box_idx in boxed_series
    R[ name ] = box_idx for name in box
  return R


#===========================================================================================================
# FAULT-FINDING
#-----------------------------------------------------------------------------------------------------------
@find_first_fault = ( me, handler ) -> @_find_faults me, yes, handler
@find_faults      = ( me, handler ) -> @_find_faults me, no,  handler

#-----------------------------------------------------------------------------------------------------------
@_find_faults = ( me, first_only, handler ) ->
  step ( resume ) =>
    boxed_chart   = @get_boxed_chart    me
    indexed_chart = @get_indexed_chart  me
    indexed_trend = yield @fetch_indexed_trend me, resume
    R             = if first_only then null else []
    #.......................................................................................................
    messages = {}
    warn_missing = ( name ) ->
      ### TAINT warn or fail? ###
      message = "not in trend: #{rpr ref_name}"
      warn message unless message of messages
      messages[ message ] = 1
      return null
    #.......................................................................................................
    for ref_name, ref_chart_idx of indexed_chart
      ref_trend_idx = indexed_trend[ ref_name ]
      #.....................................................................................................
      unless ref_trend_idx?
        warn_missing ref_name
        continue
      #.....................................................................................................
      ref_name_json = JSON.stringify ref_name
      for cmp_name_json in me[ 'graph' ][ 'precedents' ].get ref_name_json
        cmp_name = JSON.parse cmp_name_json
        cmp_trending_idx = indexed_trend[ cmp_name ]
        #...................................................................................................
        unless cmp_trending_idx?
          warn_missing cmp_name
          continue
        #...................................................................................................
        continue if cmp_trending_idx < ref_trend_idx
        #...................................................................................................
        relation  = @get_fix me, cmp_name, ref_name, null
        relation ?= { cause: comparison, effect: reference, fix: null, }
        relation  = Object.assign {}, relation
        #...................................................................................................
        if first_only
          handler null, relation
          return null
        #...................................................................................................
        R.push relation
    #.......................................................................................................
    handler null, R
    return null
  #.........................................................................................................
  return null


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@HELPERS = {}

#-----------------------------------------------------------------------------------------------------------
@HELPERS.file_stamper = ( me, path, handler ) =>
  step ( resume ) =>
    locator = PATH.resolve me[ 'home' ], path
    try
      stat  = yield ( require 'fs' ).stat locator, resume
      Z     = +stat[ 'mtime' ]
    catch error
      throw error unless error[ 'code' ] is 'ENOENT'
      ### TAINT use special value to signal file missing ###
      Z = null
    handler null, Z

#-----------------------------------------------------------------------------------------------------------
@HELPERS.shell = ( me, command, handler ) =>
  ### TAINT consider to use `spawn` so we get safe arguments ###
  # cwd:      PATH.resolve __dirname, '..'
  settings = { encoding: 'utf-8', cwd: me[ 'home' ], }
  ( require 'child_process' ).exec command, settings, ( error, stdout, stderr ) =>
    return handler error if error?
    return handler null, { stdout, stderr, }

#-----------------------------------------------------------------------------------------------------------
@HELPERS.touch = ( me, path, handler ) =>
  ### TAINT must properly escape path unless you know what you're doing ###
  locator = PATH.resolve me[ 'home' ], path
  @HELPERS.shell me, "touch #{locator}", handler




