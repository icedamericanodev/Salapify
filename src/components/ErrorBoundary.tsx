import React, { Component, ErrorInfo, ReactNode } from 'react';
import { AlertTriangle, RefreshCw } from 'lucide-react';

interface Props {
  children: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null,
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Salapify caught an error:', error, errorInfo);
  }

  private handleReset = () => {
    this.setState({ hasError: false, error: null });
    window.location.reload();
  };

  public render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-[#FFEEDF] dark:bg-[#14100D] text-[#15120F] dark:text-[#F6EFE8] flex items-center justify-center p-4">
          <div className="w-full max-w-md bg-white dark:bg-[#27201A] rounded-3xl p-6 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] text-center space-y-4">
            <div className="w-12 h-12 rounded-2xl bg-[#9E2C1B]/10 text-[#9E2C1B] dark:text-[#FF8A6E] flex items-center justify-center mx-auto">
              <AlertTriangle size={24} />
            </div>
            <div>
              <h2 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                Something went wrong
              </h2>
              <p className="text-xs text-[#6B6156] dark:text-[#AC9E92] mt-1">
                Your data is safe in local storage. Click below to recover the session.
              </p>
            </div>
            <button
              type="button"
              onClick={this.handleReset}
              className="w-full py-2.5 rounded-xl bg-[#B03C09] hover:bg-[#963307] text-white text-xs font-bold transition-all flex items-center justify-center gap-2 cursor-pointer shadow-xs"
            >
              <RefreshCw size={15} />
              <span>Reload Application</span>
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
