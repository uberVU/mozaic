define [], () ->
    # This file contains core Constants specific to the Mozaic Core.
    # To add project specific constants create a new constants file and extend window.Constants

    Constants =
        # Custom error message thrown when a 401 Unauthorized message is received from the server.
        UNAUTHORIZED_EXCEPTION: '__UNAUTHORIZED__'

        TODO_MOCKS: [
            id: 1
            name: "rob the bank",
            starred: true
        ,
            id: 2
            name: "grandma' needs a bath"
        ,
            id: 3
            name: "feed that damn dog"
        ,
            id: 4
            name: "finish the hackton"
        ,
            id: 5
            name: "do your homework"
        ,
            id: 6
            name: "remember the milk",
            checked: true
        ,
            id: 7
            name: "shake that ass",
            checked: true
        ]

    window.Constants = Constants
    return Constants
