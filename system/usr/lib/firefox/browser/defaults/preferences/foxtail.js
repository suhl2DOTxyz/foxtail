// Foxtail defaults for Firefox.
// Draw titlebar buttons with GTK so Foxtail's traffic-light theme applies
// (Firefox otherwise paints its own non-native buttons on Linux).
pref("widget.gtk.non-native-titlebar-buttons.enabled", false);
// Tabs in the titlebar with the window controls, like Safari.
pref("browser.tabs.inTitlebar", 1);
// Follow the system light/dark appearance.
pref("layout.css.prefers-color-scheme.content-override", 2);
