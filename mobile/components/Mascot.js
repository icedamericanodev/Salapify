// Mascot: the public Pan component. It renders the high fidelity Skia version
// (MascotSkia) inside an error boundary. If Skia throws while rendering, for
// any reason, the boundary quietly swaps to the plain react-native-Animated
// version (MascotFallback), so a mascot problem can never take down a screen.
// Every caller keeps the same simple API: <Mascot size state style />.

import React from 'react';
import MascotSkia from './MascotSkia';
import MascotFallback from './MascotFallback';

export default class Mascot extends React.Component {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch() {
    // Intentionally quiet. The fallback renders on the next pass; there is no
    // user facing error and nothing to recover beyond showing the plain Pan.
  }

  render() {
    if (this.state.failed) return <MascotFallback {...this.props} />;
    return <MascotSkia {...this.props} />;
  }
}
