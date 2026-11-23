# Small Living Things

Small things that live on your computer, drawn entirely in code. Made by lesheess and Still.

## No. 1: Roomie

A pair of eyes that lives in your Mac's menu bar. You choose who moves in, Madam or the Gentleman. They watch you work, and now and then their card springs out of the notch: look at something far away, get up and walk, go to bed. Say you'll walk and stay put, and they will notice.

**[Download Roomie for Mac](site/roomie/Roomie.zip)** · free · macOS 13 or later, Apple silicon and Intel

Roomie is not registered with Apple yet, so the first time macOS will stop it. The zip has a short "How to install.txt"; the same steps are on the site.

### What they read

The clock, how long since you last touched the Mac, where the pointer is, that a click happened (not where), the battery level, how hot the Mac runs, whether the microphone is in use (so they keep quiet on calls) and whether the front window fills the screen. Nothing on your screen, nothing you type. There is no network code at all.

### Build it yourself

You need only Apple's Command Line Tools (`xcode-select --install`), no Xcode.

```bash
roomie/build.sh
open roomie/Roomie.app
```

The whole app is one file, `roomie/main.swift`. `roomie/lab/` holds the sketches the eyes grew out of.

## The site

`site/` is static HTML, CSS and a little JavaScript, no build step. Preview it with:

```bash
python3 -m http.server 8790 --directory site
```

## Licence

The code is here to be read, not reused: see [LICENSE](LICENSE).
