/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const u = up.util;

up.RenderOptions = (function() {

  const GLOBAL_DEFAULTS = {
    hungry: true,
    keep: true,
    source: true,
    saveScroll: true,
    fail: 'auto'
  };

  const PRELOAD_OVERRIDES = {
    solo: false,
    confirm: false,
    feedback: false
  };

  // These properties are used before the request is sent.
  // Hence there cannot be a failVariant.
  const PREFLIGHT_KEYS = [
    'url',
    'method',
    'origin',
    'headers',
    'params',
    'cache',
    'clearCache',
    'fallback',  // this may produce a different X-Up-Target request header if { target } is missing on page
    'solo',
    'confirm',
    'feedback',
    'origin',
    'baseLayer',
    'fail',
  ];

  // These properties are used between success options and fail options.
  // There's a lot of room to think differently about what should be shared and what
  // should explictely be set separately for both cases. An argument can always be
  // that it's either convenient to share, or better to be explicit.
  //
  // Generally we have decided to share:
  //
  // - Options that are relevant before the request is sent (e.g. { url } or { solo }).
  // - Options that change how we think about the entire rendering operation.
  //   E.g. if we always want to see a server response, we set { fallback: true }.
  //
  // Generally we have decided to not share:
  //
  // - Layer-related options (e.g. target layer or options for a new layer)
  // - Options that change focus. The user might focus a specific element from a success element,
  //   like { focus: '.result', failFocus: '.errors' }.
  // - Options that change focus. The user might scroll to a specific element from a success element,
  //   like { reveal: '.result', failReaveal: '.errors' }.
  const SHARED_KEYS = PREFLIGHT_KEYS.concat([
    'keep',         // If I want to discard [up-keep] elements, I also want to discard them for the fail case.
    'hungry',       // If I want to opportunistically update [up-hungry] elements, I also want it for the fail case.
    'history',      // Note that regardless of setting, we only set history for reloadable responses (GET).
    'source',       // No strong opinions about that one. Wouldn't one always have a source? Might as well not be an option.
    'saveScroll',   // No strong opinions about that one. Wouldn't one always want to saveScroll? Might as wellnot be an option.
    'navigate'      // Also set navigate defaults for fail options
  ]);

  const CONTENT_KEYS = [
    'url',
    'content',
    'fragment',
    'document'
  ];

  // preprocess() will leave out properties for which there may be a better default
  // later, in particular from the layer config in up.Change.OpenLayer.
  const LATE_KEYS = [
    'history',
    'focus',
    'scroll'
  ];

  const navigateDefaults = function(options) {
    if (options.navigate) {
      return up.fragment.config.navigateOptions;
    }
  };

  const preloadOverrides = function(options) {
    if (options.preload) {
      return PRELOAD_OVERRIDES;
    }
  };

  const preprocess = function(options) {
    if (typeof up.migrate.preprocessRenderOptions === 'function') {
      up.migrate.preprocessRenderOptions(options);
    }

    const defaults = u.merge(
      GLOBAL_DEFAULTS,
      navigateDefaults(options)
    );

    return u.merge(
      // Leave out properties for which there may be a better default later, in particular
      // from the layer config in up.Change.OpenLayer. If we merged it now we could
      // not distinguish a user option (which always has highest priority) with a
      // default that may be overridden by the layer config. If there is no better default
      // later, the original defaults will be applied in finalize().
      u.omit(defaults, LATE_KEYS),
      // Remember the defaults in a { default } prop so we can re-use it
      // later in deriveFailOptions() and finalize().
      { defaults },
      options,
      preloadOverrides(options)
    );
  };

  const finalize = (preprocessedOptions, lateDefaults) => u.merge(
    preprocessedOptions.defaults,
    lateDefaults,
    preprocessedOptions
  );

  const assertContentGiven = function(options) {
    if (!u.some(CONTENT_KEYS, contentKey => u.isGiven(options[contentKey]))) {
      // up.layer.open() should open an empty layer without a content key.
      if (options.defaultToEmptyContent) {
        return options.content = '';
      } else {
        return up.fail('up.render() needs either { ' + CONTENT_KEYS.join(', ') + ' } option');
      }
    }
  };

  const failOverrides = function(options) {
    const overrides = {};
    for (let key in options) {
      // Note that up.fragment.successKey(key) only returns a value
      // if the given key is prefixed with "fail".
      var unprefixed;
      const value = options[key];
      if (unprefixed = up.fragment.successKey(key)) {
        overrides[unprefixed] = value;
      }
    }
    return overrides;
  };

  const deriveFailOptions = preprocessedOptions => u.merge(
    preprocessedOptions.defaults,
    u.pick(preprocessedOptions, SHARED_KEYS),
    failOverrides(preprocessedOptions)
  );

  return {
    preprocess,
    finalize,
    assertContentGiven,
    deriveFailOptions,
  };
})();
