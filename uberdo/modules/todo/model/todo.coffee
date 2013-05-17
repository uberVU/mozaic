define ['cs!base_model'], (BaseModel) ->

    class TodoModel extends BaseModel
        defaults:
            timestamp: new Date().getTime()
            name: ''
            checked: false
            starred: false
