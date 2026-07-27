// The primary destinations, named.
//
// They used to be bare ints. `onSwitchTab(3)` meant Utang, `onSwitchTab(4)`
// meant Insights, and the only place that mapping existed was the order of the
// arms in a switch statement in main.dart. Eight call sites across six files
// depended on it, none of them said which tab they meant, and nothing would
// have failed if the tabs were reordered: every tap would simply have landed
// somewhere else, forever, in silence.
//
// The bottom bar is about to go from six destinations to five, which is exactly
// the reshuffle that class of bug waits for. Naming them first means the
// analyzer finds every site, and means a future reorder is a one-line change to
// the order below rather than an archaeology exercise.
//
// The order here IS the left-to-right order of the bar, because `index` is what
// NavigationBar's selectedIndex wants. Changing the order changes the bar.
enum Destination {
  home,
  budget,
  history,
  utang,
  insights,
  menu,
}
