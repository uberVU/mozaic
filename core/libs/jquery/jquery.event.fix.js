Object.defineProperties && (function (document, $){
    var
        // Use defineProperty on an object to set the value and return it
        set = function (obj, prop, val) {
            if( val !== undefined ){
                Object.defineProperty(obj, prop, {
                    value : val
                });
            }
            return val;
        },

        // special converters
        special = {
            pageX : function (evt) {
                var
                      eventDoc = this.target.ownerDocument || document
                    , doc   = eventDoc.documentElement
                    , body  = eventDoc.body
                ;
                return evt.clientX + (doc && doc.scrollLeft || body && body.scrollLeft || 0 ) - ( doc && doc.clientLeft || body && body.clientLeft || 0);
            },

            pageY : function (evt) {
                var
                      eventDoc = this.target.ownerDocument || document
                    , doc   = eventDoc.documentElement
                    , body  = eventDoc.body
                ;
                return evt.clientY + (doc && doc.scrollTop || body && body.scrollTop || 0 ) - ( doc && doc.clientTop || body && body.clientTop || 0);
            },

            relatedTarget : function (evt) {
                if(!evt) {
                    return;
                }
                return evt.fromElement === this.target ? evt.toElement : evt.fromElement;
            },

            metaKey : function (evt) {
                return evt.ctrlKey;
            },

            which : function (evt) {
                return evt.charCode != null ? evt.charCode : evt.keyCode;
            }
        }
    ;


    // support jQuery < 1.7
    if( !$.event.keyHooks )     $.event.keyHooks    = { props: [] };
    if( !$.event.mouseHooks )   $.event.mouseHooks  = { props: [] };


    // Get all properties that should be mapped
    $.each($.event.keyHooks.props.concat($.event.mouseHooks.props, $.event.props), function (i, prop) {
        if( prop !== "target" ){
            (function (){
                Object.defineProperty($.Event.prototype, prop, {
                    get : function () {
                        // get the original value, undefined when there is no original event
                        var originalValue = this.originalEvent && this.originalEvent[prop];

                        // overwrite getter lookup
                        return this['_' + prop] !== undefined ? this['_' + prop] : set(this, prop,
                            // if we have a special function and no value
                            special[prop] && originalValue === undefined ?
                                // call the special function
                                special[prop].call(this, this.originalEvent) :
                                // use the original value
                                originalValue)
                    },

                    set : function (newValue) {
                        // Set the property with underscore prefix
                        this['_' + prop] = newValue;
                    }
                });
            })();
        }
    });


    $.event.fix = function (evt) {
        if( evt[ $.expando ] ){
            return  evt;
        }

        // Create a jQuery event with at minimum a target and type set
        var original = evt, target = original.target;

        evt = $.Event(original);

        // Fix target property, if necessary (#1925, IE 6/7/8 & Safari2)
        if( !target ){
            target = original.srcElement || document;
        }

        // Target should not be a text node (#504, Safari)
        if( target.nodeType === 3 ){
            target = target.parentNode;
        }

        evt.target = target;

        return  evt;
    }
})(document, jQuery);