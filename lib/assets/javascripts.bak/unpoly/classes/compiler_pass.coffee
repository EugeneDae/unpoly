u = up.util
e = up.element

class up.CompilerPass

  constructor: (@root, @compilers, options = {}) ->
    # Exclude all elements that are descendants of the subtrees we want to keep.
    # The exclusion process is very expensive (in one case compiling 100 slements
    # took 1.5s because of this). That's why we only do it if (1) options.skipSubtrees
    # was given and (2) there is an [up-keep] element in root.
    @skipSubtrees = options.skip
    unless @skipSubtrees.length && @root.querySelector('[up-keep]')
      @skipSubtrees = undefined

    # (1) If a caller has already looked up the layer we don't want to look it up again.
    # (2) Ddefault to the current layer in case the user manually compiles a detached element.
    @layer = options.layer || up.layer.get(@root) || up.layer.current

    @errors = []

  run: ->
    up.puts 'up.hello()', "Compiling fragment %o", @root
    # If we're compiling a fragment in a background layer, we want
    # up.layer.current to resolve to that background layer, not the front layer.
    @layer.asCurrent =>
      for compiler in @compilers
        @runCompiler(compiler)

    if @errors.length
      throw up.error.failed('Errors while compiling', { @errors })

  runCompiler: (compiler) ->
    matches = @select(compiler.selector)
    return unless matches.length

    unless compiler.isDefault
      up.puts 'up.hello()', 'Compiling "%s" on %d element(s)', compiler.selector, matches.length

    if compiler.batch
      @compileBatch(compiler, matches)
    else
      for match in matches
        @compileOneElement(compiler, match)

    up.migrate.postCompile?(matches, compiler)

  compileOneElement: (compiler, element) ->
    elementArg = if compiler.jQuery then up.browser.jQuery(element) else element
    compileArgs = [elementArg]
    # Do not retrieve and parse [up-data] unless the compiler function
    # expects a second argument. Note that we must pass data for an argument
    # count of 0, since then the function might take varargs.
    unless compiler.length == 1
      data = up.syntax.data(element)
      compileArgs.push(data)

    result = @applyCompilerFunction(compiler, element, compileArgs)

    if destructorOrDestructors = @destructorPresence(result)
      up.destructor(element, destructorOrDestructors)

  compileBatch: (compiler, elements) ->
    elementsArgs = if compiler.jQuery then up.browser.jQuery(elements) else elements
    compileArgs = [elementsArgs]
    # Do not retrieve and parse [up-data] unless the compiler function
    # expects a second argument. Note that we must pass data for an argument
    # count of 0, since then the function might take varargs.
    unless compiler.length == 1
      dataList = u.map(elements, up.syntax.data)
      compileArgs.push(dataList)

    result = @applyCompilerFunction(compiler, elements, compileArgs)

    if @destructorPresence(result)
      up.fail('Compilers with { batch: true } cannot return destructors')

  applyCompilerFunction: (compiler, elementOrElements, compileArgs) ->
    try
      compiler.apply(elementOrElements, compileArgs)
    catch error
      @errors.push(error)
      up.log.error('up.hello()', 'While compiling %o: %o', elementOrElements, error)
      up.error.emitGlobal(error)

  destructorPresence: (result) ->
    # Check if the result value looks like a destructor to filter out
    # unwanted implicit returns in CoffeeScript.
    if u.isFunction(result) || u.isArray(result) && (u.every(result, u.isFunction))
      result

  select: (selector) ->
    matches = e.subtree(@root, u.evalOption(selector))
    if @skipSubtrees
      matches = u.reject(matches, @isInSkippedSubtree)

    matches

  isInSkippedSubtree: (element) =>
    if u.contains(@skipSubtrees, element)
      true
    else if parent = element.parentElement
      @isInSkippedSubtree(parent)
    else
      false

