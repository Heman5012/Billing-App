import React, { useState } from 'react';
import { 
  Receipt, 
  Sparkles, 
  ShieldCheck, 
  ScanLine, 
  TrendingUp, 
  Mail, 
  Lock, 
  ArrowRight, 
  PlayCircle,
  AlertCircle,
  Copy,
  Check,
  ExternalLink,
  ShieldAlert,
  Globe,
  RefreshCw,
  X
} from 'lucide-react';
import { signInWithGoogle, signInWithEmail, signUpWithEmail, startDemoSession, firebaseConfig } from '../services/firebase';

interface LoginScreenProps {
  onLoginSuccess: (user: any) => void;
}

export const LoginScreen: React.FC<LoginScreenProps> = ({ onLoginSuccess }) => {
  const [isRegister, setIsRegister] = useState(false);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [unauthorizedDomainInfo, setUnauthorizedDomainInfo] = useState<{ hostname: string; projectId: string } | null>(null);
  const [copiedDomain, setCopiedDomain] = useState(false);

  const handleDemoAccess = () => {
    setIsLoading(true);
    const demoUser = startDemoSession();
    setTimeout(() => {
      onLoginSuccess(demoUser);
      setIsLoading(false);
    }, 400);
  };

  const handleGoogleSignIn = async () => {
    setIsLoading(true);
    setError(null);
    setUnauthorizedDomainInfo(null);
    try {
      const user = await signInWithGoogle();
      onLoginSuccess(user);
    } catch (err: any) {
      if (err?.code === 'auth/unauthorized-domain' || (err?.message && err.message.includes('unauthorized-domain'))) {
        setUnauthorizedDomainInfo({
          hostname: typeof window !== 'undefined' ? window.location.hostname : 'ais-dev-...run.app',
          projectId: firebaseConfig.projectId,
        });
      } else {
        setError(err?.message || 'Google sign-in was cancelled or failed.');
      }
    } finally {
      setIsLoading(false);
    }
  };

  const handleCopyHostname = () => {
    if (unauthorizedDomainInfo?.hostname) {
      navigator.clipboard.writeText(unauthorizedDomainInfo.hostname);
      setCopiedDomain(true);
      setTimeout(() => setCopiedDomain(false), 2500);
    }
  };

  const handleEmailAuth = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!email || !password) return;
    setIsLoading(true);
    setError(null);
    try {
      const user = isRegister 
        ? await signUpWithEmail(email, password)
        : await signInWithEmail(email, password);
      onLoginSuccess(user);
    } catch (err: any) {
      setError(err?.message || 'Authentication failed. Please verify credentials.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-emerald-950 via-slate-900 to-teal-950 flex flex-col justify-center py-12 px-4 sm:px-6 lg:px-8 text-white">
      <div className="sm:mx-auto sm:w-full sm:max-w-md text-center">
        {/* App Logo */}
        <div className="inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-gradient-to-tr from-emerald-500 to-teal-400 shadow-xl shadow-emerald-500/20 mb-4">
          <Receipt className="w-9 h-9 text-white" />
        </div>
        <h1 className="text-3xl font-black tracking-tight text-white">BillWave</h1>
        <p className="mt-2 text-sm text-emerald-200/80 font-medium">
          Smart Billing, Barcode POS & Invoice Management
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-md">
        <div className="bg-white/10 backdrop-blur-xl py-8 px-6 shadow-2xl rounded-3xl border border-white/20 sm:px-10 space-y-6">
          
          {/* Quick Demo Access Hero Button */}
          <div className="p-4 rounded-2xl bg-gradient-to-r from-emerald-500/20 to-teal-500/20 border border-emerald-400/40 text-center space-y-2.5">
            <div className="flex items-center justify-center gap-1.5 text-xs font-bold text-emerald-300 uppercase tracking-wider">
              <Sparkles className="w-4 h-4 text-emerald-400" />
              Instant Full-Access Demo
            </div>
            <p className="text-xs text-gray-300">
              Explore POS billing, barcode scanning, 10 FMCG products & tax invoices right away.
            </p>
            <button
              type="button"
              onClick={handleDemoAccess}
              disabled={isLoading}
              className="w-full flex items-center justify-center gap-2 py-3 px-4 rounded-xl text-sm font-black text-slate-900 bg-gradient-to-r from-emerald-400 to-teal-300 hover:from-emerald-300 hover:to-teal-200 shadow-lg shadow-emerald-500/25 transition cursor-pointer transform active:scale-95 disabled:opacity-50"
            >
              <PlayCircle className="w-5 h-5 text-slate-900" />
              Launch POS Live Demo
            </button>
          </div>

          <div className="relative flex py-1 items-center">
            <div className="flex-grow border-t border-white/20" />
            <span className="flex-shrink mx-3 text-xs uppercase text-gray-400 font-semibold tracking-wider">
              Or Sign In With Account
            </span>
            <div className="flex-grow border-t border-white/20" />
          </div>

          {unauthorizedDomainInfo && (
            <div className="p-4 bg-amber-500/15 border-2 border-amber-400/50 rounded-2xl text-left space-y-3.5 shadow-xl">
              <div className="flex items-start justify-between gap-2">
                <div className="flex items-center gap-2 text-amber-300 font-bold text-sm">
                  <ShieldAlert className="w-5 h-5 text-amber-400 shrink-0" />
                  <span>Firebase Domain Authorization</span>
                </div>
                <button 
                  type="button" 
                  onClick={() => setUnauthorizedDomainInfo(null)}
                  className="text-gray-400 hover:text-white p-1 rounded-lg transition cursor-pointer"
                  title="Close message"
                >
                  <X className="w-4 h-4" />
                </button>
              </div>

              <p className="text-xs text-amber-100/90 leading-relaxed">
                Firebase Authentication restricts Google Sign-In popups until your hosting domain is allowlisted in the Firebase Console:
              </p>

              {/* Domain to copy */}
              <div className="space-y-1.5">
                <div className="text-[11px] font-semibold text-amber-200 flex items-center gap-1">
                  <Globe className="w-3.5 h-3.5 text-amber-300" />
                  Domain to Authorize:
                </div>
                <div className="flex items-center gap-2 bg-black/40 border border-amber-400/30 rounded-xl px-3 py-2">
                  <code className="text-xs text-amber-200 font-mono flex-1 break-all select-all font-semibold">
                    {unauthorizedDomainInfo.hostname}
                  </code>
                  <button
                    type="button"
                    onClick={handleCopyHostname}
                    className="shrink-0 flex items-center gap-1.5 px-2.5 py-1 text-xs font-bold rounded-lg bg-amber-400/20 hover:bg-amber-400/30 text-amber-200 border border-amber-400/40 transition cursor-pointer active:scale-95"
                  >
                    {copiedDomain ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                    <span>{copiedDomain ? 'Copied!' : 'Copy'}</span>
                  </button>
                </div>
              </div>

              {/* Instructions */}
              <ol className="text-xs text-gray-200 space-y-1 list-decimal list-inside pl-1 bg-black/30 p-2.5 rounded-xl border border-white/10">
                <li>Click <span className="font-semibold text-amber-300">Open Firebase Console</span> below</li>
                <li>Under <span className="font-semibold text-white">Authorized domains</span>, click <span className="font-semibold text-white">Add domain</span></li>
                <li>Paste the copied domain and click <span className="font-semibold text-white">Save</span></li>
              </ol>

              {/* Action buttons */}
              <div className="space-y-2 pt-1">
                <a
                  href={`https://console.firebase.google.com/project/${unauthorizedDomainInfo.projectId}/authentication/settings`}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="w-full flex items-center justify-center gap-2 py-2 px-3 text-xs font-bold rounded-xl bg-amber-400 hover:bg-amber-300 text-slate-950 transition shadow cursor-pointer"
                >
                  <span>Open Firebase Console Settings</span>
                  <ExternalLink className="w-3.5 h-3.5" />
                </a>

                <button
                  type="button"
                  onClick={handleGoogleSignIn}
                  disabled={isLoading}
                  className="w-full flex items-center justify-center gap-2 py-2 px-3 text-xs font-semibold rounded-xl bg-white/10 hover:bg-white/20 text-white border border-white/20 transition cursor-pointer disabled:opacity-50"
                >
                  <RefreshCw className={`w-3.5 h-3.5 ${isLoading ? 'animate-spin' : ''}`} />
                  <span>I added the domain, retry Google Sign-In</span>
                </button>

                <button
                  type="button"
                  onClick={handleDemoAccess}
                  className="w-full flex items-center justify-center gap-2 py-2 px-3 text-xs font-bold rounded-xl bg-emerald-500 hover:bg-emerald-400 text-white transition cursor-pointer shadow"
                >
                  <Sparkles className="w-3.5 h-3.5" />
                  <span>Or use Instant Demo Mode (Full POS Features)</span>
                </button>
              </div>
            </div>
          )}

          {error && !unauthorizedDomainInfo && (
            <div className="p-3 bg-red-500/20 border border-red-500/40 rounded-xl flex items-center gap-2.5 text-xs text-red-200">
              <AlertCircle className="w-4 h-4 text-red-400 shrink-0" />
              <span>{error}</span>
            </div>
          )}

          {/* Google Sign In */}
          <button
            type="button"
            onClick={handleGoogleSignIn}
            disabled={isLoading}
            className="w-full flex items-center justify-center gap-3 py-2.5 px-4 rounded-xl text-sm font-semibold text-gray-900 bg-white hover:bg-gray-100 shadow transition cursor-pointer disabled:opacity-50"
          >
            <svg className="w-4 h-4" viewBox="0 0 24 24">
              <path
                fill="#4285F4"
                d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
              />
              <path
                fill="#34A853"
                d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
              />
              <path
                fill="#FBBC05"
                d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
              />
              <path
                fill="#EA4335"
                d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
              />
            </svg>
            Continue with Google
          </button>

          {/* Email / Password Form */}
          <form onSubmit={handleEmailAuth} className="space-y-3.5">
            <div>
              <label className="block text-xs font-medium text-gray-300 mb-1">Email Address</label>
              <div className="relative">
                <Mail className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  required
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 text-sm bg-black/30 border border-white/20 rounded-xl text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-emerald-400"
                  placeholder="merchant@billwave.store"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-medium text-gray-300 mb-1">Password</label>
              <div className="relative">
                <Lock className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="password"
                  required
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 text-sm bg-black/30 border border-white/20 rounded-xl text-white placeholder-gray-400 focus:outline-none focus:ring-2 focus:ring-emerald-400"
                  placeholder="••••••••"
                />
              </div>
            </div>

            <button
              type="submit"
              disabled={isLoading}
              className="w-full flex items-center justify-center gap-2 py-2.5 px-4 rounded-xl text-sm font-bold text-white bg-emerald-600 hover:bg-emerald-500 shadow-md transition cursor-pointer disabled:opacity-50"
            >
              <span>{isRegister ? 'Create Merchant Account' : 'Sign In with Email'}</span>
              <ArrowRight className="w-4 h-4" />
            </button>
          </form>

          {/* Toggle Register / Login */}
          <div className="text-center">
            <button
              type="button"
              onClick={() => setIsRegister(!isRegister)}
              className="text-xs text-emerald-300 hover:text-emerald-200 underline transition cursor-pointer"
            >
              {isRegister ? 'Already have an account? Sign in' : "Don't have an account? Register here"}
            </button>
          </div>
        </div>

        {/* Bottom Feature Badges */}
        <div className="mt-8 grid grid-cols-3 gap-3 text-center text-xs text-emerald-200/80">
          <div className="flex flex-col items-center gap-1">
            <ScanLine className="w-5 h-5 text-emerald-400" />
            <span>Fast Barcode POS</span>
          </div>
          <div className="flex flex-col items-center gap-1">
            <ShieldCheck className="w-5 h-5 text-emerald-400" />
            <span>QR Tax Invoices</span>
          </div>
          <div className="flex flex-col items-center gap-1">
            <TrendingUp className="w-5 h-5 text-emerald-400" />
            <span>Real-time Reports</span>
          </div>
        </div>
      </div>
    </div>
  );
};
