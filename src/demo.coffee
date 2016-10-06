


############################################################################################################
CND                       = require 'cnd'
rpr                       = CND.rpr
badge                     = 'TOPOCACHE/DEMO'
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
test                      = require 'guy-test'
TC                        = require './main'
LTSORT                    = require 'ltsort'
{ step, }                 = require 'coffeenode-suspend'
resolve                   = ( require 'path' ).resolve


# #===========================================================================================================
# # FILE SYSTEM SIMULATOR
# #-----------------------------------------------------------------------------------------------------------
# FS        = {}
# FS._t     = 1000
# FS.cache  = {}

# #-----------------------------------------------------------------------------------------------------------
# FS._now = ->
#   return @_t += +1

# #-----------------------------------------------------------------------------------------------------------
# FS.write = ( name, value ) ->
#   t = @_now()
#   @cache[ name ] = { t, value, }
#   return value

# #-----------------------------------------------------------------------------------------------------------
# FS.read = ( name ) ->
#   return undefined unless ( R = FS.cache[ name ] )?
#   return R.value

# #-----------------------------------------------------------------------------------------------------------
# FS.read_json = ( name ) ->
#   json = @read name
#   try
#     return JSON.parse json
#   catch error
#     warn "invalid JSON for #{rpr name}: #{rpr json}"
#     throw error

# #-----------------------------------------------------------------------------------------------------------
# FS.write_json = ( name, value ) -> @write name, JSON.stringify value

# #-----------------------------------------------------------------------------------------------------------
# FS.fetch_cache = ( handler ) ->
#   setImmediate => handler null, @cache
#   return null

# XXX = {}

# #-----------------------------------------------------------------------------------------------------------
# XXX.cmp = ( name_a, name_b ) ->
#   throw new Error "unknown name #{rpr name_a}" unless ( entry_a = FS.cache[ name_a ] )?
#   throw new Error "unknown name #{rpr name_b}" unless ( entry_b = FS.cache[ name_b ] )?
#   return -1 if entry_a.t < entry_b.t
#   return +1 if entry_a.t > entry_b.t
#   return  0

# #-----------------------------------------------------------------------------------------------------------
# XXX.test_cromulence = ( reference, comparators... ) ->
#   throw new Error "need at least one comparator, got none" unless comparators.length > 0
#   for comparator in comparators
#     return false if ( @cmp reference, comparator ) < 0
#   return true

f = ->
  FS = require 'fs'

f.apply TC

#-----------------------------------------------------------------------------------------------------------
main = ->
  step ( resume ) ->
    g = TC.new_cache()
    TC.URL.anchor g, 'file', PATH.resolve __dirname, '..'
    #.......................................................................................................
    urls =
      f_coffee_template:  TC.URL.join g, 'test-data/templates/f.coffee'
      a_json_template:    TC.URL.join g, 'test-data/templates/a.json'
      f_coffee:           TC.URL.join g, 'test-data/f.coffee'
      f_js:               TC.URL.join g, 'test-data/f.js'
      a_json:             TC.URL.join g, 'test-data/a.json'
      cache_f:            TC.URL.join g, 'cache', 'foo'
    #.......................................................................................................
    help yield TC.timestamp_from_url g, urls.f_coffee_template, resume
    help yield TC.timestamp_from_url g, urls.f_coffee, resume
    #.......................................................................................................
    TC.register g, urls.f_coffee, urls.f_js,    [ 'bash',   'coffee -o lib -c src', ]
    TC.register g, urls.f_js,     urls.f_cache, [ 'advice', 'recalculate',          ]
    TC.register g, urls.a_json,   urls.f_cache, [ 'advice', 'recalculate',          ]
    debug '78777', g
    help TC.get_boxed_chart g
    return
    #.......................................................................................................
    FS.write_json urls.a_json,   { x: 42, }
    FS.write      urls.f_coffee, "### some CS here ###"
    FS.write      urls.f_js,     "/* some JS here */"
    warn '################# @1 #############################'
    info f()
    urge 'cache:\n' + rpr FS.cache
    warn yield TC.find_first_fault  g, resume
    #.......................................................................................................
    warn '################# @2 #############################'
    help "boxed chart:\n",          TC.get_boxed_chart g
    help "boxed trend:\n", yield  TC.fetch_boxed_trend g, resume
    FS.write      urls.f_coffee,  "### some modified CS here ###"
    FS.write_json urls.a_json,    { x: 108, }
    help "boxed trend:\n", yield TC.fetch_boxed_trend g, resume
    info f()
    warn yield TC.find_first_fault  g, resume
    urge yield TC.find_faults       g, resume
    urge 'cache:\n' + rpr FS.cache
    #.......................................................................................................
    return null


############################################################################################################
unless module.parent?
  main()


