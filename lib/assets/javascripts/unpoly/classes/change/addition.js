/*
 * decaffeinate suggestions:
 * DS102: Remove unnecessary code created because of implicit returns
 * DS205: Consider reworking code to avoid use of IIFEs
 * Full docs: https://github.com/decaffeinate/decaffeinate/blob/master/docs/suggestions.md
 */
const u = up.util;
const e = up.element;

up.Change.Addition = class Addition extends up.Change {

  constructor(options) {
    super(options);
    this.responseDoc = options.responseDoc;
    this.acceptLayer = options.acceptLayer;
    this.dismissLayer = options.dismissLayer;
    this.eventPlans = options.eventPlans || [];
  }

  handleLayerChangeRequests() {
    if (this.layer.isOverlay()) {
      // The server may send an HTTP header `X-Up-Accept-Layer: value`
      this.tryAcceptLayerFromServer();
      this.abortWhenLayerClosed();

      // A close condition { acceptLocation: '/path' } might have been
      // set when the layer was opened.
      this.layer.tryAcceptForLocation();
      this.abortWhenLayerClosed();

      // The server may send an HTTP header `X-Up-Dismiss-Layer: value`
      this.tryDismissLayerFromServer();
      this.abortWhenLayerClosed();

      // A close condition { dismissLocation: '/path' } might have been
      // set when the layer was opened.
      this.layer.tryDismissForLocation();
      this.abortWhenLayerClosed();
    }

    // On the server we support up.layer.emit('foo'), which sends:
    //
    //     X-Up-Events: [{ layer: 'current', type: 'foo'}]
    //
    // We must set the current layer to @layer so { layer: 'current' } will emit on
    // the layer that is being updated, instead of the front layer.
    //
    // A listener to such a server-sent event might also close the layer.
    return this.layer.asCurrent(() => {
      return (() => {
        const result = [];
        for (let eventPlan of this.eventPlans) {
          up.emit(eventPlan);
          result.push(this.abortWhenLayerClosed());
        }
        return result;
      })();
    });
  }

  tryAcceptLayerFromServer() {
    // When accepting without a value, the server will send X-Up-Accept-Layer: null
    if (u.isDefined(this.acceptLayer) && this.layer.isOverlay()) {
      return this.layer.accept(this.acceptLayer);
    }
  }

  tryDismissLayerFromServer() {
    // When dismissing without a value, the server will send X-Up-Dismiss-Layer: null
    if (u.isDefined(this.dismissLayer) && this.layer.isOverlay()) {
      return this.layer.dismiss(this.dismissLayer);
    }
  }

  abortWhenLayerClosed() {
    if (this.layer.isClosed()) {
      // Wind up the call stack. Whoever has closed the layer will also clean up
      // elements, handlers, etc.
      throw up.error.aborted('Layer was closed');
    }
  }

  setSource({ oldElement, newElement, source }) {
    // (1) When the server responds with an error, or when the request method is not
    //     reloadable (not GET), we keep the same source as before.
    // (2) Don't set a source if someone tries to 'keep' when opening a new layer
    if (source === 'keep') {
      source = (oldElement && up.fragment.source(oldElement));
    }

    // (1) Don't set a source if { false } is passed.
    // (2) Don't set a source if the element HTML already has an [up-source] attribute.
    if (source) {
      return e.setMissingAttr(newElement, 'up-source', u.normalizeURL(source));
    }
  }
};
