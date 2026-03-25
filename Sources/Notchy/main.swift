import AppKit

// Disable stdout buffering so logs appear immediately
setbuf(stdout, nil)
setbuf(stderr, nil)

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
