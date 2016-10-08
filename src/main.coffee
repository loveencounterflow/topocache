




############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/MAIN'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
# info                      = CND.get_logger 'info',      badge
# warn                      = CND.get_logger 'warn',      badge
# help                      = CND.get_logger 'help',      badge
# urge                      = CND.get_logger 'urge',      badge
# whisper                   = CND.get_logger 'whisper',   badge
# echo                      = CND.echo.bind CND
#...........................................................................................................
LTSORT                    = require 'ltsort'
{ step, }                 = require 'coffeenode-suspend'



#===========================================================================================================
# TOPOCACHE MODEL IMPLEMENTATION
#-----------------------------------------------------------------------------------------------------------
@new_cache = ( stamper = null ) ->
  stamper ?= @HELPERS.file_stamper
  #.........................................................................................................
  unless ( type = CND.type_of stamper ) is 'function'
    throw new Error "expected a function, got a #{type}"
  unless ( arity = stamper.length ) is 2
    throw new Error "expected a function with arity 2, got one with arity #{arity}"
  #.........................................................................................................
  R =
    '~isa':       'TOPOCACHE/cache'
    'graph':      LTSORT.new_graph loners: no
    'fixes':      {}
    'store':      {}
    'stamper':    stamper
    'anchors':    {}
  #.........................................................................................................
  @_reset_chart R
  @_reset_trend R
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@_reset_chart = ( me ) ->
  me[ 'boxed-chart'   ] = null
  me[ 'indexed-chart' ] = null
  return me

#-----------------------------------------------------------------------------------------------------------
@_reset_trend = ( me ) ->
  me[ 'boxed-trend'   ] = null
  me[ 'indexed-trend' ] = null
  return me

#-----------------------------------------------------------------------------------------------------------
@_is_fresh = ( me ) -> me[ 'graph' ][ 'precedents' ].size is 0


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@HELPERS = {}

#-----------------------------------------------------------------------------------------------------------
@HELPERS.file_stamper = ( path, handler ) =>
  step ( resume ) =>
    try
      stat  = yield ( require 'fs' ).stat path, resume
      Z     = +stat[ 'mtime' ]
    catch error
      throw error unless error[ 'code' ] is 'ENOENT'
      ### TAINT use special value to signal file missing ###
      Z = null
    handler null, Z

#-----------------------------------------------------------------------------------------------------------
@HELPERS.shell = ( command, handler ) ->
  ### TAINT consider to use `spawn` so we get safe arguments ###
  # cwd:      PATH.resolve __dirname, '..'
  settings = { encoding: 'utf-8', }
  ( require 'child_process' ).exec command, settings, ( error, stdout, stderr ) ->
    return handler error if error?
    return handler null, { stdout, stderr, }


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@register = ( me, cause, effect, fix ) ->
  throw new Error "expected a text, got a #{type}" unless ( type = CND.type_of cause  ) is 'text'
  throw new Error "expected a text, got a #{type}" unless ( type = CND.type_of effect ) is 'text'
  throw new Error "expected a text, got a #{type}" unless ( type = CND.type_of fix    ) is 'text'
  rc_key                  = @_get_rc_key me, cause, effect
  me[ 'fixes' ][ rc_key ] = fix
  LTSORT.add me[ 'graph' ], cause, effect
  @_reset_chart me
  return null

#-----------------------------------------------------------------------------------------------------------
@get_fix = ( me, cause, effect, fallback ) ->
  throw new Error "expected a text, got a #{type}" unless ( type = CND.type_of cause  ) is 'text'
  throw new Error "expected a text, got a #{type}" unless ( type = CND.type_of effect ) is 'text'
  rc_key                  = @_get_rc_key me, cause, effect
  unless ( R = me[ 'fixes' ][ rc_key ] )?
    throw new Error "no fix for #{rpr rc_key}" if fallback is undefined
    R = fallback
  return R

#-----------------------------------------------------------------------------------------------------------
@_get_rc_key = ( me, cause, effect ) ->
  ### TAINT use URLs for RC keys? ###
  return "#{effect} -> #{cause}"


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@get_boxed_chart = ( me ) ->
  return R if ( R = me[ 'boxed-chart' ] )?
  LTSORT.linearize me[ 'graph' ]
  return me[ 'boxed-chart' ] = LTSORT.group me[ 'graph' ]

#-----------------------------------------------------------------------------------------------------------
@get_indexed_chart = ( me ) ->
  return R if ( R = me[ 'indexed-chart' ] )?
  return me[ 'indexed-chart' ] = @_indexed_from_boxed_series me, @get_boxed_chart me

#-----------------------------------------------------------------------------------------------------------
@fetch_boxed_trend = ( me, handler ) ->
  if ( Z = me[ 'boxed-trend' ] )?
    setImmediate -> handler null, Z
    return null
  #.........................................................................................................
  step ( resume ) =>
    Z         = []
    collector = {}
    for id of @get_indexed_chart me
      t = yield me[ 'stamper' ] id, resume
      ( collector[ t ] ?= [] ).push id
    Z.push collector[ t ] for t in ( Object.keys collector ).sort()
    handler null, me[ 'boxed-trend' ] = Z
  #.........................................................................................................
  return null

#-----------------------------------------------------------------------------------------------------------
@fetch_indexed_trend = ( me, handler ) ->
  if ( Z = me[ 'indexed-trend' ] )?
    setImmediate -> handler null, Z
    return null
  #.........................................................................................................
  step ( resume ) =>
    boxed_trend = yield @fetch_boxed_trend me, resume
    Z           = me[ 'indexed-trend' ] = @_indexed_from_boxed_series me, boxed_trend
    handler null, Z
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
    @_reset_trend me
    indexed_chart = @get_indexed_chart me
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
    for ref_name, ref_charting_idx of indexed_chart
      unless ( ref_trending_idx = indexed_trend[ ref_name ] )?
        warn_missing ref_name
        continue
      #.....................................................................................................
      for cmp_name, cmp_charting_idx of indexed_chart
        ### Skip entries with same or smaller charting index (that do not depend on reference): ###
        continue if ref_charting_idx <= cmp_charting_idx
        unless ( cmp_trending_idx = indexed_trend[ cmp_name ] )?
          warn_missing cmp_name
          continue
        #...................................................................................................
        ### A fault is indicated by the trending index being in violation of the dependency relation
        as expressed by the charting index: ###
        unless ref_trending_idx > cmp_trending_idx
          entry =
            reference:  ref_name
            comparison: cmp_name
            fix:        @get_fix me, cmp_name, ref_name, null
          #.................................................................................................
          if first_only
            handler null, entry
            return null
          #.................................................................................................
          R.push entry
    #.......................................................................................................
    handler null, R
    return null
  #.........................................................................................................
  return null





