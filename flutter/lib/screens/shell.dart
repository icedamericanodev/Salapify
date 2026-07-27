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
  home(label: 'Home', icon: 'home'),
  budget(label: 'Budget', icon: 'budget'),
  history(label: 'History', icon: 'activity'),
  utang(label: 'Utang', icon: 'utang'),
  insights(label: 'Insights', icon: 'insights'),
  menu(label: 'Menu', icon: 'menu');

  const Destination({required this.label, required this.icon});

  /// The bottom bar label. Sentence case, matching ScreenHeader, because a
  /// tab reading "Budget" under a header reading "BUDGET" was the busy feeling
  /// the header refresh already fixed everywhere else.
  final String label;

  /// A semantic icon NAME resolved through salapify_icon.dart, never a raw
  /// IconData. Same rule as NavTile: one file decides how Salapify's icons are
  /// drawn, and a typo here hits a visible fallback marker that a test catches
  /// rather than a blank space that nobody notices.
  final String icon;
}
