u = up.util
$ = jQuery

describe 'up.store.Session', ->

  afterEach ->
    sessionStorage.removeItem('spec')

  describe 'constructor', ->

    it 'does not create a key "undefined" in sessionStorage (bugfix)', ->
      sessionStorage.removeItem('undefined')

      store = new up.store.Session('spec')

      expect(sessionStorage.getItem('undefined')).toBeMissing()

  describe '#get', ->

    it 'returns an item that was previously set', ->
      store = new up.store.Session('spec')
      store.set('foo', 'value of foo')
      store.set('bar', 'value of bar')

      expect(store.get('foo')).toEqual('value of foo')
      expect(store.get('bar')).toEqual('value of bar')

    it 'returns undefined if no item with that key was set', ->
      store = new up.store.Session('spec')
      store.set('foo', 'value of foo')

      expect(store.get('bar')).toBeUndefined()

    it 'does not read keys from a store with anotther root key', ->
      store = new up.store.Session('spec.v1')
      store.set('foo', 'value of foo')
      expect(store.get('foo')).toEqual('value of foo')

      store = new up.store.Session('spec.v2')
      expect(store.get('foo')).toBeUndefined()

  describe '#set', ->

    it 'stores the given item in window.sessionStorage where it survives a follow without Unpoly', ->
      store = new up.store.Session('spec')
      store.set('foo', 'value of foo')

      expect(window.sessionStorage.getItem('spec')).toContain('foo')

    it 'stores boolean values across sessions', ->
      store1 = new up.store.Session('spec')
      store1.set('foo', true)
      store1.set('bar', false)

      store2 = new up.store.Session('spec')
      expect(store2.get('foo')).toEqual(true)
      expect(store2.get('bar')).toEqual(false)

    it 'stores number values across sessions', ->
      store1 = new up.store.Session('spec')
      store1.set('foo', 123)

      store2 = new up.store.Session('spec')
      expect(store2.get('foo')).toEqual(123)

    it 'stores structured values across sessions', ->
      store1 = new up.store.Session('spec')
      store1.set('foo', { bar: ['baz', 'bam'] })

      store2 = new up.store.Session('spec')
      storedValue = store2.get('foo')
      expect(u.isObject(storedValue)).toBe(true)
      expect(storedValue).toEqual { bar: ['baz', 'bam'] }

  describe '#keys', ->

    it 'returns an array of keys in the store', ->
      store = new up.store.Session('spec')
      store.set('foo', 'value of foo')
      store.set('bar', 'value of bar')

      expect(store.keys().sort()).toEqual ['bar', 'foo']

    it 'does not return keys for entries that were removed (bugfix)', ->
      store = new up.store.Session('spec')
      store.set('foo', 'value of foo')
      store.set('bar', 'value of bar')
      store.remove('bar')

      expect(store.keys().sort()).toEqual ['foo']

  describe '#values', ->

    it 'returns an array of values in the store', ->
      store = new up.store.Session('spec')
      store.set('foo', 'value of foo')
      store.set('bar', 'value of bar')

      expect(store.values().sort()).toEqual ['value of bar', 'value of foo']

  describe '#clear', ->

    it 'removes all keys from the store', ->
      store = new up.store.Session('spec')
      store.set('foo', 'value of foo')
      store.set('bar', 'value of bar')

      store.clear()

      expect(store.get('foo')).toBeUndefined()
      expect(store.get('bar')).toBeUndefined()

  describe '#remove', ->

    it 'removes the given key from the store', ->
      store = new up.store.Session('spec')
      store.set('foo', 'value of foo')
      store.set('bar', 'value of bar')

      store.remove('foo')

      expect(store.get('foo')).toBeUndefined()
      expect(store.get('bar')).toEqual('value of bar')
