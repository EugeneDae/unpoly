/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
/***
@module up.util
*/

/***
Returns a copy of the given object that only contains
the given keys.

@function up.util.only
@param {Object} object
@param {Array} ...keys
@deprecated
  Use `up.util.pick()` instead.
*/
up.util.only = function(object, ...keys) {
  up.migrate.deprecated('up.util.only(object, ...keys)', 'up.util.pick(object, keys)');
  return up.util.pick(object, keys);
};

/***
Returns a copy of the given object that contains all except
the given keys.

@function up.util.except
@param {Object} object
@param {Array} ...keys
@deprecated
  Use `up.util.omit(object, keys)` (with an array argument) instead of `up.util.object(...keys)` (with rest arguments).
*/
up.util.except = function(object, ...keys) {
  up.migrate.deprecated('up.util.except(object, ...keys)', 'up.util.omit(object, keys)');
  return up.util.omit(object, keys);
};

up.util.parseUrl = function(...args) {
  up.migrate.warn('up.util.parseUrl() has been renamed to up.util.parseURL()');
  return up.util.parseURL(...Array.from(args || []));
};

up.util.any = function(...args) {
  up.migrate.warn('up.util.any() has been renamed to up.util.some()');
  return some(...Array.from(args || []));
};

up.util.all = function(...args) {
  up.migrate.warn('up.util.all() has been renamed to up.util.every()');
  return up.util.every(...Array.from(args || []));
};

up.util.detect = function(...args) {
  up.migrate.warn('up.util.detect() has been renamed to up.util.find()');
  return up.util.find(...Array.from(args || []));
};

up.util.select = function(...args) {
  up.migrate.warn('up.util.select() has been renamed to up.util.filter()');
  return up.util.filter(...Array.from(args || []));
};

up.util.setTimer = function(...args) {
  up.migrate.warn('up.util.setTimer() has been renamed to up.util.timer()');
  return up.util.timer(...Array.from(args || []));
};

up.util.escapeHtml = function(...args) {
  up.migrate.deprecated('up.util.escapeHtml', 'up.util.escapeHTML');
  return up.util.escapeHTML(...Array.from(args || []));
};

up.util.selectorForElement = function(...args) {
  up.migrate.warn('up.util.selectorForElement() has been renamed to up.fragment.toTarget()');
  return up.fragment.toTarget(...Array.from(args || []));
};

up.util.nextFrame = function(...args) {
  up.migrate.warn('up.util.nextFrame() has been renamed to up.util.task()');
  return up.util.task(...Array.from(args || []));
};
