# Running Salapify 3 on your own Mac, with live updates

Written for a beginner. Every step says what it does and why it matters.

The goal: the app running on an Android emulator on your MacBook, updating in
about a second whenever the code changes, so you can tap through a feature
instead of looking at a screenshot of it.

## What you need, and the one thing Android Studio does not give you

Android Studio gives you the **Android SDK** and the **emulator**, which is the
simulated phone. It does not give you **Flutter**, which is the toolkit Salapify
3 is written in. You need both.

Check what you already have. Open Terminal and run:

    flutter --version

- **"command not found"** means Flutter is not installed. Install it below.
- **A version number that is not 3.44.6** means you have Flutter, but not the
  version this project is built against. Read "About the version" below before
  you do anything else.

### Installing Flutter, if you need to

    brew install --cask flutter

That is Homebrew, the usual way to install developer tools on a Mac. If
`brew` itself is missing, install it from https://brew.sh first.

### About the version, and why it matters

This project is built and tested against **Flutter 3.44.6**. That is not a
preference, it is the version the automated checks use, so it is the version
that decides whether your changes pass.

A newer Flutter will still run the app. The risk is quieter than that: the
command `flutter pub get` rewrites a file called `pubspec.lock` to match
whichever version ran it, and neither the app nor the tests notice. If you run
a newer Flutter and then commit that file, the checks can fail for a reason
that has nothing to do with what you changed.

So: if `git status` ever shows `app/pubspec.lock` changed and you did not
deliberately change a dependency, do not commit it. Run `git status` after any
`flutter pub get` and you will see it.

## Setting up the emulator, once

1. Open **Android Studio**.
2. From the welcome screen, open **More Actions** and then **Virtual Device
   Manager**. If a project is already open, it is under **Tools** instead.
3. Click **Create Device**. Pick **Pixel 7** or any recent Pixel. Salapify is
   designed at 412 points wide, which is what these are.
4. Pick a system image. Anything **API 34 or newer** is fine. If it says
   **Download** next to it, click that first and wait.
5. Finish, then press the **play** arrow next to your new device. A phone
   appears on your screen. Leave it running.

You only do this once. Afterwards the emulator is just an app you start.

## Running Salapify 3

In Terminal, go to wherever you cloned this repository, then:

    cd app
    flutter pub get
    flutter run

`flutter pub get` downloads the libraries the app depends on. `flutter run`
builds the app and installs it on whatever device it can see, which is your
emulator.

**The first build takes several minutes.** It is compiling everything from
nothing. Every build after that takes seconds. This is normal and is not a
problem with your machine.

If it says no devices are found, check the emulator is actually running, then:

    flutter devices

That lists what Flutter can see.

## The short version, once Flutter and the emulator exist

With the emulator running, from the repository root:

    bash tools/dev-sync.sh

That starts the app AND watches GitHub. Every fifteen seconds it checks for new
commits, pulls them, and restarts the app on the emulator by itself. You do not
type anything after that. Stop it with Ctrl-C.

It prints the commit messages of whatever it pulled, so you can see what
changed before you look at the screen.

Everything below explains the manual version of that same loop, which is worth
knowing when the script is not what you want.

## The part you asked about: live updates

Leave `flutter run` running. It stays attached to the app and watches for
changes. In that Terminal window:

- Press **`r`** for a **hot reload**. Your change appears in under a second and
  the app keeps its current state, so you stay on the screen you were on.
- Press **`R`** (capital) for a **hot restart**. Slower, a couple of seconds,
  and the app starts from its first screen. Use this when `r` does not seem to
  take, which happens for changes to things that are set up once at startup.
- Press **`q`** to quit.

### When I have pushed new work

I push code to GitHub. To bring it to your Mac, in a second Terminal window:

    git pull

Then press **`r`** in the window where `flutter run` is still going. That is
the whole loop, and it is a few seconds end to end.

If I changed something in `pubspec.yaml`, which is the list of libraries the
app uses, run `flutter pub get` before the reload. I will say so when that
happens; it is rare.

## Two things worth knowing before they confuse you

**It installs beside your live app, not over it.** Salapify 3's application id
is `dev.icedamericano.salapify3`, deliberately different from the app you use
daily. Both can sit on the same phone at once, and neither can see the other's
data. Nothing you do here can touch your real ledger.

**The emulator starts completely empty.** No accounts, no entries, no payday.
That is not a bug, and it is the single most useful thing about testing this
way: it is exactly what a stranger sees ten seconds after installing, which as
of decision D19 is who this app is being built for. It has already earned its
keep once, catching a first run that said "Set your payday in Plan" when
nothing in the app could set a payday. Every test passed and every screenshot
looked right, because both ran against data that already had one.

## Sample data, so you can actually review a screen

An empty app is the right thing to SEE once and the wrong thing to review
against. So on the empty Home screen there is a quiet **Load sample data**
link under the big button. One tap fills the app with the same ledger the
tests and the review screenshots use: three accounts, a credit card, debts in
both directions, a month of entries, budget limits set on three categories.

Three things about it, because "sample data in a real app" deserves suspicion:

1. **It cannot reach the app store.** The link is behind `kDebugMode`, which is
   a value fixed when the app is built. In a release build it is false, the
   code is dead, and the compiler removes both the link and the data. There is
   no step to remember before launch, which is the point: a step somebody has
   to remember is a step that eventually gets missed.
2. **It cannot overwrite anything.** It only appears when the ledger is empty,
   so there is never anything there to lose. That removes the risk rather than
   guarding it with a confirmation box you would learn to tap through.
3. **It is dated around today**, not around the day it was written, so the
   screens look current instead of stuck last September.

To get back to an empty app: long press the Salapify 3 icon on the emulator,
then **App info**, **Storage**, **Clear storage**. Deliberately a manual step,
because a "wipe everything" button inside the app is the one thing here that
really could destroy a ledger.

## Running on your actual phone instead

Better than the emulator for judging how something really feels, because the
screen is a real size in a real hand.

1. On the phone, open **Settings**, then **About phone**, and tap **Build
   number** seven times. It will tell you developer mode is on.
2. In the new **Developer options** menu, turn on **USB debugging**.
3. Plug the phone into the Mac. The phone asks whether to trust this computer.
   Say yes.
4. Run `flutter devices`. Your phone should be listed. Then `flutter run` as
   above, and hot reload works exactly the same.

## What is NOT set up yet, said plainly

There is no automatic build that hands you an installable APK. The live Flutter
app has one, `flutter/`, which builds and ships to your phone over the air, but
`app/` deliberately has no publisher yet: that is Phase D on the roadmap, and
decision D15 is why there is no update stamp in `app/` until then.

So today, running it yourself is the only way to see Salapify 3 on a phone.
When v3 goes to other people, it needs the same delivery machinery the live app
has, which is a phase of its own and not a switch to flip.
