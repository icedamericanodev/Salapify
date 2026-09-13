# The Salapify app icon

## There isn't one

Verified 2026-09-13. Both the shipped app and the rebuild carry the **stock
Flutter logo**, byte for byte identical across all five mipmap densities, and
neither has an adaptive icon.

## Three rounds, and what each one got wrong

**Round one** was six candidates and the founder rejected all of them. The
honest fault: all six were the SAME IDEA, a flat symbol centred on a plain
tile. Three subjects explored once each in one composition. Part of that was
imagination and part was the harness, which could only draw a mark ON a ground,
so negative space and layering were not rejected, they were unavailable.

**Round two** fixed the composition problem. Eleven real references studied for
their compositional DEVICE (Slack, Boardy, Flighty, Threads, Nike Run Club,
Todoist, Monzo, Halide, Mastercard, a capiz shell window), eight genuinely
different directions. The founder's answer was the note both rounds deserved:
**"make it related to Salapify or Pan atleast."**

Correct. Every candidate so far was formally competent and had nothing to do
with this particular app. A counterchanged disc, a cropped stroke, a bitten
corner: all of them would suit any warm-toned product.

## What Pan actually is, and why it changes the palette's meaning

From `flutter/lib/widgets/pan_mascot.dart`, Pan is a chibi panda "who cradles
his cup of **kapeng Barako**, with a **peso sign rising in the steam** and a
coffee-cherry sprout on his head."

That sentence explains something the revamp docs never wrote down: **the warm
orange palette is coffee.** The theme system is named Barako, after Philippine
coffee. The colour was never arbitrary, and the first two rounds were drawing an
abstract orange that merely happened to match it.

**Founder decision: icon only, Pan stays cut.** The icon inherits Pan's OBJECT,
not his face, and D2 is untouched. That also sidesteps a real trap: this rebuild
exists because of "it looks like we copy the Tarsi", and an animal mascot on the
icon beside a competitor named after an animal invites exactly that comparison.
The cup is Pan without being a panda.

## Round three

![The candidates](icon-sheet.png)

| Light home screen | Dark home screen |
|---|---|
| ![Light](icon-home-light.png) | ![Dark](icon-home-dark.png) |

## What the renders say, honestly. Three work and four do not.

### The three that work

**Barako.** Pan's cup with two steam curls. Reads instantly, survives 48px
without losing anything, and it is warm and friendly next to a grid of blue and
green. The coffee is not decoration: it is the thing the theme system is named
after.

**Buto.** A coffee bean whose centre crease is an S, so one shape does two jobs,
Barako and the initial of Salapify. The most distinctive silhouette of the seven
and it holds perfectly at 48px.

**Pan.** The panda as pure geometry rather than soft 3D, and it reads clearly
even at 48px, which the rendered artwork never would. It is here because the
founder named Pan and deserved to see one. The mascot caution still stands.

### The four that do not

**Barako Piso** failed. The peso ended up sitting on what reads as a pedestal or
an anvil, so the tile says trophy or rubber stamp rather than coffee. The cup
crop did not survive being cropped.

**Bunga** failed. The cherry and leaves read as a lollipop or a balloon on a
string, not as a coffee cherry. It was flagged in advance as the most delicate
of the seven and the render settled it.

**Pan cut out** is too dark. The head barely separates from the slab, and the
tile measures 1.06 against Play's dark surface, so it would vanish there.

**Baso** did not come off. The counterchange device is still good, but a tapered
cup crossing a horizon reads as a plant pot or a bucket. The device needs a
shape that is unmistakable in silhouette, which is why the plain disc worked in
round two and this does not.

## The measurements that still bind

- A one-value tile cannot hold an edge on both Play surfaces. Orange is 2.10
  against the white listing page, near black is 1.06 against the dark one.
- Two hero-ramp tones cannot be told apart: `#FFD9B0` on `#FB9C52` is **1.58**,
  under the 3.0 bar. Ink stays near black.
- The 48px floor: 108 units at 0.667px each, so **nothing thinner than 6 units
  and no gap under 6**.
- Play: 512 square, submitted flat, because Play masks at **30%** and adds its
  own shadow.

## How these are made

    cd app
    flutter test test/shots/icon_preview.dart --update-goldens
