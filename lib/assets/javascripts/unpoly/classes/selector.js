/*
 * decaffeinate suggestions:
 * DS101: Remove unnecessary use of Array.from
 * DS102: Remove unnecessary code created because of implicit returns
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const e = up.element;
const u = up.util;

up.Selector = class Selector {

  constructor(selectors, filters = []) {
    // If the user has set config.mainTargets = [] then a selector :main
    // will resolve to an empty array.
    this.selectors = selectors;
    this.filters = filters;
    this.unionSelector = this.selectors.join(',') || 'match-none';
  }

  matches(element) {
    return e.matches(element, this.unionSelector) && this.passesFilter(element);
  }

  closest(element) {
    let parentElement;
    if (this.matches(element)) {
      return element;
    } else if (parentElement = element.parentElement) {
      return this.closest(parentElement);
    }
  }

  passesFilter(element) {
    return u.every(this.filters, filter => filter(element));
  }

  descendants(root) {
    // There's a requirement that prior selectors must match first.
    // The background here is that up.fragment.config.mainTargets may match multiple
    // elements in a layer (like .container and body), but up.fragment.get(':main') should
    // prefer to match .container.
    //
    // To respect this priority we do not join @selectors into a single, comma-separated
    // CSS selector, but rather make one query per selector and concatenate the results.
    const results = u.flatMap(this.selectors, selector => e.all(root, selector));
    return u.filter(results, element => this.passesFilter(element));
  }

  subtree(root) {
    const results = [];
    if (this.matches(root)) {
      results.push(root);
    }
    results.push(...Array.from(this.descendants(root) || []));
    return results;
  }
};
