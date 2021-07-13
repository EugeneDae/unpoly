#= require ./record

u = up.util
e = up.element

###**
Instances of `up.Request` normalizes properties of an [`AJAX request`](/up.request)
such as the requested URL, form parameters and HTTP method.

@class up.Request
###
class up.Request extends up.Record

  ###**
  The HTTP method for the request.

  @property up.Request#method
  @param {string} method
  @stable
  ###

  ###**
  The URL for the request.

  @property up.Request#url
  @param {string} url
  @stable
  ###

  ###**
  [Parameters](/up.Params) that should be sent as the request's payload.

  @property up.Request#params
  @param {Object|FormData|string|Array} params
  @stable
  ###

  ###**
  The CSS selector that will be sent as an [`X-Up-Target` header](/up.protocol#optimizing-responses).

  @property up.Request#target
  @param {string} target
  @stable
  ###

  ###**
  The CSS selector that will be sent as an [`X-Up-Fail-Target` header](/up.protocol#optimizing-responses).

  @property up.Request#failTarget
  @param {string} failTarget
  @stable
  ###

  ###**
  An object of additional HTTP headers.

  @property up.Request#headers
  @param {Object} headers
  @stable
  ###

  ###**
  A timeout in milliseconds.

  If [`up.proxy.config.maxRequests`](/up.proxy.config#config.maxRequests) is set,
  the timeout will not include the time spent waiting in the queue.

  @property up.Request#timeout
  @param {Object|undefined} timeout
  @stable
  ###
  fields: ->
    [
      'method',
      'url',
      'params',
      'target',
      'failTarget',
      'headers',
      'timeout',
      'preload' # since up.proxy.request() options are sometimes wrapped in this class
      'cache'   # since up.proxy.request() options are sometimes wrapped in this class
    ]

  ###**
  Creates a new `up.Request` object.

  This will not actually send the request over the network. For that use `up.request()`.

  @constructor up.Request
  @param {string} attrs.url
  @param {string} [attrs.method='get']
  @param {up.Params|string|Object|Array} [attrs.params]
  @param {string} [attrs.target]
  @param {string} [attrs.failTarget]
  @param {Object<string, string>} [attrs.headers]
  @param {number} [attrs.timeout]
  @internal
  ###
  constructor: (options) ->
    up.legacy.fixKey(options, 'data', 'params')
    super(options)
    @normalize()

  normalize: =>
    @params = new up.Params(@params) # copies, which we want
    @method = u.normalizeMethod(@method)
    @headers ||= {}
    @extractHashFromUrl()

    unless u.methodAllowsPayload(@method)
      @transferParamsToUrl()

  extractHashFromUrl: =>
    urlParts = u.parseUrl(@url)
    # Remember the #hash for later revealing.
    # It will be lost during normalization.
    @hash = u.presence(urlParts.hash)
    @url = u.normalizeUrl(urlParts, hash: false)

  transferParamsToUrl: =>
    unless u.isBlank(@params)
      # GET methods are not allowed to have a payload, so we transfer { params } params to the URL.
      @url = @params.toURL(@url)
      # Now that we have transfered the params into the URL, we delete them from the { params } option.
      @params.clear()

  transferSearchToParams: =>
    paramsFromQuery = up.Params.fromURL(@url)
    unless u.isBlank(paramsFromQuery)
      @params.addAll(paramsFromQuery)
      @url = u.normalizeUrl(@url, search: false)

  isSafe: =>
    up.proxy.isSafeMethod(@method)

  send: =>
    # We will modify this request below.
    # This would confuse API clients and cache key logic in up.proxy.
    new Promise (resolve, reject) =>
      xhr = new XMLHttpRequest()

      xhrHeaders = u.copy(@headers)
      xhrUrl = @url
      xhrParams = u.copy(@params)
      xhrMethod = up.proxy.wrapMethod(@method, xhrParams)

      xhrPayload = null
      unless u.isBlank(xhrParams)
        delete xhrHeaders['Content-Type'] # let the browser set the content type
        xhrPayload = xhrParams.toFormData()

      pc = up.protocol.config
      xhrHeaders[pc.versionHeader] = up.version
      xhrHeaders[pc.targetHeader] = @target if @target
      xhrHeaders[pc.failTargetHeader] = @failTarget if @failTarget
      xhrHeaders['X-Requested-With'] ||= 'XMLHttpRequest' unless @isCrossDomain()
      if csrfToken = @csrfToken()
        xhrHeaders[pc.csrfHeader] = csrfToken

      xhr.open(xhrMethod, xhrUrl)

      for header, value of xhrHeaders
        xhr.setRequestHeader(header, value)

      resolveWithResponse = =>
        response = @buildResponse(xhr)
        if response.isSuccess()
          resolve(response)
        else
          reject(response)

      # Convert from XHR API to promise API
      xhr.onload = resolveWithResponse
      xhr.onerror = resolveWithResponse
      xhr.ontimeout = resolveWithResponse

      xhr.timeout = @timeout if @timeout

      xhr.send(xhrPayload)

  navigate: =>
    # GET forms cannot have an URL with a query section in their [action] attribute.
    # The query section would be overridden by the serialized input values on submission.
    @transferSearchToParams()

    form = e.affix(document.body, 'form.up-page-loader')

    addField = (attrs) ->
      e.affix(form, 'input[type=hidden]', attrs)

    if @method == 'GET'
      formMethod = 'GET'
    else
      # Browser forms can only have GET or POST methods.
      # When we want to make a request with another method, most backend
      # frameworks allow to pass the method as a param.
      addField(name: up.protocol.config.methodParam, value: @method)
      formMethod = 'POST'

    e.setAttrs(form, method: formMethod, action: @url)

    if (csrfParam = up.protocol.csrfParam()) && (csrfToken = @csrfToken())
      addField(name: csrfParam, value: csrfToken)

    # @params will be undefined for GET requests, since we have already
    # transfered all params to the URL during normalize().
    u.each(@params.toArray(), addField)

    e.hide(form)

    up.browser.submitForm(form)

  # Returns a csrfToken if this request requires it
  csrfToken: =>
    if !@isSafe() && !@isCrossDomain()
      up.protocol.csrfToken()

  isCrossDomain: =>
    u.isCrossDomain(@url)

  buildResponse: (xhr) =>
    responseAttrs =
      method: @method
      url: @url
      text: xhr.responseText
      status: xhr.status
      request: @
      xhr: xhr

    if urlFromServer = up.protocol.locationFromXhr(xhr)
      responseAttrs.url = urlFromServer
      # If the server changes a URL, it is expected to signal a new method as well.
      responseAttrs.method = up.protocol.methodFromXhr(xhr) ? 'GET'

    responseAttrs.title = up.protocol.titleFromXhr(xhr)

    new up.Response(responseAttrs)

  isCachable: =>
    @isSafe() && !u.isFormData(@params)

  cacheKey: =>
    [@url, @method, @params.toQuery(), @target].join('|')

  @wrap: (value) ->
    u.wrapValue(value, @)
