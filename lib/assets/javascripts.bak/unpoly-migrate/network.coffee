u = up.util

###**
@module up.network
###

up.migrate.renamedPackage('proxy', 'network')
up.migrate.renamedEvent('up:proxy:load',     'up:request:load')    # renamed in 1.0.0
up.migrate.renamedEvent('up:proxy:received', 'up:request:loaded')  # renamed in 0.50.0
up.migrate.renamedEvent('up:proxy:loaded',   'up:request:loaded')  # renamed in 1.0.0
up.migrate.renamedEvent('up:proxy:fatal',    'up:request:fatal')   # renamed in 1.0.0
up.migrate.renamedEvent('up:proxy:aborted',  'up:request:aborted') # renamed in 1.0.0
up.migrate.renamedEvent('up:proxy:slow',     'up:request:late')    # renamed in 1.0.0
up.migrate.renamedEvent('up:proxy:recover',  'up:request:recover') # renamed in 1.0.0

preloadDelayMoved = -> up.migrate.deprecated('up.proxy.config.preloadDelay', 'up.link.config.preloadDelay')
Object.defineProperty up.network.config, 'preloadDelay',
  get: ->
    preloadDelayMoved()
    return up.link.config.preloadDelay
  set: (value) ->
    preloadDelayMoved()
    up.link.config.preloadDelay = value

up.migrate.renamedProperty(up.network.config, 'maxRequests', 'concurrency')
up.migrate.renamedProperty(up.network.config, 'slowDelay', 'badResponseTime')

up.migrate.handleRequestOptions = (options) ->
  up.migrate.fixKey(options, 'data', 'params')

###**
Makes an AJAX request to the given URL and caches the response.

The function returns a promise that fulfills with the response text.

\#\#\# Example

```
up.ajax('/search', { params: { query: 'sunshine' } }).then(function(text) {
  console.log('The response text is %o', text)
}).catch(function() {
  console.error('The request failed')
})
```

@function up.ajax
@param {string} [url]
  The URL for the request.

  Instead of passing the URL as a string argument, you can also pass it as an `{ url }` option.
@param {Object} [options]
  See options for `up.request()`.
@return {Promise<string>}
  A promise for the response text.
@deprecated
  Use `up.request()` instead.
###
up.ajax = (args...) ->
  up.migrate.deprecated('up.ajax()', 'up.request()')
  pickResponseText = (response) -> return response.text
  up.request(args...).then(pickResponseText)

###**
Removes all cache entries.

@function up.proxy.clear
@deprecated
  Use `up.cache.clear()` instead.
###
up.network.clear = ->
  up.migrate.deprecated('up.proxy.clear()', 'up.cache.clear()')
  return up.cache.clear()

up.network.preload = (args...) ->
  up.migrate.deprecated('up.proxy.preload(link)', 'up.link.preload(link)')
  return up.link.preload(args...)

###**
@class up.Request
###

up.Request.prototype.navigate = ->
  up.migrate.deprecated('up.Request#navigate()', 'up.Request#loadPage()')
  @loadPage()

###**
@class up.Response
###

###**
Returns whether the server responded with a 2xx HTTP status.

@function up.Response#isSuccess
@return {boolean}
@deprecated
  Use `up.Response#ok` instead.
###
up.Response.prototype.isSuccess = ->
  up.migrate.deprecated('up.Response#isSuccess()', 'up.Response#ok')
  return @ok

###**
Returns whether the response was not [successful](/up.Response.prototype.ok).

@function up.Response#isError
@return {boolean}
@deprecated
  Use `!up.Response#ok` instead.
###
up.Response.prototype.isError = ->
  up.migrate.deprecated('up.Response#isError()', '!up.Response#ok')
  return !@ok

mayHaveCustomIndicator = ->
  listeners = up.EventListener.allNonDefault(document)
  u.find listeners, (listener) -> listener.eventType == 'up:request:late'

progressBarDefault = up.network.config.progressBar

disableProgressBarIfCustomIndicator = ->
  up.network.config.progressBar = ->
    if mayHaveCustomIndicator()
      up.migrate.warn('Disabled the default progress bar as may have built a custom loading indicator with your up:request:late listener. Please set up.network.config.progressBar to true or false.')
      false
    else
      progressBarDefault

disableProgressBarIfCustomIndicator()
up.on 'up:framework:reset', disableProgressBarIfCustomIndicator

