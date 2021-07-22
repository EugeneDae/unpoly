u = up.util
e = up.element

class up.Change.FromContent extends up.Change

  constructor: (options) ->
    super(options)

    # If we're rendering a fragment from a { url }, options.layer will already
    # be an array of up.Layer objects, set by up.Change.FromURL. It looks up the
    # layer eagerly because in case of { layer: 'origin' } (default for navigation)
    # the { origin } element may get removed while the request was in flight.
    # From that given array we need to remove layers that have been closed while
    # the request was in flight.
    #
    # If we're rendering a framgent from local content ({ document, fragment, content }),
    # options.layer will be a layer name like "current" and needs to be looked up.
    @layers = u.filter(up.layer.getAll(@options), @isRenderableLayer)

    # Only extract options required for step building, since #execute() will be called with an
    # postflightOptions argument once the response is received and has provided refined
    # options.
    @origin = @options.origin
    @preview = @options.preview
    @mode = @options.mode

    # When we're swapping elements in origin's layer, we can be choose a fallback
    # replacement zone close to the origin instead of looking up a selector in the
    # entire layer (where it might match unrelated elements).
    if @origin
      @originLayer = up.layer.get(@origin)

  isRenderableLayer: (layer) ->
    layer == 'new' || layer.isOpen()

  getPlans: ->
    unless @plans
      @plans = []

      if @options.fragment
        # ResponseDoc allows to pass innerHTML as { fragment }, but then it also
        # requires a { target }. We use a target that matches the parsed { fragment }.
        @options.target = @getResponseDoc().rootSelector()

      # First seek { target } in all layers, then seek { fallback } in all layers.
      @expandIntoPlans(@layers, @options.target)
      @expandIntoPlans(@layers, @options.fallback)

    return @plans

  expandIntoPlans: (layers, targets) ->
    for layer in layers
      # An abstract selector like :main may expand into multiple
      # concrete selectors, like ['main', '.content'].
      for target in @expandTargets(targets, layer)
        # Any plans we add will inherit all properties from @options
        props = u.merge(@options, { target, layer, placement: @defaultPlacement() })
        if layer == 'new'
          change = new up.Change.OpenLayer(props)
        else
          change = new up.Change.UpdateLayer(props)
        @plans.push(change)

  expandTargets: (targets, layer) ->
    return up.fragment.expandTargets(targets, { layer, @mode, @origin })

  execute: ->
    # Preloading from local content is a no-op.
    if @options.preload
      return Promise.resolve()

    executePlan = (plan) => plan.execute(@getResponseDoc())
    return @seekPlan(executePlan) or @postflightTargetNotApplicable()

  getResponseDoc: ->
    unless @preview || @responseDoc
      docOptions = u.pick(@options, ['target', 'content', 'fragment', 'document', 'html'])
      up.migrate.handleResponseDocOptions?(docOptions)

      # If neither { document } nor { fragment } source is given, we assume { content }.
      if @defaultPlacement() == 'content'
        # When processing { content }, ResponseDoc needs a { target }
        # to create a matching element.
        docOptions.target = @firstExpandedTarget(docOptions.target)

      @responseDoc = new up.ResponseDoc(docOptions)

    return @responseDoc

  defaultPlacement: ->
    if !@options.document && !@options.fragment
      return 'content'

  # When the user provided a { content } we need an actual CSS selector for
  # which up.ResponseDoc can create a matching element.
  firstExpandedTarget: (target) ->
    return @expandTargets(target || ':main', @layers[0])[0]

  # Returns information about the change that is most likely before the request was dispatched.
  # This might change postflight if the response does not contain the desired target.
  preflightProps: (opts = {}) ->
    getPlanProps = (plan) -> plan.preflightProps()
    @seekPlan(getPlanProps) or opts.optional or @preflightTargetNotApplicable()

  preflightTargetNotApplicable: ->
    @targetNotApplicable('Could not find target in current page')

  postflightTargetNotApplicable: ->
    @targetNotApplicable('Could not find common target in current page and response')

  targetNotApplicable: (reason) ->
    if @getPlans().length
      planTargets = u.uniq(u.map(@getPlans(), 'target'))
      humanizedLayerOption = up.layer.optionToString(@options.layer)
      up.fail(reason + " (tried selectors %o in %s)", planTargets, humanizedLayerOption)
    else if @layers.length
      up.fail('No target selector given')
    else
      up.fail('Layer %o does not exist', @options.layer)

  seekPlan: (fn) ->
    for plan in @getPlans()
      try
        # A return statement stops iteration of a vanilla for loop,
        # but would not stop an u.each() or Array#forEach().
        return fn(plan)
      catch error
        # Re-throw any unexpected type of error
        up.error.notApplicable.is(error) or throw error
