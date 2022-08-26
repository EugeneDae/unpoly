const u = up.util

up.Change = class Change {

  constructor(options) {
    this.options = options
  }

  cannotMatch(reason) {
    return up.error.cannotMatch(this, reason)
  }

  execute() {
    throw new up.NotImplemented()
  }

  onFinished(renderResult) {
    return this.options.onFinished?.(renderResult)
  }

  // Values we want to keep:
  // - false (no update)
  // - string (forced update)
  // Values we want to override:
  // - true (do update with defaults)
  improveHistoryValue(existingValue, newValue) {
    if ((existingValue === false) || u.isString(existingValue)) {
      return existingValue
    } else {
      return newValue
    }
  }
}
