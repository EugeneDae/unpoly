###**
@module up.event
###

up.migrate.renamedPackage 'bus', 'event'

###**
[Emits an event](/up.emit) and returns whether no listener
has prevented the default action.

\#\#\# Example

```javascript
if (up.event.nobodyPrevents('disk:erase')) {
  Disk.erase()
})
```

@function up.event.nobodyPrevents
@param {string} eventType
@param {Object} eventProps
@return {boolean}
  whether no listener has prevented the default action
@deprecated
  Use `!up.emit(type).defaultPrevented` instead.
###
up.event.nobodyPrevents = (args...) ->
  up.migrate.deprecated('up.event.nobodyPrevents(type)', '!up.emit(type).defaultPrevented')
  event = up.emit(args...)
  not event.defaultPrevented
