


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/MAIN'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
# info                      = CND.get_logger 'info',      badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
alert                     = CND.get_logger 'alert',     badge
whisper                   = CND.get_logger 'whisper',   badge
# echo                      = CND.echo.bind CND
#...........................................................................................................
LTSORT                    = require 'ltsort'
PATH                      = require 'path'
D                         = require 'pipedreams'
{ $, $async, }            = D
{ step, }                 = require 'coffeenode-suspend'
@HELPERS                  = require './helpers'
@MONITORS                 = require './monitors'
@ALIGNERS                 = require './aligners'
get_monotimestamp         = require './monotimestamp'
@FILEWATCHER              = require './filewatcher'
@FILEWATCHER.main()


#===========================================================================================================
# TOPOCACHE MODEL IMPLEMENTATION
#-----------------------------------------------------------------------------------------------------------
@new_cache = ( settings = null ) ->
  # stamper = settings?[ 'stamper'  ] ? @HELPERS.stamper
  home = settings?[ 'home' ] ? process.cwd()
  # #.........................................................................................................
  # unless ( type = CND.type_of stamper ) is 'function'
  #   throw new Error "expected a function, got a #{type}"
  # unless ( arity = stamper.length ) is 3
  #   throw new Error "expected a function with arity 3, got one with arity #{arity}"
  monitors = Object.assign {}, @MONITORS, settings?[ 'monitors' ] ? null
  aligners = Object.assign {}, @ALIGNERS, settings?[ 'aligners' ] ? null
  #.........................................................................................................
  R =
    '~isa':       'TOPOCACHE/cache'
    'graph':      LTSORT.new_graph loners: no
    'home':       home
    'fixes':      {}
    'aligners':   aligners
    'monitors':   monitors
    'store':      {}
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@_is_fresh = ( me ) -> me[ 'graph' ][ 'precedents' ].size is 0


#===========================================================================================================
# CACHE PROPER
#-----------------------------------------------------------------------------------------------------------
@_now = -> get_monotimestamp()

#-----------------------------------------------------------------------------------------------------------
@set = ( me, key, value, t0 = null ) ->
  t0 ?= @_now()
  me[ 'store' ][ key ] = { t0, key, value, }
  return value

#-----------------------------------------------------------------------------------------------------------
@get = ( me, key ) -> me[ 'store' ][ key ]?[ 'value' ]

#-----------------------------------------------------------------------------------------------------------
@delete = ( me, key ) -> delete me[ 'store' ][ key ]

#-----------------------------------------------------------------------------------------------------------
@get_cache_entry = ( me, key ) -> me[ 'store' ][ key ]

#-----------------------------------------------------------------------------------------------------------
@register_change = ( me, key, t0 = null ) ->
  t0 ?= @_now()
  me[ 'store' ][ key ] = { t0, key, }
  return null

#-----------------------------------------------------------------------------------------------------------
@validate_key = ( me, role, key ) ->
  @_split_key me, role, key
  return null

#-----------------------------------------------------------------------------------------------------------
@split_key = ( me, key ) -> @_split_key me, null, key

#-----------------------------------------------------------------------------------------------------------
@_split_key = ( me, role, key ) ->
  unless ( type = CND.type_of key ) is 'text'
    throw new Error "expected a text, got a #{type}"
  unless ( R = key.split '::' ).length is 2
    throw new Error "expected a text with separator '::', got #{rpr key}"
  [ protocol, path, ] = R
  unless protocol.length > 0
    throw new Error "expected non-empty protocol, got key #{rpr key}"
  unless path.length > 0
    throw new Error "expected non-empty path, got key #{rpr key}"
  #.........................................................................................................
  ### ... more validations based on role ... ###
  #.........................................................................................................
  return R

#-----------------------------------------------------------------------------------------------------------
@_kind_and_command_from_fix = ( me, fix ) ->
  switch type = CND.type_of fix
    when 'text'
      kind    = 'text'
      command = fix
    when 'list'
      [ kind, command..., ] = fix
    when 'pod'
      { kind, } = fix
      command   = Object.assign {}, fix
    when 'function'
      kind    = 'call'
      command = [ fix, ]
    else
      throw new Error "expected a text, a list, a function or a POD, got a #{type}"
  return [ kind, command, ]


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@register_fix = ( me, cause, effect, fix = null ) ->
  @validate_key me, 'cause',  cause
  @validate_key me, 'effect', effect
  rc_key                  = @_get_cause_effect_key me, cause, effect
  relation                = { cause, effect, fix, }
  me[ 'fixes' ][ rc_key ] = relation
  LTSORT.add me[ 'graph' ], cause, effect
  return null

#-----------------------------------------------------------------------------------------------------------
@register_alignment = ( me, kind, method ) ->
  me[ 'aligners' ][ kind ] = method
  return null

#-----------------------------------------------------------------------------------------------------------
@get_fix = ( me, cause, effect, fallback ) ->
  @validate_key me, 'cause',  cause
  @validate_key me, 'effect', effect
  rc_key = @_get_cause_effect_key me, cause, effect
  unless ( R = me[ 'fixes' ][ rc_key ] )?
    return fallback unless fallback is undefined
    throw new Error "no fix for #{rpr rc_key}"
  return R

#-----------------------------------------------------------------------------------------------------------
@_get_cause_effect_key = ( me, cause, effect ) ->
  ### TAINT wrong way around ###
  return "#{effect} -> #{cause}"


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@stamp = ( me, key, handler ) ->
  [ protocol, path, ] = @split_key me, key
  unless ( stamper = me[ 'monitors' ][ protocol ] )?
    return handler new Error "no stamper for protocol #{rpr protocol}"
  stamper me, path, handler

#-----------------------------------------------------------------------------------------------------------
@get_boxed_chart = ( me ) ->
  R = []
  for box in LTSORT.group me[ 'graph' ]
    target = []
    R.push ( key for key in box )
  return R

#-----------------------------------------------------------------------------------------------------------
@get_indexed_chart = ( me ) ->
  return @_indexed_from_boxed_series me, @get_boxed_chart me

#-----------------------------------------------------------------------------------------------------------
@fetch_boxed_trend = ( me, handler ) ->
  #.........................................................................................................
  step ( resume ) =>
    Z         = []
    collector = new Map()
    #.......................................................................................................
    for box in @get_boxed_chart me
      for key in box
        timestamp = yield @stamp me, key, resume
        unless CND.isa_number timestamp
          return handler new Error "expected a number for timestamp of #{rpr key}, got #{rpr timestamp}"
        unless ( target = collector.get timestamp )?
          target = []
          collector.set timestamp, target
        target.push key
    #.......................................................................................................
    timestamps = Array.from collector.keys()
    timestamps.sort ( a, b ) ->
      return +1 if a > b
      return -1 if a < b
      return  0
    ( Z.push collector.get timestamp ) for timestamp in timestamps
    debug '30112', collector
    debug '30112', timestamps
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

#-----------------------------------------------------------------------------------------------------------
@_boxed_series_as_vertical_rpr = ( me, title, boxed_series ) ->
  R = []
  R.push '\n'
  R.push '│   ' + title
  for box in boxed_series
    R.push '├─  ' + box.join ' '
  R.push '▼'
  return R.join '\n'


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@get_ids        = ( me ) -> Array.from me[ 'graph' ][ 'precedents' ].keys()
@get_file_ids   = ( me ) -> ( id for id in ( @get_ids me ) when id.startsWith 'file::' )
@get_file_paths = ( me ) -> ( id.replace /^file::/, '' for id in ( @get_file_ids me ) )



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
      message = "not in trend: #{rpr ref_key}"
      warn message unless message of messages
      messages[ message ] = 1
      return null
    #.......................................................................................................
    for ref_key, ref_chart_idx of indexed_chart
      ref_trend_idx = indexed_trend[ ref_key ]
      #.....................................................................................................
      unless ref_trend_idx?
        warn_missing ref_key
        continue
      #.....................................................................................................
      for cmp_key in me[ 'graph' ][ 'precedents' ].get ref_key
        cmp_trend_idx = indexed_trend[ cmp_key ]
        #...................................................................................................
        unless cmp_trend_idx?
          warn_missing cmp_key
          continue
        #...................................................................................................
        continue if cmp_trend_idx < ref_trend_idx
        #...................................................................................................
        relation  = @get_fix me, cmp_key, ref_key, null
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

#-----------------------------------------------------------------------------------------------------------
@align = ( me, settings = null, handler ) =>
  switch arity = arguments.length
    when 2
      handler   = settings
      settings  = null
    when 3
      null
    else throw new Error "expected 2 or 3 arguments, got #{arity}"
  #.........................................................................................................
  report    = settings?[ 'report'   ] ? no
  progress  = settings?[ 'progress' ] ? no
  #.........................................................................................................
  runs          = []
  run_count     = 0
  Z             = { runs, t0: new Date(), }
  max_run_count = ( Object.keys me[ 'fixes' ] ).length * 2
  #.........................................................................................................
  # if progress
  #   urge '33442', "chart:", @get_boxed_chart me
  #.........................................................................................................
  step ( resume ) =>
    #.......................................................................................................
    while ( fault = yield @find_first_fault me, resume )?
      run_count += +1
      if run_count > max_run_count
        return handler ( new Error "suspecting runaway loop after #{run_count} runs" ), Z
      #.....................................................................................................
      t0                      = new Date()
      { cause, effect, fix, } = fault
      #.....................................................................................................
      try
        [ kind, command, ] = @_kind_and_command_from_fix me, fix
      catch error
        return handler error
      #.....................................................................................................
      if ( method = me[ 'aligners' ][ kind ] )?
      #.....................................................................................................
        if progress
          urge @_boxed_series_as_vertical_rpr me, 'trend', yield @fetch_boxed_trend me, resume
          whisper "align: run ##{runs.length + 1} #{cause} -> #{effect}"
        output  = yield method me, command, resume
        output ?= null
      #.....................................................................................................
      else
        return handler new Error "unknown alignment: #{rpr kind}"
      #.....................................................................................................
      t1  = new Date()
      dt  = ( t1 - t0 ) / 1000
      run = Object.assign {}, fault, { kind, command, output, t0, t1, dt, }
      if progress
        whisper "align: run ##{runs.length + 1} #{cause} -> #{effect} completed after #{dt.toFixed 3}s"
      runs.push run
    #.......................................................................................................
    Z[ 't1' ] = new Date()
    Z[ 'dt' ] = ( Z[ 't1' ] - Z[ 't0' ] ) / 1000
    #.......................................................................................................
    if report
      for run, run_idx in runs
        { cause, effect, dt, output, } = run
        help "align: run ##{run_idx + 1} #{cause} -> #{effect} completed after #{dt.toFixed 3}s"
      help "align: took #{Z[ 'dt' ].toFixed 3}s"
    #.......................................................................................................
    handler null, Z
  #.........................................................................................................
  return null

