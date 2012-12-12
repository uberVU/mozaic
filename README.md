uberVU, the leader of online social media monitoring, makes its own Coffee :)

This is our very own, home-brewed SPA framework. More details:
https://github.com/uberVU/mozaic/raw/master/mozaic.pdf

# Release notes for v0.3:
* released our latest Mozaic core internal version. Starting with this version, we will be eating our own dogfood and using Mozaic core from this repo. More details to follow.

# Release notes for v0.2:
* improved widget starter which now uses DOM Mutation events in order to detect when new widgets are added / removed
* forms support (read the comments!)
* datasource now supports "streampoll", a type of smart poll for a data channel which represents a stream; use-cases are twitter-like feeds where new items appear all the time
* support for automatic inclusion of files in index.html (actually this is a precursor to bundling, but our script just didn't make it in this releasE)
* loading animation by default
* support for adding new items to collections and deleting items from collections in Datasource
* almost complete isolation of widget crashes (automatic wrapping of all instance methods and new Module() calls)
* garbage collection! Widgets which disappear from the DOM will be killed and the data channels referenced by them also

In this repo you have a TODO list app called TodoVU following the model from [1].

[1]: http://addyosmani.github.com/todomvc/
