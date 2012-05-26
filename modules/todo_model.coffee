define [], () ->
    class Todo extends Backbone.Model
    	
    	defaults:
    		timestamp: new Date().getTime()
    		name: ''
    		checked: false
    		starred: false

    return Todo