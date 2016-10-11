
###
adapted from https://www.npmjs.com/package/timestamp
###

_last = 0
_count = 1
LAST = undefined

module.exports = ->
  t = Date.now()
  _t = t
  if _last == t
    _t += _count++ / 1000
  else
    _count = 1
  _last = t
  if _t == LAST
    throw new Error('LAST:' + LAST + ',' + _t)
  LAST = _t
  _t



