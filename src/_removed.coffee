


# FS                        = require 'fs'
# PATH                      = require 'path'
# URL                       = require 'url'
# QUERYSTRING               = require 'querystring'
# COFFEESCRIPT              = require 'coffee-script'


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




#===========================================================================================================
# TESTS
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
    url             = TC.URL.join g, 'file', path_1
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
  T.eq ( TC.URL.join  g,                 [ 'bash', 'coffee -c test-data', ]... ), 'bash:///coffee -c test-data'
  T.eq ( TC.URL.split g, TC.URL.join g,  [ 'bash', 'coffee -c test-data', ]... ), [ 'bash', 'coffee -c test-data', ]
  #.........................................................................................................
  done()



#-----------------------------------------------------------------------------------------------------------
@[ "URL.is_url" ] = ( T, done ) ->
  probes_and_matchers = [
    [ null,                                            no,  ]
    [ '',                                              no,  ]
    [ [ 'file', 'foo/bar', ],                          no,  ]
    [ 'foo/bar',                                       no,  ]
    [ 'file://foo/bar',                                yes, ]
    [ 'file:///foo/bar',                               yes, ]
    [ 'file:///~foo/bar',                              yes, ]
    [ 'http://languagelog.ldc.upenn.edu/nll/?p=28689', yes, ]
    ]
  #.........................................................................................................
  for [ probe, matcher, ] in probes_and_matchers
    urge ( CND.white rpr probe ), ( CND.truth TC.URL.is_url null, probe )
    T.eq ( TC.URL.is_url null, probe ), matcher
  #.........................................................................................................
  done()

#-----------------------------------------------------------------------------------------------------------
@[ "URL.from" ] = ( T, done ) ->
  g                   = TC.new_cache()
  probes_and_matchers = [
    # [ [ null,                                            ], null,  ]
    [ [ '',                                              ], null,  ]
    [ [ [ 'file', 'foo/bar', ],                          ], null,  ]
    [ [ [ 'http', 'domain.com/foo/bar', ],                          ], null,  ]
    [ [ 'foo/bar',                                       ], null,  ]
    [ [ 'file://foo/bar',                                ], null, ]
    [ [ 'file:///foo/bar',                               ], null, ]
    [ [ 'file:///~foo/bar',                              ], null, ]
    [ [ 'http://languagelog.ldc.upenn.edu/nll/?p=28689', ], null, ]
    ]
  #.........................................................................................................
  for [ probe, matcher, ] in probes_and_matchers
    urge ( CND.white rpr probe ), ( CND.gold rpr TC.URL.from g, probe... )
    # T.eq ( TC.URL.is_url null, probe ), matcher
  #.........................................................................................................
  done()








