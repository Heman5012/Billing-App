import React from 'react';
import {
  LayoutDashboard,
  Package,
  ReceiptText,
  History,
  BarChart3,
  Settings,
  QrCode,
  ShoppingCart,
  LogOut,
  Sparkles,
} from 'lucide-react';
import { LocalUser } from '../services/firebase';
import { BusinessProfile } from '../types';

interface AppNavigationProps {
  activeTab: number;
  onTabChange: (index: number) => void;
  user: LocalUser | null;
  business: BusinessProfile;
  cartItemCount: number;
  cartGrandTotal: number;
  onOpenCart: () => void;
  onOpenScanner: () => void;
  onSignOut: () => void;
  onOpenVerify: () => void;
}

export const AppNavigation: React.FC<AppNavigationProps> = ({
  activeTab,
  onTabChange,
  user,
  business,
  cartItemCount,
  cartGrandTotal,
  onOpenCart,
  onOpenScanner,
  onSignOut,
  onOpenVerify,
}) => {
  const navItems = [
    { label: 'Dashboard', icon: LayoutDashboard },
    { label: 'Products', icon: Package },
    { label: 'Create Bill', icon: ReceiptText, badge: cartItemCount > 0 ? cartItemCount : undefined },
    { label: 'History', icon: History },
    { label: 'Reports', icon: BarChart3 },
    { label: 'Settings', icon: Settings },
  ];

  return (
    <header className="sticky top-0 z-40 bg-white/95 backdrop-blur-md border-b border-slate-200/90 shadow-2xs">
      <div className="max-w-7xl mx-auto px-4 sm:px-6">
        <div className="flex items-center justify-between h-16 gap-3">
          {/* Logo & Brand */}
          <div className="flex items-center gap-3 shrink-0">
            <div
              onClick={() => onTabChange(0)}
              className="flex items-center gap-2.5 cursor-pointer group select-none"
            >
              <div className="w-9 h-9 rounded-xl bg-gradient-to-tr from-emerald-600 to-teal-500 p-0.5 shadow-sm shadow-emerald-500/20 flex items-center justify-center">
                <img
                  src="/assets/images/logo.png"
                  alt="BillWave Logo"
                  className="w-full h-full object-contain rounded-[10px]"
                  onError={(e) => {
                    (e.target as HTMLElement).style.display = 'none';
                  }}
                />
              </div>
              <div>
                <div className="flex items-center gap-1.5">
                  <span className="font-extrabold text-slate-900 text-lg tracking-tight group-hover:text-blue-600 transition-colors">
                    BillWave
                  </span>
                  <span className="px-1.5 py-0.5 text-[10px] font-bold bg-amber-50 text-amber-700 border border-amber-300 rounded">
                    DEMO
                  </span>
                </div>
                <div className="text-[11px] text-slate-400 font-medium truncate max-w-[130px] sm:max-w-[200px]">
                  {business.businessName || 'Retail POS'}
                </div>
              </div>
            </div>
          </div>

          {/* Center Navigation Tabs (Desktop) */}
          <nav className="hidden md:flex items-center gap-1 bg-slate-100/80 p-1 rounded-xl border border-slate-200/60">
            {navItems.map((item, index) => {
              const Icon = item.icon;
              const isActive = activeTab === index;
              return (
                <button
                  key={item.label}
                  type="button"
                  onClick={() => onTabChange(index)}
                  className={`relative flex items-center gap-2 px-3.5 py-1.5 rounded-lg text-xs font-bold transition-all ${
                    isActive
                      ? 'bg-white text-blue-600 shadow-xs'
                      : 'text-slate-600 hover:text-slate-900 hover:bg-slate-200/50'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span>{item.label}</span>
                  {item.badge !== undefined && item.badge > 0 && (
                    <span className="ml-0.5 px-1.5 py-0.2 bg-red-500 text-white text-[10px] font-extrabold rounded-full animate-pulse">
                      {item.badge}
                    </span>
                  )}
                </button>
              );
            })}
          </nav>

          {/* Right Action Icons & User */}
          <div className="flex items-center gap-2 shrink-0">
            {/* Quick Scan Barcode Button */}
            <button
              type="button"
              onClick={onOpenScanner}
              className="p-2 sm:px-3 sm:py-2 text-xs font-bold text-blue-700 bg-blue-50 hover:bg-blue-100 border border-blue-200 rounded-xl flex items-center gap-1.5 transition-colors"
              title="Scan barcode or QR token"
            >
              <QrCode className="w-4 h-4 text-blue-600" />
              <span className="hidden sm:inline">Scan</span>
            </button>

            {/* Public Invoice Verification Link button */}
            <button
              type="button"
              onClick={onOpenVerify}
              className="hidden lg:flex items-center gap-1 px-2.5 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900 hover:bg-slate-100 border border-slate-200 rounded-xl transition-colors"
              title="Verify invoice by token"
            >
              <Sparkles className="w-3.5 h-3.5 text-amber-500" />
              <span>Verify Receipt</span>
            </button>

            {/* Active Cart Quick Pill */}
            {cartItemCount > 0 && (
              <button
                type="button"
                onClick={onOpenCart}
                className="flex items-center gap-2 px-3 py-1.5 text-xs font-extrabold text-white bg-blue-600 hover:bg-blue-700 rounded-xl shadow-xs transition-all animate-in fade-in"
              >
                <div className="relative">
                  <ShoppingCart className="w-4 h-4" />
                  <span className="absolute -top-1.5 -right-2 px-1 py-0.1 bg-red-500 text-white text-[9px] font-black rounded-full ring-2 ring-white">
                    {cartItemCount}
                  </span>
                </div>
                <span className="hidden sm:inline">
                  {business.currency}
                  {cartGrandTotal.toFixed(2)}
                </span>
              </button>
            )}

            {/* User Profile & Sign Out */}
            <div className="flex items-center gap-2 pl-2 border-l border-slate-200">
              <div className="hidden sm:block text-right">
                <div className="text-xs font-bold text-slate-800 leading-tight truncate max-w-[110px]">
                  {user?.displayName || 'Merchant'}
                </div>
                <div className="text-[10px] text-slate-400 font-medium">
                  {user?.isDemo ? 'Demo Mode' : 'Signed In'}
                </div>
              </div>
              <button
                type="button"
                onClick={onSignOut}
                className="p-2 text-slate-400 hover:text-red-600 hover:bg-red-50 rounded-xl transition-colors"
                title="Sign out / switch account"
              >
                <LogOut className="w-4 h-4" />
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Mobile Bottom Navigation Bar */}
      <nav className="md:hidden flex items-center justify-around py-2 px-1 border-t border-slate-200 bg-white">
        {navItems.map((item, index) => {
          const Icon = item.icon;
          const isActive = activeTab === index;
          return (
            <button
              key={item.label}
              type="button"
              onClick={() => onTabChange(index)}
              className={`flex flex-col items-center gap-0.5 py-1 px-2 rounded-lg text-[10px] font-bold transition-all relative ${
                isActive ? 'text-blue-600' : 'text-slate-500 hover:text-slate-800'
              }`}
            >
              <div className="relative">
                <Icon className="w-4 h-4" />
                {item.badge !== undefined && item.badge > 0 && (
                  <span className="absolute -top-1 -right-2 w-3.5 h-3.5 bg-red-500 text-white text-[8px] font-bold rounded-full flex items-center justify-center">
                    {item.badge}
                  </span>
                )}
              </div>
              <span>{item.label}</span>
            </button>
          );
        })}
      </nav>
    </header>
  );
};
