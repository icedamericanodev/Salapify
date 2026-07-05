// Mascot: the public Pan component. It renders the 3D clay render version
// (MascotClay) inside an error boundary. If that ever fails to render, the
// boundary quietly swaps to the plain drawn version (MascotFallback), so a
// mascot problem can never take down a screen. Every caller keeps the same
// simple API: <Mascot size state style />.

import React from 'react';
import MascotClay from './MascotClay';
import MascotFallback from './MascotFallback';

export default class Mascot extends React.Component {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  componentDidCatch() {
    // Intentionally quiet. The fallback renders on the next pass.
  }

  render() {
    if (this.state.failed) return <MascotFallback {...this.props} />;
    return <MascotClay {...this.props} />;
  }
}
