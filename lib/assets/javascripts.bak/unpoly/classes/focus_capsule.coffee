u = up.util
e = up.element

PRESERVE_KEYS = ['selectionStart', 'selectionEnd', 'scrollLeft', 'scrollTop']

transferProps = (from, to) ->
  for key in PRESERVE_KEYS
    try
      to[key] = from[key]
    catch error
      # Safari throws a TypeError when accessing { selectionStart }
      # from a focused <input type="submit">. We ignore it.

focusedElementWithin = (scopeElement) ->
  focusedElement = document.activeElement
  if e.isInSubtree(scopeElement, focusedElement)
    return focusedElement

class up.FocusCapsule extends up.Record
  keys: ->
    ['selector', 'oldElement'].concat(PRESERVE_KEYS)

  restore: (scope, options) ->
    unless @wasLost()
      # If the old element was never detached (e.g. because it was kept),
      # and still has focus, we don't need to do anything.
      return

    if rediscoveredElement = e.get(scope, @selector)
      # Firefox needs focus-related props to be set *before* we focus the element
      transferProps(this, rediscoveredElement)
      up.focus(rediscoveredElement, options)
      # Signals callers that we could restore
      return true

  @preserveWithin: (oldElement) ->
    if focusedElement = focusedElementWithin(oldElement)
      plan = { oldElement, selector: up.fragment.toTarget(focusedElement) }
      transferProps(focusedElement, plan)
      return new @(plan)

  wasLost: ->
    return !focusedElementWithin(@oldElement)
