


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


#===========================================================================================================
#
#-----------------------------------------------------------------------------------------------------------
@main = ->
  watcher = CKD.watch()
  watcher.add PATH.resolve __dirname, '..', 'test-data'
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
@checksum_from_path = ( path, handler ) ->
  input = D.new_stream { path, }
  crc32 = new Crc32.CRC32()
  input
    .pipe $ ( data, send ) -> crc32.update data
    .pipe $ 'finish', => handler null, crc32.crc()
  return null



############################################################################################################
unless module.parent?
  @main()
