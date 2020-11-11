# ios-multiscreen-starter

![](docs/images/arch.jpg)

Starter kit for developing hybrid iOS / web applications designed to run on a "controller" iOS device and mirrored to a passive external display.

## Important

This is meant to be a working _reference implementation_ for other applications. It is not designed to be an abstract container in to which a web application is placed.

You don't need to be an XCode or a Swift expert but there is some expectation that you know the basics and can put together a (simple) project and compile it from scratch.

## How does it work and what are the moving pieces?

![](docs/images/xcode.png)

_To be written._

### www.bundle

This is where the web application lives.

#### main.html

#### external.html

#### javascript/*.js

#### css/*.css

### SceneDelegate

### ExternalSceneDelegate

### ViewController

## See also

### WKWebView

* https://iosdevcenters.blogspot.com/2016/05/creating-simple-browser-with-wkwebview.html

### Notifications

* https://medium.com/@dmytro.anokhin/notification-in-swift-d47f641282fa

### UIScene, UIWindow and UIScreen

* https://www.donnywals.com/understanding-the-ios-13-scene-delegate/
* https://developer.apple.com/documentation/uikit/uiwindow
* https://developer.apple.com/documentation/uikit/uiscreen
* https://developer.apple.com/documentation/uikit/windows_and_screens/displaying_content_on_a_connected_screen

Out of date, with the introduction of `UIScene` but still useful:

* https://www.bignerdranch.com/blog/adding-external-display-support-to-your-ios-app-is-ridiculously-easy/
