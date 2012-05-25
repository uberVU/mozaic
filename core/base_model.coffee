define [], () ->
    class BaseModel extends Backbone.Model
        url: ->
            ###
                Returns the url of the model or the url of the collection 
                if the model has not been saved yet.
                http://documentcloud.github.com/backbone/#Model-url
                A model that has not yet been saved will not have a collection 
                (this is our usage pattern right now). Fallback to the 
                urlRoot of the model in that case
            ###
            if @collection?
                if @id?
                    return Utils.model_url(@collection.url, @id)
                else
                    return @collection.url
            else if @urlRoot?
                if @id?    
                    return Utils.model_url(@urlRoot, @id) 
                else
                    return @urlRoot
            throw('Set a collection or the urlRoot property on the model')

    return BaseModel