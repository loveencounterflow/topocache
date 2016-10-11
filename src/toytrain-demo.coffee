


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
TC                        = require './main'
LTSORT                    = require 'ltsort'
PATH                      = require 'path'
FS                        = require 'fs'
{ step, }                 = require 'coffeenode-suspend'
#...........................................................................................................
D                         = require 'pipedreams'
{ $, $async, }            = D
require 'pipedreams/lib/plugin-tsv'



#-----------------------------------------------------------------------------------------------------------
@[ "toytrain demo" ] = ( T, done ) ->
  @_procure_test_files()
  read_sims = ->
    path  = PATH.resolve __dirname, '../test-data', 'sims.tsv'
    whisper path
    input = D.new_stream { path, }
    input
      .pipe D.$split_tsv()
      .pipe $ ( record, send ) ->
        [ _, target, _, source, ] = record
        send [ target, source, ]
      .pipe $ ( record, send ) ->
        [ target, source, ] = record
        source = source.replace /!.*$/g, ''
        send [ target, source, ]
      .pipe D.$show()
      .pipe $ 'finish', ->
        done()
  # cache_sims
  # write_sims
  # read_formulas
  # write_formulas
  # read_variantusage
  # write_variantusage
  read_sims()
  #.........................................................................................................
  return null
