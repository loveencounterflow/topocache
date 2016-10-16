


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/FILEWATCHER'
log                       = CND.get_logger 'plain',     badge
debug                     = CND.get_logger 'debug',     badge
info                      = CND.get_logger 'info',      badge
warn                      = CND.get_logger 'warn',      badge
help                      = CND.get_logger 'help',      badge
urge                      = CND.get_logger 'urge',      badge
whisper                   = CND.get_logger 'whisper',   badge
echo                      = CND.echo.bind CND
#...........................................................................................................
PATH                      = require 'path'
#...........................................................................................................
CKD                       = require 'chokidar'
get_monotimestamp         = require './monotimestamp'
Crc32                     = require 'sse4_crc32'
TC                        = require './main'
D                         = require 'pipedreams'
{ $, $async, }            = D
{ step, }                 = require 'coffeenode-suspend'


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@main = ->
  watcher = CKD.watch()
  path    = PATH.resolve __dirname, '..', 'test-data'
  debug '99031', "file watcher: #{path}"
  watcher.add path
  watcher.on 'change', ( path, nfo ) =>
    info ( get_monotimestamp().toFixed 3 ), CND.steel 'change:', path
  # watcher.on 'add',       ( P... ) => info Date.now(), CND.rainbow 'add:        ', JSON.stringify P
  # watcher.on 'addDir',    ( P... ) => info Date.now(), CND.rainbow 'addDir:     ', JSON.stringify P
  # watcher.on 'unlink',    ( P... ) => info Date.now(), CND.rainbow 'unlink:     ', JSON.stringify P
  # watcher.on 'unlinkDir', ( P... ) => info Date.now(), CND.rainbow 'unlinkDir:  ', JSON.stringify P
  # watcher.on 'ready',     ( P... ) => info Date.now(), CND.rainbow 'ready:      ', JSON.stringify P
  # watcher.on 'raw',       ( P... ) => info Date.now(), CND.rainbow 'raw:        ', JSON.stringify P
  # watcher.on 'error',     ( P... ) => info Date.now(), CND.rainbow 'error:      ', JSON.stringify P
  return null

#-----------------------------------------------------------------------------------------------------------
@checksum_from_path = ( me, path, fallback, handler ) ->
  switch arity = arguments.length
    when 3
      handler   = fallback
      fallback  = undefined
    when 4
      null
    else throw new Error "expect 3 or 4 arguments, got #{arity}"
  crc32     = new Crc32.CRC32()
  finished  = no
  # input     = ( require 'fs' ).createReadStream path
  input = D.new_stream { path, }
  #.........................................................................................................
  input.on 'error', ( error ) ->
    throw error if finished
    finished = yes
    return handler null, fallback unless fallback is undefined
    handler error
  #.........................................................................................................
  input
    .pipe $ ( data, send ) -> crc32.update data
    .pipe $ 'finish', =>
      return if finished
      finished = yes
      handler null, crc32.crc()
  return null

#-----------------------------------------------------------------------------------------------------------
@_get_crc = ( text ) -> Crc32.calculate text

#-----------------------------------------------------------------------------------------------------------
@compile_catalog = ( me, handler ) ->
  Z = {}
  step ( resume ) =>
    for path in TC.get_file_paths me
      locator   = TC.locator_from_path me, path
      checksum  = yield @checksum_from_path me, locator, 0, resume
      Z[ path ] = { path, checksum, }
    handler null, Z
  return null

#-----------------------------------------------------------------------------------------------------------
@$add_crc = ( me, fallback ) ->
  return $async ( nfo ) =>
    step ( resume ) =>
      { path }          = nfo
      locator           = TC.locator_from_path me, path
      nfo[ 'checksum' ] = yield @checksum_from_path me, locator, fallback, resume
      return null
    return null


############################################################################################################
@_default_catalog_home = PATH.resolve "/tmp/topocache-catalog-#{@_get_crc __dirname}"
try
  ( require 'fs' ).mkdirSync @_default_catalog_home
catch error
  throw error unless error[ 'code' ] is 'EEXIST'


# ############################################################################################################
# unless module.parent?
@main()










