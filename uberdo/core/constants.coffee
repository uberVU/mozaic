define [], () ->
    # This file contains core Constants specific to the Mozaic Core.
    # To add project specific constants create a new constants file and extend window.Constants

    Constants =
        # Custom error message thrown when a 401 Unauthorized message is received from the server.
        UNAUTHORIZED_EXCEPTION: '__UNAUTHORIZED__'

        TODO_MOCKS: [
            id: 1
            name: "grandma' needs a bath"
        ,
            id: 2
            name: "feed that damn dog"
        ,
            id: 3
            checked: true,
            name: "remember the milk"
        ,
            id: 4
            name: "finish the hackton"
        ,
            id: 5
            checked: true,
            name: "shake that ass"
        ,
            id: 6
            name: "do your homework"
        ,
            id: 7
            starred: true,
            name: "rob the bank"
        ]

    window.Constants = Constants
    return Constants
