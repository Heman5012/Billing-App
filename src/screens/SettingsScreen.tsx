import React, { useState } from 'react';
import { 
  Building2, 
  MapPin, 
  Phone, 
  Mail, 
  FileText, 
  Save, 
  RotateCcw, 
  Check, 
  AlertCircle,
  Database,
  DollarSign,
  Percent,
  ShieldCheck,
  LogOut
} from 'lucide-react';
import { BusinessProfile } from '../types';

interface SettingsScreenProps {
  business: BusinessProfile;
  onUpdateBusiness: (updated: BusinessProfile) => Promise<boolean>;
  onResetProducts: () => Promise<void>;
  onSignOut: () => void;
  userEmail?: string;
  isDemoUser?: boolean;
}

export const SettingsScreen: React.FC<SettingsScreenProps> = ({
  business,
  onUpdateBusiness,
  onResetProducts,
  onSignOut,
  userEmail,
  isDemoUser
}) => {
  const [formData, setFormData] = useState<BusinessProfile>({ ...business });
  const [isSaving, setIsSaving] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);
  const [isResetting, setIsResetting] = useState(false);
  const [resetMessage, setResetMessage] = useState<string | null>(null);

  const handleChange = (e: React.ChangeEvent<HTMLInputElement | HTMLTextAreaElement | HTMLSelectElement>) => {
    const { name, value } = e.target;
    setFormData(prev => ({
      ...prev,
      [name]: name === 'defaultTaxRate' ? parseFloat(value) || 0 : value,
      ...(name === 'name' ? { businessName: value, name: value } : {}),
      ...(name === 'businessName' ? { businessName: value, name: value } : {})
    }));
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSaving(true);
    setSavedSuccess(false);
    try {
      const ok = await onUpdateBusiness(formData);
      if (ok) {
        setSavedSuccess(true);
        setTimeout(() => setSavedSuccess(false), 3000);
      }
    } finally {
      setIsSaving(false);
    }
  };

  const handleResetCatalog = async () => {
    if (!window.confirm('Reset all product inventory and restore original 10 FMCG items?')) {
      return;
    }
    setIsResetting(true);
    setResetMessage(null);
    try {
      await onResetProducts();
      setResetMessage('Catalog reset to standard seed FMCG inventory!');
      setTimeout(() => setResetMessage(null), 3500);
    } finally {
      setIsResetting(false);
    }
  };

  return (
    <div className="max-w-4xl mx-auto space-y-8 pb-12">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-gray-900 tracking-tight">Store & Business Settings</h1>
          <p className="text-sm text-gray-500">Configure your receipt layout, tax identification, and store profile</p>
        </div>
        
        <div className="flex items-center gap-2">
          {isDemoUser && (
            <span className="px-3 py-1 bg-amber-100 text-amber-800 text-xs font-semibold rounded-full border border-amber-200">
              Demo Merchant Mode
            </span>
          )}
          <button
            onClick={onSignOut}
            className="inline-flex items-center gap-2 px-3.5 py-2 text-sm font-medium text-red-600 bg-red-50 hover:bg-red-100 rounded-xl transition border border-red-200"
          >
            <LogOut className="w-4 h-4" />
            Sign Out
          </button>
        </div>
      </div>

      {savedSuccess && (
        <div className="p-4 bg-emerald-50 border border-emerald-200 rounded-2xl flex items-center gap-3 text-emerald-800 text-sm font-medium animate-in fade-in duration-200">
          <Check className="w-5 h-5 text-emerald-600 shrink-0" />
          Settings saved successfully! Future invoices will reflect these updated details.
        </div>
      )}

      {resetMessage && (
        <div className="p-4 bg-blue-50 border border-blue-200 rounded-2xl flex items-center gap-3 text-blue-800 text-sm font-medium animate-in fade-in duration-200">
          <Check className="w-5 h-5 text-blue-600 shrink-0" />
          {resetMessage}
        </div>
      )}

      {/* Main Settings Form */}
      <form onSubmit={handleSave} className="space-y-6">
        <div className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm space-y-6">
          <h2 className="text-base font-bold text-gray-900 flex items-center gap-2 border-b border-gray-100 pb-3">
            <Building2 className="w-5 h-5 text-emerald-600" />
            Merchant Profile (Printed on Invoices)
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1">
                Business / Store Name *
              </label>
              <div className="relative">
                <Building2 className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  name="name"
                  required
                  value={formData.businessName || formData.name || ''}
                  onChange={handleChange}
                  className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                  placeholder="e.g. BillWave Supermarket"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1">
                GSTIN / Tax ID
              </label>
              <div className="relative">
                <FileText className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="text"
                  name="gstin"
                  value={formData.gstin || ''}
                  onChange={handleChange}
                  className="w-full pl-9 pr-3 py-2 text-sm font-mono border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                  placeholder="e.g. 27AABCB1518M1ZT"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1">
                Contact Phone
              </label>
              <div className="relative">
                <Phone className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="tel"
                  name="phone"
                  value={formData.phone}
                  onChange={handleChange}
                  className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                  placeholder="+91 98765 43210"
                />
              </div>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1">
                Contact Email
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="email"
                  name="email"
                  value={formData.email}
                  onChange={handleChange}
                  className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                  placeholder="support@billwave.store"
                />
              </div>
            </div>

            <div className="md:col-span-2">
              <label className="block text-xs font-bold text-gray-700 mb-1">
                Store Physical Address
              </label>
              <div className="relative">
                <MapPin className="w-4 h-4 text-gray-400 absolute left-3 top-3" />
                <textarea
                  name="address"
                  rows={2}
                  value={formData.address}
                  onChange={handleChange}
                  className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                  placeholder="Shop No. 12, High Street, Commercial Hub, Bangalore 560001"
                />
              </div>
            </div>
          </div>
        </div>

        {/* Currency & Tax Preferences */}
        <div className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm space-y-6">
          <h2 className="text-base font-bold text-gray-900 flex items-center gap-2 border-b border-gray-100 pb-3">
            <DollarSign className="w-5 h-5 text-emerald-600" />
            Currency & Tax Policy
          </h2>

          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1">
                Display Currency Symbol
              </label>
              <select
                name="currency"
                value={formData.currency}
                onChange={handleChange}
                className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none bg-white cursor-pointer"
              >
                <option value="₹">₹ (Indian Rupee - INR)</option>
                <option value="$">$ (US Dollar - USD)</option>
                <option value="€">€ (Euro - EUR)</option>
                <option value="£">£ (British Pound - GBP)</option>
                <option value="د.إ">AED (UAE Dirham)</option>
              </select>
            </div>

            <div>
              <label className="block text-xs font-bold text-gray-700 mb-1">
                Default GST Rate (%)
              </label>
              <div className="relative">
                <Percent className="w-4 h-4 text-gray-400 absolute left-3 top-1/2 -translate-y-1/2" />
                <input
                  type="number"
                  name="defaultTaxRate"
                  min="0"
                  max="100"
                  step="0.5"
                  value={formData.defaultTaxRate}
                  onChange={handleChange}
                  className="w-full pl-9 pr-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                />
              </div>
              <p className="text-[11px] text-gray-400 mt-1">Standard rates in India: 0%, 5%, 12%, 18%, 28%</p>
            </div>

            <div className="md:col-span-2">
              <label className="block text-xs font-bold text-gray-700 mb-1">
                Receipt Footer / Terms Note
              </label>
              <textarea
                name="terms"
                rows={2}
                value={formData.terms || ''}
                onChange={handleChange}
                className="w-full px-3 py-2 text-sm border border-gray-300 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                placeholder="Goods once sold will only be exchanged within 7 days with original invoice."
              />
            </div>
          </div>

          <div className="flex justify-end pt-2">
            <button
              type="submit"
              disabled={isSaving}
              className="inline-flex items-center gap-2 px-6 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white font-semibold text-sm rounded-xl shadow-md transition disabled:opacity-50 cursor-pointer"
            >
              <Save className="w-4 h-4" />
              {isSaving ? 'Saving Changes...' : 'Save Settings'}
            </button>
          </div>
        </div>
      </form>

      {/* Database & Data Maintenance */}
      <div className="bg-white p-6 rounded-2xl border border-gray-200 shadow-sm space-y-4">
        <h2 className="text-base font-bold text-gray-900 flex items-center gap-2 border-b border-gray-100 pb-3">
          <Database className="w-5 h-5 text-purple-600" />
          Catalog & Inventory Maintenance
        </h2>

        <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 p-4 rounded-xl bg-gray-50 border border-gray-200">
          <div>
            <h3 className="text-sm font-bold text-gray-900">Restore 10 FMCG Seed Products</h3>
            <p className="text-xs text-gray-500 mt-0.5">
              Refreshes and restocks the sample products (Soap, Shampoo, Coffee, Rice, Oil, Biscuits, etc.)
            </p>
          </div>
          <button
            type="button"
            onClick={handleResetCatalog}
            disabled={isResetting}
            className="inline-flex items-center gap-1.5 px-4 py-2 text-xs font-bold text-purple-700 bg-purple-50 hover:bg-purple-100 rounded-xl border border-purple-200 transition disabled:opacity-50 shrink-0"
          >
            <RotateCcw className="w-3.5 h-3.5" />
            {isResetting ? 'Restoring...' : 'Restore Seed Catalog'}
          </button>
        </div>

        <div className="text-xs text-gray-400 p-3 bg-gray-50 rounded-xl border border-gray-100 flex items-center gap-2">
          <ShieldCheck className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>Signed in as: <strong>{userEmail || 'Demo Mode User'}</strong></span>
        </div>
      </div>
    </div>
  );
};
