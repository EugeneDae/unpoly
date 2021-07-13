u = up.util
$ = jQuery

describe 'up.proxy', ->

  describe 'JavaScript functions', ->

    describe 'up.request', ->

      it 'makes a request with the given URL and params', ->
        up.request('/foo', params: { key: 'value' }, method: 'post')
        request = @lastRequest()
        expect(request.url).toMatchUrl('/foo')
        expect(request.data()).toEqual(key: ['value'])
        expect(request.method).toEqual('POST')

      it 'also allows to pass the URL as a { url } option instead', ->
        up.request(url: '/foo', params: { key: 'value' }, method: 'post')
        request = @lastRequest()
        expect(request.url).toMatchUrl('/foo')
        expect(request.data()).toEqual(key: ['value'])
        expect(request.method).toEqual('POST')

      it 'allows to pass in an up.Request instance instead of an options object', ->
        requestArg = new up.Request(url: '/foo', params: { key: 'value' }, method: 'post')
        up.request(requestArg)

        jasmineRequest = @lastRequest()
        expect(jasmineRequest.url).toMatchUrl('/foo')
        expect(jasmineRequest.data()).toEqual(key: ['value'])
        expect(jasmineRequest.method).toEqual('POST')

      it 'submits the replacement targets as HTTP headers, so the server may choose to only frender the requested fragments', asyncSpec (next) ->
        up.request(url: '/foo', target: '.target', failTarget: '.fail-target')

        next =>
          request = @lastRequest()
          expect(request.requestHeaders['X-Up-Target']).toEqual('.target')
          expect(request.requestHeaders['X-Up-Fail-Target']).toEqual('.fail-target')

      it "sends Unpoly's version as an X-Up-Version request header", asyncSpec (next) ->
        up.request(url: '/foo')

        next =>
          versionHeader = @lastRequest().requestHeaders['X-Up-Version']
          expect(versionHeader).toBePresent()
          expect(versionHeader).toEqual(up.version)

      it 'resolves to a Response object that contains information about the response and request', (done) ->
        promise = up.request(
          url: '/url'
          params: { key: 'value' }
          method: 'post'
          target: '.target'
        )

        u.task =>
          @respondWith(
            status: 201,
            responseText: 'response-text'
          )

          promise.then (response) ->
            expect(response.request.url).toMatchUrl('/url')
            expect(response.request.params).toEqual(new up.Params(key: 'value'))
            expect(response.request.method).toEqual('POST')
            expect(response.request.target).toEqual('.target')
            expect(response.request.hash).toBeBlank()

            expect(response.url).toMatchUrl('/url') # If the server signaled a redirect with X-Up-Location, this would be reflected here
            expect(response.method).toEqual('POST') # If the server sent a X-Up-Method header, this would be reflected here
            expect(response.text).toEqual('response-text')
            expect(response.status).toEqual(201)
            expect(response.xhr).toBePresent()

            done()

      it 'resolves to a Response that contains the response headers', (done) ->
        promise = up.request(url: '/url')

        u.task =>
          @respondWith
            responseHeaders: { 'foo': 'bar', 'baz': 'bam' }
            responseText: 'hello'

        promise.then (response) ->
          expect(response.getHeader('foo')).toEqual('bar')

          # Lookup is case-insensitive
          expect(response.getHeader('BAZ')).toEqual('bam')

          done()

      it "preserves the URL hash in a separate { hash } property, since although it isn't sent to server, code might need it to process the response", (done) ->
        promise = up.request('/url#hash')

        u.task =>
          request = @lastRequest()
          expect(request.url).toMatchUrl('/url')

          @respondWith('response-text')

          promise.then (response) ->
            expect(response.request.url).toMatchUrl('/url')
            expect(response.request.hash).toEqual('#hash')
            expect(response.url).toMatchUrl('/url')
            done()

      describe 'when the server responds with an X-Up-Method header', ->

        it 'updates the { method } property in the response object', (done) ->
          promise = up.request(
            url: '/url'
            params: { key: 'value' }
            method: 'post'
            target: '.target'
          )

          u.task =>
            @respondWith(
              responseHeaders:
                'X-Up-Location': '/redirect'
                'X-Up-Method': 'GET'
            )

            promise.then (response) ->
              expect(response.request.url).toMatchUrl('/url')
              expect(response.request.method).toEqual('POST')
              expect(response.url).toMatchUrl('/redirect')
              expect(response.method).toEqual('GET')
              done()

      describe 'when the server responds with an X-Up-Location header', ->

        it 'sets the { url } property on the response object', (done) ->
          promise = up.request('/request-url#request-hash')

          u.task =>
            @respondWith
              responseHeaders:
                'X-Up-Location': '/response-url'

            promise.then (response) ->
              expect(response.request.url).toMatchUrl('/request-url')
              expect(response.request.hash).toEqual('#request-hash')
              expect(response.url).toMatchUrl('/response-url')
              done()

        it 'considers a redirection URL an alias for the requested URL', asyncSpec (next) ->
          up.request('/foo')

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseHeaders:
                'X-Up-Location': '/bar'
                'X-Up-Method': 'GET'

          next =>
            up.request('/bar')

          next =>
            # See that the cached alias is used and no additional requests are made
            expect(jasmine.Ajax.requests.count()).toEqual(1)

        it 'does not considers a redirection URL an alias for the requested URL if the original request was never cached', asyncSpec (next) ->
          up.request('/foo', method: 'post') # POST requests are not cached

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseHeaders:
                'X-Up-Location': '/bar'
                'X-Up-Method': 'GET'

          next =>
            up.request('/bar')

          next =>
            # See that an additional request was made
            expect(jasmine.Ajax.requests.count()).toEqual(2)

        it 'does not considers a redirection URL an alias for the requested URL if the response returned a non-200 status code', asyncSpec (next) ->
          up.request('/foo')

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseHeaders:
                'X-Up-Location': '/bar'
                'X-Up-Method': 'GET'
              status: 500

          next =>
            up.request('/bar')

          next =>
            # See that an additional request was made
            expect(jasmine.Ajax.requests.count()).toEqual(2)

        describeCapability 'canInspectFormData', ->

          it "does not explode if the original request's { params } is a FormData object", asyncSpec (next) ->
            up.request('/foo', method: 'post', params: new FormData()) # POST requests are not cached

            next =>
              expect(jasmine.Ajax.requests.count()).toEqual(1)
              @respondWith
                responseHeaders:
                  'X-Up-Location': '/bar'
                  'X-Up-Method': 'GET'

            next =>
              @secondAjaxPromise = up.request('/bar')

            next.await =>
              promiseState(@secondAjaxPromise).then (result) ->
                # See that the promise was not rejected due to an internal error.
                expect(result.state).toEqual('pending')


      describe 'when the XHR object has a { responseURL } property', ->

        it 'sets the { url } property on the response object', (done) ->
          promise = up.request('/request-url#request-hash')

          u.task =>
            @respondWith
              responseURL: '/response-url'

            promise.then (response) ->
              expect(response.request.url).toMatchUrl('/request-url')
              expect(response.request.hash).toEqual('#request-hash')
              expect(response.url).toMatchUrl('/response-url')
              done()

        it 'considers a redirection URL an alias for the requested URL', asyncSpec (next) ->
          up.request('/foo')

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseURL: '/bar'

          next =>
            up.request('/bar')

          next =>
            # See that the cached alias is used and no additional requests are made
            expect(jasmine.Ajax.requests.count()).toEqual(1)

        it 'does not considers a redirection URL an alias for the requested URL if the original request was never cached', asyncSpec (next) ->
          up.request('/foo', method: 'post') # POST requests are not cached

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseURL: '/bar'

          next =>
            up.request('/bar')

          next =>
            # See that an additional request was made
            expect(jasmine.Ajax.requests.count()).toEqual(2)

        it 'does not considers a redirection URL an alias for the requested URL if the response returned a non-200 status code', asyncSpec (next) ->
          up.request('/foo')

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            @respondWith
              responseURL: '/bar'
              status: 500

          next =>
            up.request('/bar')


      describe 'CSRF', ->

        beforeEach ->
          up.protocol.config.csrfHeader = 'csrf-header'
          up.protocol.config.csrfToken = 'csrf-token'

        it 'sets a CSRF token in the header', asyncSpec (next) ->
          up.request('/path', method: 'post')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['csrf-header']).toEqual('csrf-token')

        it 'does not add a CSRF token if there is none', asyncSpec (next) ->
          up.protocol.config.csrfToken = ''
          up.request('/path', method: 'post')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['csrf-header']).toBeMissing()

        it 'does not add a CSRF token for GET requests', asyncSpec (next) ->
          up.request('/path', method: 'get')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['csrf-header']).toBeMissing()

        it 'does not add a CSRF token when loading content from another domain', asyncSpec (next) ->
          up.request('http://other-domain.tld/path', method: 'post')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['csrf-header']).toBeMissing()

      describe 'X-Requested-With header', ->

        it 'sets the header to "XMLHttpRequest" by default', asyncSpec (next) ->
          up.request('/path', method: 'post')
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['X-Requested-With']).toEqual('XMLHttpRequest')

        it 'does not overrride an existing X-Requested-With header', asyncSpec (next) ->
          up.request('/path', method: 'post', headers: { 'X-Requested-With': 'Love' })
          next =>
            headers = @lastRequest().requestHeaders
            expect(headers['X-Requested-With']).toEqual('Love')

      describe 'with { params } option', ->

        it "uses the given params as a non-GET request's payload", asyncSpec (next) ->
          givenParams = { 'foo-key': 'foo-value', 'bar-key': 'bar-value' }
          up.request(url: '/path', method: 'put', params: givenParams)

          next =>
            expect(@lastRequest().data()['foo-key']).toEqual(['foo-value'])
            expect(@lastRequest().data()['bar-key']).toEqual(['bar-value'])

        it "encodes the given params into the URL of a GET request", (done) ->
          givenParams = { 'foo-key': 'foo-value', 'bar-key': 'bar-value' }
          promise = up.request(url: '/path', method: 'get', params: givenParams)

          u.task =>
            expect(@lastRequest().url).toMatchUrl('/path?foo-key=foo-value&bar-key=bar-value')
            expect(@lastRequest().data()).toBeBlank()

            @respondWith('response-text')

            promise.then (response) ->
              # See that the response object has been updated by moving the data options
              # to the URL. This is important for up.fragment code that works on response.request.
              expect(response.request.url).toMatchUrl('/path?foo-key=foo-value&bar-key=bar-value')
              expect(response.request.params).toBeBlank()
              done()

      it 'caches server responses for the configured duration', asyncSpec (next) ->
        up.proxy.config.cacheExpiry = 200 # 1 second for test

        responses = []
        trackResponse = (response) -> responses.push(response.text)

        next =>
          up.request(url: '/foo').then(trackResponse)
          expect(jasmine.Ajax.requests.count()).toEqual(1)

        next.after (10), =>
          # Send the same request for the same path
          up.request(url: '/foo').then(trackResponse)

          # See that only a single network request was triggered
          expect(jasmine.Ajax.requests.count()).toEqual(1)
          expect(responses).toEqual([])

        next =>
          # Server responds once.
          @respondWith('foo')

        next =>
          # See that both requests have been fulfilled
          expect(responses).toEqual(['foo', 'foo'])

        next.after (200), =>
          # Send another request after another 3 minutes
          # The clock is now a total of 6 minutes after the first request,
          # exceeding the cache's retention time of 5 minutes.
          up.request(url: '/foo').then(trackResponse)

          # See that we have triggered a second request
          expect(jasmine.Ajax.requests.count()).toEqual(2)

        next =>
          @respondWith('bar')

        next =>
          expect(responses).toEqual(['foo', 'foo', 'bar'])

      it "does not cache responses if config.cacheExpiry is 0", asyncSpec (next) ->
        up.proxy.config.cacheExpiry = 0
        next => up.request(url: '/foo')
        next => up.request(url: '/foo')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "does not cache responses if config.cacheSize is 0", asyncSpec (next) ->
        up.proxy.config.cacheSize = 0
        next => up.request(url: '/foo')
        next => up.request(url: '/foo')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it 'does not limit the number of cache entries if config.cacheSize is undefined'

      it 'never discards old cache entries if config.cacheExpiry is undefined'

      it 'respects a config.cacheSize setting', asyncSpec (next) ->
        up.proxy.config.cacheSize = 2
        next => up.request(url: '/foo')
        next => up.request(url: '/bar')
        next => up.request(url: '/baz')
        next => up.request(url: '/foo')
        next => expect(jasmine.Ajax.requests.count()).toEqual(4)

      it "doesn't reuse responses when asked for the same path, but different selectors", asyncSpec (next) ->
        next => up.request(url: '/path', target: '.a')
        next => up.request(url: '/path', target: '.b')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "doesn't reuse responses when asked for the same path, but different params", asyncSpec (next) ->
        next => up.request(url: '/path', params: { query: 'foo' })
        next => up.request(url: '/path', params: { query: 'bar' })
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "reuses a response for an 'html' selector when asked for the same path and any other selector", asyncSpec (next) ->
        next => up.request(url: '/path', target: 'html')
        next => up.request(url: '/path', target: 'body')
        next => up.request(url: '/path', target: 'p')
        next => up.request(url: '/path', target: '.klass')
        next => expect(jasmine.Ajax.requests.count()).toEqual(1)

      it "reuses a response for a 'body' selector when asked for the same path and any other selector other than 'html'", asyncSpec (next) ->
        next => up.request(url: '/path', target: 'body')
        next => up.request(url: '/path', target: 'p')
        next => up.request(url: '/path', target: '.klass')
        next => expect(jasmine.Ajax.requests.count()).toEqual(1)

      it "doesn't reuse a response for a 'body' selector when asked for the same path but an 'html' selector", asyncSpec (next) ->
        next => up.request(url: '/path', target: 'body')
        next => up.request(url: '/path', target: 'html')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it "doesn't reuse responses for different paths", asyncSpec (next) ->
        next => up.request(url: '/foo')
        next => up.request(url: '/bar')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      u.each ['GET', 'HEAD', 'OPTIONS'], (method) ->

        it "caches #{method} requests", asyncSpec (next) ->
          next => up.request(url: '/foo', method: method)
          next => up.request(url: '/foo', method: method)
          next => expect(jasmine.Ajax.requests.count()).toEqual(1)

        it "does not cache #{method} requests with { cache: false }", asyncSpec (next) ->
          next => up.request(url: '/foo', method: method, cache: false)
          next => up.request(url: '/foo', method: method, cache: false)
          next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      u.each ['POST', 'PUT', 'DELETE'], (method) ->

        it "does not cache #{method} requests", asyncSpec (next) ->
          next => up.request(url: '/foo', method: method)
          next => up.request(url: '/foo', method: method)
          next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      it 'does not cache responses with a non-200 status code', asyncSpec (next) ->
        next => up.request(url: '/foo')
        next => @respondWith(status: 500, contentType: 'text/html', responseText: 'foo')
        next => up.request(url: '/foo')
        next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      describe 'with config.wrapMethods set', ->

        it 'should be set by default', ->
          expect(up.proxy.config.wrapMethods).toBePresent()

        u.each ['GET', 'POST', 'HEAD', 'OPTIONS'], (method) ->

          it "does not change the method of a #{method} request", asyncSpec (next) ->
            up.request(url: '/foo', method: method)

            next =>
              request = @lastRequest()
              expect(request.method).toEqual(method)
              expect(request.data()['_method']).toBeUndefined()

        u.each ['PUT', 'PATCH', 'DELETE'], (method) ->

          it "turns a #{method} request into a POST request and sends the actual method as a { _method } param to prevent unexpected redirect behavior (https://makandracards.com/makandra/38347)", asyncSpec (next) ->
            up.request(url: '/foo', method: method)

            next =>
              request = @lastRequest()
              expect(request.method).toEqual('POST')
              expect(request.data()['_method']).toEqual([method])
#              expect(request.data()['foo']).toEqual('bar')

      describe 'with config.maxRequests set', ->

        beforeEach ->
          @oldMaxRequests = up.proxy.config.maxRequests
          up.proxy.config.maxRequests = 1

        afterEach ->
          up.proxy.config.maxRequests = @oldMaxRequests

        it 'limits the number of concurrent requests', asyncSpec (next) ->
          responses = []
          trackResponse = (response) -> responses.push(response.text)

          next =>
            up.request(url: '/foo').then(trackResponse)
            up.request(url: '/bar').then(trackResponse)

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1) # only one request was made

          next =>
            @respondWith('first response', request: jasmine.Ajax.requests.at(0))

          next =>
            expect(responses).toEqual ['first response']
            expect(jasmine.Ajax.requests.count()).toEqual(2) # a second request was made

          next =>
            @respondWith('second response', request: jasmine.Ajax.requests.at(1))

          next =>
            expect(responses).toEqual ['first response', 'second response']

        it 'ignores preloading for the request limit', asyncSpec (next) ->
          next => up.request(url: '/foo', preload: true)
          next => up.request(url: '/bar')
          next => expect(jasmine.Ajax.requests.count()).toEqual(2)
          next => up.request(url: '/bar')
          next => expect(jasmine.Ajax.requests.count()).toEqual(2)

      describe 'up:proxy:load event', ->

        it 'emits an up:proxy:load event before the request touches the network', asyncSpec (next) ->
          listener = jasmine.createSpy('listener')
          up.on 'up:proxy:load', listener
          up.request('/bar')

          next =>
            expect(jasmine.Ajax.requests.count()).toEqual(1)

            partialRequest = jasmine.objectContaining(
              method: 'GET',
              url: jasmine.stringMatching('/bar')
            )
            partialEvent = jasmine.objectContaining(request: partialRequest)

            expect(listener).toHaveBeenCalledWith(partialEvent, jasmine.anything(), jasmine.anything())

        it 'allows up:proxy:load listeners to prevent the request (useful to cancel all requests when stopping a test scenario)', (done) ->
          listener = jasmine.createSpy('listener').and.callFake (event) ->
            expect(jasmine.Ajax.requests.count()).toEqual(0)
            event.preventDefault()

          up.on 'up:proxy:load', listener

          promise = up.request('/bar')

          u.task ->
            expect(listener).toHaveBeenCalled()
            expect(jasmine.Ajax.requests.count()).toEqual(0)

            promiseState(promise).then (result) ->
              expect(result.state).toEqual('rejected')
              expect(result.value).toBeError(/prevented/i)
              done()

        it 'does not block the queue when a request was prevented', (done) ->
          up.proxy.config.maxRequests = 1

          listener = jasmine.createSpy('listener').and.callFake (event) ->
            # only prevent the first request
            if event.request.url.indexOf('/path1') >= 0
              event.preventDefault()

          up.on 'up:proxy:load', listener

          promise1 = up.request('/path1')
          promise2 = up.request('/path2')

          u.task =>
            expect(listener.calls.count()).toBe(2)
            expect(jasmine.Ajax.requests.count()).toEqual(1)
            expect(@lastRequest().url).toMatchUrl('/path2')
            done()

        it 'allows up:proxy:load listeners to manipulate the request headers', (done) ->
          listener = (event) ->
            event.request.headers['X-From-Listener'] = 'foo'

          up.on 'up:proxy:load', listener

          up.request('/path1')

          u.task =>
            expect(@lastRequest().requestHeaders['X-From-Listener']).toEqual('foo')
            done()

      describe 'up:proxy:slow and up:proxy:recover events', ->

        beforeEach ->
          up.proxy.config.slowDelay = 0
          @events = []
          u.each ['up:proxy:load', 'up:proxy:loaded', 'up:proxy:slow', 'up:proxy:recover', 'up:proxy:fatal'], (eventName) =>
            up.on eventName, =>
              @events.push eventName

        it 'emits an up:proxy:slow event if the server takes too long to respond'

        it 'does not emit an up:proxy:slow event if preloading', asyncSpec (next) ->
          next =>
            # A request for preloading preloading purposes
            # doesn't make us busy.
            up.request(url: '/foo', preload: true)

          next =>
            expect(@events).toEqual([
              'up:proxy:load'
            ])
            expect(up.proxy.isBusy()).toBe(false)

          next =>
            # The same request with preloading does trigger up:proxy:slow.
            up.request(url: '/foo')

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow'
            ])
            expect(up.proxy.isBusy()).toBe(true)

          next =>
            # The response resolves both promises and makes
            # the proxy idle again.
            jasmine.Ajax.requests.at(0).respondWith
              status: 200
              contentType: 'text/html'
              responseText: 'foo'

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow',
              'up:proxy:loaded',
              'up:proxy:recover'
            ])
            expect(up.proxy.isBusy()).toBe(false)

        it 'can delay the up:proxy:slow event to prevent flickering of spinners', asyncSpec (next) ->
          next =>
            up.proxy.config.slowDelay = 100
            up.request(url: '/foo')

          next =>
            expect(@events).toEqual([
              'up:proxy:load'
            ])

          next.after 50, =>
            expect(@events).toEqual([
              'up:proxy:load'
            ])

          next.after 60, =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow'
            ])

          next =>
            jasmine.Ajax.requests.at(0).respondWith
              status: 200
              contentType: 'text/html'
              responseText: 'foo'

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow',
              'up:proxy:loaded',
              'up:proxy:recover'
            ])

        it 'does not emit up:proxy:recover if a delayed up:proxy:slow was never emitted due to a fast response', asyncSpec (next) ->
          next =>
            up.proxy.config.slowDelay = 200
            up.request(url: '/foo')

          next =>
            expect(@events).toEqual([
              'up:proxy:load'
            ])

          next.after 100, =>
            jasmine.Ajax.requests.at(0).respondWith
              status: 200
              contentType: 'text/html'
              responseText: 'foo'

          next.after 250, =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:loaded'
            ])

        it 'emits up:proxy:recover if a request returned but failed with an error code', asyncSpec (next) ->
          next =>
            up.request(url: '/foo')

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow'
            ])

          next =>
            jasmine.Ajax.requests.at(0).respondWith
              status: 500
              contentType: 'text/html'
              responseText: 'something went wrong'

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow',
              'up:proxy:loaded',
              'up:proxy:recover'
            ])


        it 'emits up:proxy:recover if a request returned but failed fatally', asyncSpec (next) ->
          up.proxy.config.slowDelay = 10

          next =>
            up.request(url: '/foo', timeout: 75)

          next.after 50, =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow'
            ])

          next =>
            jasmine.clock().install() # required by responseTimeout()
            @lastRequest().responseTimeout()

          next =>
            expect(@events).toEqual([
              'up:proxy:load',
              'up:proxy:slow',
              'up:proxy:fatal',
              'up:proxy:recover'
            ])


    describe 'up.ajax', ->

      it 'fulfills to the response text in order to match the $.ajax() API as good as possible', (done) ->
        promise = up.ajax('/url')

        u.timer 100, =>
          @respondWith('response-text')

          promise.then (text) ->
            expect(text).toEqual('response-text')

            done()

    describe 'up.proxy.preload', ->

      describeCapability 'canPushState', ->

        beforeEach ->
          @requestTarget = => @lastRequest().requestHeaders['X-Up-Target']

        it "loads and caches the given link's destination", asyncSpec (next) ->
          $fixture('.target')
          $link = $fixture('a[href="/path"][up-target=".target"]')

          up.proxy.preload($link)

          next =>
            cachedPromise = up.proxy.get(url: '/path', target: '.target')
            expect(u.isPromise(cachedPromise)).toBe(true)

        it "does not load a link whose method has side-effects", (done) ->
          $fixture('.target')
          $link = $fixture('a[href="/path"][up-target=".target"][data-method="post"]')
          preloadPromise = up.proxy.preload($link)

          promiseState(preloadPromise).then (result) ->
            expect(result.state).toEqual('rejected')
            expect(up.proxy.get(url: '/path', target: '.target')).toBeUndefined()
            done()

        it 'accepts options', asyncSpec (next) ->
          $fixture('.target')
          $link = $fixture('a[href="/path"][up-target=".target"]')
          up.proxy.preload($link, url: '/options-path')

          next =>
            cachedPromise = up.proxy.get(url: '/options-path', target: '.target')
            expect(u.isPromise(cachedPromise)).toBe(true)

        describe 'for an [up-target] link', ->

          it 'includes the [up-target] selector as an X-Up-Target header if the targeted element is currently on the page', asyncSpec (next) ->
            $fixture('.target')
            $link = $fixture('a[href="/path"][up-target=".target"]')
            up.proxy.preload($link)
            next => expect(@requestTarget()).toEqual('.target')

          it 'replaces the [up-target] selector as with a fallback and uses that as an X-Up-Target header if the targeted element is not currently on the page', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-target=".target"]')
            up.proxy.preload($link)
            # The default fallback would usually be `body`, but in Jasmine specs we change
            # it to protect the test runner during failures.
            next => expect(@requestTarget()).toEqual('.default-fallback')

          it 'calls up.request() with a { preload: true } option so it bypasses the concurrency limit', asyncSpec (next) ->
            requestSpy = spyOn(up, 'request')

            $link = $fixture('a[href="/path"][up-target=".target"]')
            up.proxy.preload($link)

            next =>
              expect(requestSpy).toHaveBeenCalledWith(jasmine.objectContaining(preload: true))

        describe 'for an [up-modal] link', ->

          beforeEach ->
            up.motion.config.enabled = false

          it 'includes the [up-modal] selector as an X-Up-Target header and does not replace it with a fallback, since the modal frame always exists', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-modal=".target"]')
            up.proxy.preload($link)
            next => expect(@requestTarget()).toEqual('.target')

          it 'does not create a modal frame', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-modal=".target"]')
            up.proxy.preload($link)
            next =>
              expect('.up-modal').not.toBeAttached()

          it 'does not emit an up:modal:open event', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-modal=".target"]')
            openListener = jasmine.createSpy('listener')
            up.on('up:modal:open', openListener)
            up.proxy.preload($link)
            next =>
              expect(openListener).not.toHaveBeenCalled()

          it 'does not close a currently open modal', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-modal=".target"]')
            closeListener = jasmine.createSpy('listener')
            up.on('up:modal:close', closeListener)

            up.modal.extract('.content', '<div class="content">Modal content</div>')

            next =>
              expect('.up-modal .content').toBeAttached()

            next =>
              up.proxy.preload($link)

            next =>
              expect('.up-modal .content').toBeAttached()
              expect(closeListener).not.toHaveBeenCalled()

            next =>
              up.modal.close()

            next =>
              expect('.up-modal .content').not.toBeAttached()
              expect(closeListener).toHaveBeenCalled()

          it 'does not prevent the opening of other modals while the request is still pending', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-modal=".target"]')
            up.proxy.preload($link)

            next =>
              up.modal.extract('.content', '<div class="content">Modal content</div>')

            next =>
              expect('.up-modal .content').toBeAttached()

          it 'calls up.request() with a { preload: true } option so it bypasses the concurrency limit', asyncSpec (next) ->
            requestSpy = spyOn(up, 'request')

            $link = $fixture('a[href="/path"][up-modal=".target"]')
            up.proxy.preload($link)

            next =>
              expect(requestSpy).toHaveBeenCalledWith(jasmine.objectContaining(preload: true))

        describe 'for an [up-popup] link', ->

          beforeEach ->
            up.motion.config.enabled = false
          
          it 'includes the [up-popup] selector as an X-Up-Target header and does not replace it with a fallback, since the popup frame always exists', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-popup=".target"]')
            up.proxy.preload($link)
            next => expect(@requestTarget()).toEqual('.target')


          it 'does not create a popup frame', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-popup=".target"]')
            up.proxy.preload($link)
            next =>
              expect('.up-popup').not.toBeAttached()

          it 'does not emit an up:popup:open event', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-popup=".target"]')
            openListener = jasmine.createSpy('listener')
            up.on('up:popup:open', openListener)
            up.proxy.preload($link)
            next =>
              expect(openListener).not.toHaveBeenCalled()

          it 'does not close a currently open popup', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-popup=".target"]')
            closeListener = jasmine.createSpy('listener')
            up.on('up:popup:close', closeListener)

            $existingAnchor = $fixture('.existing-anchor')
            up.popup.attach($existingAnchor, target: '.content', html: '<div class="content">popup content</div>')

            next =>
              expect('.up-popup .content').toBeAttached()

            next =>
              up.proxy.preload($link)

            next =>
              expect('.up-popup .content').toBeAttached()
              expect(closeListener).not.toHaveBeenCalled()

            next =>
              up.popup.close()

            next =>
              expect('.up-popup .content').not.toBeAttached()
              expect(closeListener).toHaveBeenCalled()

          it 'does not prevent the opening of other popups while the request is still pending', asyncSpec (next) ->
            $link = $fixture('a[href="/path"][up-popup=".target"]')
            up.proxy.preload($link)

            next =>
              $anchor = $fixture('.existing-anchor')
              up.popup.attach($anchor, target: '.content', html: '<div class="content">popup content</div>')

            next =>
              expect('.up-popup .content').toBeAttached()

          it 'calls up.request() with a { preload: true } option so it bypasses the concurrency limit', asyncSpec (next) ->
            requestSpy = spyOn(up, 'request')

            $link = $fixture('a[href="/path"][up-popup=".target"]')
            up.proxy.preload($link)

            next =>
              expect(requestSpy).toHaveBeenCalledWith(jasmine.objectContaining(preload: true))

      describeFallback 'canPushState', ->

        it "does nothing", asyncSpec (next) ->
          $fixture('.target')
          $link = $fixture('a[href="/path"][up-target=".target"]')
          up.proxy.preload($link)
          next =>
            expect(jasmine.Ajax.requests.count()).toBe(0)

    describe 'up.proxy.get', ->

      it 'returns an existing cache entry for the given request', ->
        promise1 = up.request(url: '/foo', params: { key: 'value' })
        promise2 = up.proxy.get(url: '/foo', params: { key: 'value' })
        expect(promise1).toBe(promise2)

      it 'returns undefined if the given request is not cached', ->
        promise = up.proxy.get(url: '/foo', params: { key: 'value' })
        expect(promise).toBeUndefined()

      describeCapability 'canInspectFormData', ->

        it "returns undefined if the given request's { params } is a FormData object", ->
          promise = up.proxy.get(url: '/foo', params: new FormData())
          expect(promise).toBeUndefined()

    describe 'up.proxy.set', ->

      it 'should have tests'

    describe 'up.proxy.alias', ->

      it 'uses an existing cache entry for another request (used in case of redirects)'

    describe 'up.proxy.remove', ->

      it 'removes the cache entry for the given request'

      it 'does nothing if the given request is not cached'

      describeCapability 'canInspectFormData', ->

        it 'does not crash when passed a request with FormData (bugfix)', ->
          removal = -> up.proxy.remove(url: '/path', params: new FormData())
          expect(removal).not.toThrowError()

    describe 'up.proxy.clear', ->

      it 'removes all cache entries'

  describe 'unobtrusive behavior', ->

    describe '[up-preload]', ->

      it 'preloads the link destination when hovering, after a delay', asyncSpec (next) ->
        up.proxy.config.preloadDelay = 100

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.hoverSequence($link)

        next.after 50, =>
          # It's still too early
          expect(jasmine.Ajax.requests.count()).toEqual(0)

        next.after 75, =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)
          expect(@lastRequest().url).toMatchUrl('/foo')
          expect(@lastRequest()).toHaveRequestMethod('GET')
          expect(@lastRequest().requestHeaders['X-Up-Target']).toEqual('.target')

          @respondWith """
            <div class="target">
              new text
            </div>
            """

        next =>
          # We only preloaded, so the target isn't replaced yet.
          expect('.target').toHaveText('old text')

          Trigger.clickSequence($link)

        next =>
          # No additional request has been sent since we already preloaded
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          # The target is replaced instantly
          expect('.target').toHaveText('new text')

      it 'does not send a request if the user stops hovering before the delay is over', asyncSpec (next) ->
        up.proxy.config.preloadDelay = 100

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.hoverSequence($link)

        next.after 40, =>
          # It's still too early
          expect(jasmine.Ajax.requests.count()).toEqual(0)

          Trigger.unhoverSequence($link)

        next.after 90, =>
          expect(jasmine.Ajax.requests.count()).toEqual(0)

      it 'does not cache a failed response', asyncSpec (next) ->
        up.proxy.config.preloadDelay = 0

        $fixture('.target').text('old text')

        $link = $fixture('a[href="/foo"][up-target=".target"][up-preload]')
        up.hello($link)

        Trigger.hoverSequence($link)

        next.after 50, =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)

          @respondWith
            status: 500
            responseText: """
              <div class="target">
                new text
              </div>
              """

        next =>
          # We only preloaded, so the target isn't replaced yet.
          expect('.target').toHaveText('old text')

          Trigger.click($link)

        next =>
          # Since the preloading failed, we send another request
          expect(jasmine.Ajax.requests.count()).toEqual(2)

          # Since there isn't anyone who could handle the rejection inside
          # the event handler, our handler mutes the rejection.
          expect(window).not.toHaveUnhandledRejections() if REJECTION_EVENTS_SUPPORTED

      it 'triggers a separate AJAX request when hovered multiple times and the cache expires between hovers', asyncSpec (next)  ->
        up.proxy.config.cacheExpiry = 100
        up.proxy.config.preloadDelay = 0

        $element = $fixture('a[href="/foo"][up-preload]')
        up.hello($element)

        Trigger.hoverSequence($element)

        next.after 10, =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)

        next.after 10, =>
          Trigger.hoverSequence($element)

        next.after 10, =>
          expect(jasmine.Ajax.requests.count()).toEqual(1)

        next.after 150, =>
          Trigger.hoverSequence($element)

        next.after 30, =>
          expect(jasmine.Ajax.requests.count()).toEqual(2)
