// Generated by CoffeeScript 1.11.1
(function() {
  var FS, TC;

  console.log('loaded:', __filename);

  FS = require('fs');

  TC = require('..');

  this._f_from_cache = function() {
    return FS.readFileSync(TC.as_url(g, 'cache', 'f'));
  };

  this._f_recalculate = function() {
    var a_url, a_value, cache_url;
    a_url = TC.as_url(g, 'file', 'a.json');
    cache_url = TC.as_url(g, 'cache', 'f');
    a_value = FS.read_json(a_url);
    return FS.write(cache_url, a_value['x'] + 3);
  };

  this.f = function() {
    var R;
    if ((R = this._f_from_cache()) != null) {
      return R;
    }
    return this._f_recalculate();
  };

}).call(this);
