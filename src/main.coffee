




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
LTSORT                    = require 'ltsort'
URL                       = require 'url'
QUERYSTRING               = require 'querystring'
FS                        = require 'fs'
PATH                      = require 'path'
CS                        = require 'coffee-script'
{ step, }                 = require 'coffeenode-suspend'


#-----------------------------------------------------------------------------------------------------------
stampers =
  #---------------------------------------------------------------------------------------------------------
  # cache:

  #---------------------------------------------------------------------------------------------------------
  file:
    # #.......................................................................................................
    # get_timestamp: ( path ) =>
    #   ### TAINT return special value when file doesn't exist ###
    #   nfo = FS.statSync path
    #   return +nfo[ 'mtime' ]

    #.......................................................................................................
    fetch_timestamp: ( path, handler ) =>
      step ( resume ) =>
        try
          stat  = yield FS.stat path, resume
          Z     = +stat[ 'mtime' ]
        catch error
          throw error unless error[ 'code' ] is 'ENOENT'
          ### TAINT use special value to signal file missing ###
          Z = null
        handler null, Z

  #---------------------------------------------------------------------------------------------------------
  coffee:
    fix: ( precedent_path, consequent_path ) =>
      ### TAINT do we need sync & async fixing? signature? ###
      R = null
      js_source = CS.compile wrapped_source, { bare: no, filename: precedent_path, }
      return R

  #---------------------------------------------------------------------------------------------------------
  # bash:
  #---------------------------------------------------------------------------------------------------------
  # method:

#-----------------------------------------------------------------------------------------------------------
@_shell = ( command, handler ) ->
  # command       = 'ls -AlF'
  settings =
    cwd:      PATH.resolve __dirname, '..'
    encoding: 'utf-8'
  CP.exec command, settings, ( error, stdout, stderr ) ->
    return handler error if error?
    return handler null, stdout, stderr


#===========================================================================================================
# TOPOCACHE MODEL IMPLEMENTATION
#-----------------------------------------------------------------------------------------------------------
@new_cache = ->
  R =
    '~isa':       'TOPOCACHE/cache'
    'graph':      LTSORT.new_graph loners: no
    'fixes':      {}
    'store':      {}
    'stampers':   Object.assign {}, stampers
    'anchors':    {}
  @_reset_chart R
  @_reset_trend R
  @URL.anchor R, 'file'
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


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@register = ( me, precedent, consequent, fix ) ->
  precedent_url     = if ( CND.isa_list  precedent ) then ( @URL.join me,  precedent... ) else  precedent
  consequent_url    = if ( CND.isa_list consequent ) then ( @URL.join me, consequent... ) else consequent
  rc_key                  = @_get_rc_key me, precedent_url, consequent_url
  me[ 'fixes' ][ rc_key ] = fix
  LTSORT.add me[ 'graph' ], precedent_url, consequent_url
  @_reset_chart me
  return null

#-----------------------------------------------------------------------------------------------------------
@get_fix = ( me, precedent, consequent, fallback ) ->
  precedent_url     = if ( CND.isa_list  precedent ) then ( @URL.join me,  precedent... ) else  precedent
  consequent_url    = if ( CND.isa_list consequent ) then ( @URL.join me, consequent... ) else consequent
  rc_key                  = @_get_rc_key me, precedent_url, consequent_url
  unless ( R = me[ 'fixes' ][ rc_key ] )?
    throw new Error "no fix for #{rpr rc_key}" if fallback is undefined
    R = fallback
  return R

#-----------------------------------------------------------------------------------------------------------
@_get_rc_key = ( me, precedent, consequent ) ->
  ### TAINT use URLs for RC key as well ###
  return "#{consequent} -> #{precedent}"


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@URL = {}

#-----------------------------------------------------------------------------------------------------------
@URL.join = ( me, protocol, path = null ) =>
  unless path?
    path      = protocol
    protocol  = 'file'
  if ( anchor = me[ 'anchors' ][ protocol ] )?
    ### TAINT consider to use other methods for other protocols ###
    ### TAINT consider to only use after testing for being a relative path ###
    path = PATH.relative anchor, PATH.resolve anchor, path
  return URL.format { protocol, slashes: yes, pathname: path, }

#-----------------------------------------------------------------------------------------------------------
@URL.split = ( me, url ) =>
  R         = URL.parse url, no, no
  protocol  = R[ 'protocol' ].replace /:$/g, ''
  path      = QUERYSTRING.unescape R[ 'pathname' ]
  # path   = path.replace /^\//g, ''
  return [ protocol, path, ]

#-----------------------------------------------------------------------------------------------------------
@URL.anchor = ( me, protocol, path ) =>
  ### Anchors are reference points so you can use relative paths to files and web addresses. ###
  switch protocol
    when 'file'
      R = me[ 'anchors' ][ protocol ] = path ? process.cwd()
    else
      throw new Error "unable to set anchor for protocol #{rpr protocol}"
  return R


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@timestamp_from_url = ( me, url, handler ) ->
  ### TAINT use URLs as keys into info objects to avoid repeated parsing ###
  [ protocol, path, ] = @URL.split me, url
  stamper             = me[ 'stampers' ][ protocol ]
  return handler new Error "no stamper for protocol #{rpr protocol}" unless stamper?
  stamper.fetch_timestamp path, handler


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
    for url of @get_indexed_chart me
      t = yield @timestamp_from_url me, url, resume
      ( collector[ t ] ?= [] ).push url
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
        ### Skip entries that have the same or smaller charting index (that are not depenedent on
        reference): ###
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





