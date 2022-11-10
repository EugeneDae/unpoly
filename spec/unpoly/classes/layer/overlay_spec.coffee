u = up.util

describe 'up.Layer.Overlay', ->

  beforeEach ->
    up.motion.config.enabled = false

  describe '#accept()', ->

    it 'closes this layer', ->
      modes = -> u.map(up.layer.stack, 'mode')

      makeLayers(2)
      expect(modes()).toEqual ['root', 'modal']

      up.layer.accept(null, animation: false)

      expect(modes()).toEqual ['root']

    it 'dismiss descendants before closing this layer', ->
      listener = jasmine.createSpy('layer close listener')
      up.on 'up:layer:accepted up:layer:dismissed', listener

      makeLayers(4)

      @layers = u.copy(up.layer.stack)
      up.layer.get(1).accept()

      expect(listener.calls.count()).toBe(3)
      expect(listener.calls.argsFor(0)[0]).toBeEvent('up:layer:dismissed', layer: @layers[3])
      expect(listener.calls.argsFor(1)[0]).toBeEvent('up:layer:dismissed', layer: @layers[2])
      expect(listener.calls.argsFor(2)[0]).toBeEvent('up:layer:accepted', layer: @layers[1])

    it 'aborts pending requests for this layer', asyncSpec (next) ->
      abortedURLs = []
      up.on 'up:request:aborted', (event) -> abortedURLs.push(event.request.url)

      makeLayers(2)

      up.render('.element', url: '/layer-url', layer: 'current')

      next ->
        up.layer.accept()

      next ->
        expect(abortedURLs.length).toBe(1)
        expect(abortedURLs[0]).toMatchURL('/layer-url')

    it 'does not abort a pending request for another layer', asyncSpec (next) ->
      abortedURLs = []
      up.on 'up:request:aborted', (event) -> abortedURLs.push(event.request.url)

      makeLayers(2)

      up.render('.element', url: '/root-url', layer: 'root', peel: false)

      next ->
        up.layer.current.accept()

      next ->
        expect(abortedURLs).toBeBlank()

    it 'takes an acceptance value that is passed to onAccepted handlers', asyncSpec (next) ->
      callback = jasmine.createSpy('onAccepted handler')

      makeLayers [
        { }
        { onAccepted: callback }
      ]
      expect(callback).not.toHaveBeenCalled()

      up.layer.current.accept('acceptance value')

      expect(callback).toHaveBeenCalledWith(jasmine.objectContaining(value: 'acceptance value'))

    it 'focuses the link that originally opened the overlay', asyncSpec (next) ->
      opener = fixture('a[up-target=".element"][up-layer="new"][href="/overlay-path"]')

      Trigger.clickSequence(opener)

      next =>
        @respondWithSelector('.element', text: 'text')

      next ->
        expect(up.layer.count).toBe(2)
        expect(opener).not.toBeFocused()

        up.layer.current.accept()

      next ->
        expect(opener).toBeFocused()

    it 'pops this layer from the stack synchronously to prevent race conditions', ->
      makeLayers(2)

      expect(up.layer.count).toBe(2)
      up.layer.current.accept()
      expect(up.layer.count).toBe(1)

    it "restores the parent layer's location", ->
      up.history.config.enabled = true

      up.layer.open(
        target: '.element',
        location: '/path/to/modal'
        content: 'element text'
        history: true
      )

      expect(up.layer.isOverlay()).toBe(true)
      expect(location.href).toMatchURL('/path/to/modal')

      up.layer.current.accept()

      expect(up.layer.isRoot()).toBe(true)
      expect(location.href).toMatchURL(@locationBeforeExample)

    it "does not restore the parent layer's location if the parent layer does not render history", ->
      up.history.config.enabled = true

      makeLayers [
        { },
        { history: false, location: '/overlay1' },
        { history: true, location: '/overlay2' }
      ]

      expect(up.layer.current.index).toBe(2)
      expect(location.href).toMatchURL(@locationBeforeExample)

      up.layer.current.accept()

      expect(up.layer.current.index).toBe(1)
      expect(location.href).toMatchURL(@locationBeforeExample)

      up.layer.current.accept()

      expect(up.layer.current.index).toBe(0)
      expect(location.href).toMatchURL(@locationBeforeExample)

    it 'manipulates the layer stack synchronously, to avoid concurrency issues when we need to close layers within another change', ->
      makeLayers(2)
      expect(up.layer.count).toBe(2)

      up.layer.current.accept()

      expect(up.layer.count).toBe(1)

    it 'uses the configured close animation', asyncSpec (next) ->
      up.motion.config.enabled = true
      up.layer.config.modal.openAnimation = 'none'
      up.layer.config.modal.closeAnimation = 'fade-out'
      up.layer.config.modal.closeDuration = 600

      up.layer.open({ mode: 'modal' })

      next ->
        up.layer.current.accept()

      next.after 300, ->
        expect(document).toHaveSelector('up-modal')
        expect('up-modal-box').toHaveOpacity(0.5, 0.4)

      next.after 600, ->
        expect(document).not.toHaveSelector('up-modal')

    describe 'events', ->

      it 'emits an up:layer:accept event with the acceptance value'

      it 'lets an up:layer:accept event handler mutate the acceptance value'

      it 'lets an up:layer:accept event handler replace the acceptance value', ->
        makeLayers(2)
        expect(up.layer.count).toBe(2)

        acceptListener = (event) -> event.value = 'replaced'
        acceptedListener = jasmine.createSpy('up:layer:accepted listener')

        up.layer.current.on('up:layer:accept', acceptListener)
        up.layer.current.on('up:layer:accepted', acceptedListener)

        up.layer.current.accept('original')

        expect(acceptedListener).toHaveBeenCalled()
        expect(acceptedListener.calls.argsFor(0)[0].value).toBe('replaced')

      it 'lets an up:layer:accept event handler cancel the acceptance and throws an AbortError', ->
        makeLayers(2)
        expect(up.layer.count).toBe(2)

        up.layer.current.on 'up:layer:accept', (event) -> event.preventDefault()

        accept = -> up.layer.current.accept()

        expect(accept).toAbort()

        expect(up.layer.count).toBe(2)

  describe '#dismiss()', ->

    it 'closes this layer', ->
      modes = -> u.map(up.layer.stack, 'mode')

      makeLayers(2)
      expect(modes()).toEqual ['root', 'modal']

      up.layer.current.dismiss()

      expect(modes()).toEqual ['root']

    it 'takes a dismissal value that is passed to onDismissed handlers', ->
      callback = jasmine.createSpy('onDismissed handler')

      makeLayers [
        { }
        { onDismissed: callback }
      ]
      expect(callback).not.toHaveBeenCalled()

      up.layer.current.dismiss('dismissal value')

      expect(callback).toHaveBeenCalledWith(jasmine.objectContaining(value: 'dismissal value'))

  describe '#location', ->

    beforeEach ->
      up.history.config.enabled = true

    describe 'if the layer is the frontmost layer', ->

      it 'returns the current browser location', ->
        up.layer.open(location: '/foo/bar', history: true)
        expect(up.layer.isOverlay()).toBe(true)
        expect(up.layer.location).toEqual('/foo/bar')

        history.replaceState({}, 'title', '/qux')
        expect(up.layer.location).toEqual('/qux')

      it 'returns the current browser location with a #hash', ->
        up.layer.open(location: '/foo/bar', history: true)
        expect(up.layer.isOverlay()).toBe(true)
        expect(up.layer.location).toEqual('/foo/bar')

        history.replaceState({}, 'title', '/qux#hash')
        expect(up.layer.location).toEqual('/qux#hash')

    describe 'for an overlay that does not render history', ->

      it 'returns the location of the last fragment update that rendered history', ->
        up.layer.open(content: 'step1', history: false)
        expect(up.layer.isOverlay()).toBe(true)

        up.render(content: 'step2', history: true, location: '/step2', target: ':layer')

        expect(up.layer.location).toEqual('/step2')

    describe 'for an overlay in the background', ->

      it "returns the overlay's location", ->
        [overlay1, overlay2] = makeLayers [
          { history: true, location: '/overlay1' }
          { history: true, location: '/overlay2' }
        ]

        expect(overlay1.location).toEqual('/overlay1')
        expect(overlay2.location).toEqual('/overlay2')

      it "returns the overlay's location with a #hash", asyncSpec (next) ->
        up.layer.open({ url: '/ol1#hash', target: '.target' })

        next =>
          jasmine.respondWithSelector('.target', text: 'overlay 1')

        next =>
          up.layer.open({ url: '/ol2#hash', target: '.target' })

        next =>
          jasmine.respondWithSelector('.target', text: 'overlay 2')

        next =>
          expect(up.layer.stack.length).toBe(3)

          expect(up.layer.stack[1].location).toEqual('/ol1#hash')
          expect(up.layer.stack[2].location).toEqual('/ol2#hash')

    describe 'events', ->

      it 'should have examples'

    describe 'focus', ->

      beforeEach ->
        unless document.hasFocus()
          throw "The Jasmine spec runner must be focused for focus-related specs to pass"

      it 'traps focus within the overlay', asyncSpec (next) ->
        makeLayers(2)

        next =>
          @link1 = up.layer.affix('a[href="/one"]', text: 'link1')
          @link2 = up.layer.affix('a[href="/one"]', text: 'link2')

          @dismisser = up.fragment.get('up-modal-dismiss')

          expect(up.layer.current).toBeFocused()

          Trigger.tabSequence()

        next =>
          expect(@link1).toBeFocused()

          Trigger.tabSequence()

        next =>
          expect(@link2).toBeFocused()

          Trigger.tabSequence()

        next =>
          expect(@dismisser).toBeFocused()

          Trigger.tabSequence()

        next =>
          expect(up.layer.current).toBeFocused()

          # Focus cycle works reverse, too
          Trigger.tabSequence({ shiftKey: true })

        next =>
          expect(@dismisser).toBeFocused()
