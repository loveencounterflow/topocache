


# FS                        = require 'fs'
# PATH                      = require 'path'
# URL                       = require 'url'
# QUERYSTRING               = require 'querystring'
# COFFEESCRIPT              = require 'coffee-script'
# CP                        = require 'child_process'


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
    fix: ( cause_path, effect_path ) =>
      ### TAINT do we need sync & async fixing? signature? ###
      R = null
      js_source = COFFEESCRIPT.compile wrapped_source, { bare: no, filename: cause_path, }
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
    return handler null, { stdout, stderr, }


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@URL = {}

#-----------------------------------------------------------------------------------------------------------
@URL._get_relative_path = ( me, anchor, path ) -> PATH.relative anchor, PATH.resolve anchor, path
@URL._get_absolute_path = ( me, anchor, path ) -> PATH.resolve  anchor, path

#-----------------------------------------------------------------------------------------------------------
@URL.from = ( me, x, y ) =>
  return @URL.join me, x, y if x? and y?
  throw new Error "expected list or text, got a #{type}" unless ( type = CND.type_of x ) in [ 'list', 'text', ]
  return @URL.join me, x... if type is 'list'
  return x if @URL.is_url me, x
  return @URL.join me, 'file', x

#-----------------------------------------------------------------------------------------------------------
@URL.join = ( me, protocol, path ) =>
  throw new Error "expected 3 arguments, got #{arity}"  unless ( arity = arguments.length     ) is 3
  throw new Error "expected a text, got a #{type}"      unless ( type  = CND.type_of protocol ) is 'text'
  throw new Error "expected a text, got a #{type}"      unless ( type  = CND.type_of path     ) is 'text'
  #.........................................................................................................
  if ( anchor = me[ 'anchors' ][ protocol ] )?
    ### TAINT consider to use other methods for other protocols than `file` ###
    path = PATH.relative anchor, PATH.resolve anchor, path
  #.........................................................................................................
  # path = '~' + path
  return URL.format { protocol, slashes: yes, pathname: path, }

#-----------------------------------------------------------------------------------------------------------
@URL.split = ( me, url ) =>
  R         = URL.parse url, no, no
  protocol  = R[ 'protocol' ].replace /:$/g, ''
  path      = QUERYSTRING.unescape R[ 'pathname' ]
  # path      = path.replace /^\/~/g, ''
  # path   = path.replace /^\//g, ''
  #.........................................................................................................
  switch protocol
    when 'file' then path = PATH.resolve ( me[ 'anchors' ][ protocol ] ? '.' ), path
  #.........................................................................................................
  return [ protocol, path, ]

#-----------------------------------------------------------------------------------------------------------
@URL.set_anchor = ( me, protocol, anchor ) =>
  ### Anchors are reference points so you can use relative paths to files and web addresses. ###
  throw new Error "need anchor, got #{rpr anchor}" unless anchor?
  throw new Error "unable to reset anchor for protocol #{rpr protocol}" if me[ 'anchors' ][ protocol ]?
  throw new Error "unable to set anchor after adding dependency" unless @_is_fresh me
  switch protocol
    when 'file'
      me[ 'anchors' ][ protocol ] = anchor
    else
      throw new Error "unable to set anchor for protocol #{rpr protocol}"
  return null

#-----------------------------------------------------------------------------------------------------------
@URL.is_url = ( me, x ) =>
  return false unless CND.isa_text x
  return ( /^[a-z]+:\/\// ).test x


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@timestamp_from_url = ( me, url, handler ) ->
  ### TAINT use URLs as keys into info objects to avoid repeated parsing ###
  [ protocol, path, ] = @URL.split me, url
  stamper             = me[ 'stampers' ][ protocol ]
  return handler new Error "no stamper for protocol #{rpr protocol}" unless stamper?
  stamper.fetch_timestamp path, handler
