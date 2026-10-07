import React, { useState, useMemo, useEffect } from 'react';
import { X, Building2, TrendingUp, Check, Info, Bell, Calendar, Percent, ShieldCheck, ExternalLink, AlertCircle } from 'lucide-react';
import { formatPeso } from '../utils/format';
import {
  calculateBusinessTax,
  EntityType,
  TaxRegime,
  VatStatus,
  BusinessFinancials
} from '../utils/businessTaxes';

interface BusinessTaxSimulatorModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const BusinessTaxSimulatorModal: React.FC<BusinessTaxSimulatorModalProps> = ({ isOpen, onClose }) => {
  const [entityType, setEntityType] = useState<EntityType>('sole_prop');
  const [vatStatus, setVatStatus] = useState<VatStatus>('non_vat');
  const [taxRegime, setTaxRegime] = useState<TaxRegime>('8_percent');
  
  const [revenueStr, setRevenueStr] = useState('1000000');
  const [cogsStr, setCogsStr] = useState('300000');
  const [opexStr, setOpexStr] = useState('200000');
  const [notificationsEnabled, setNotificationsEnabled] = useState(false);

  // Reset/sync logic when modal opens/toggles happen
  useEffect(() => {
    if (entityType === 'partnership') {
      setTaxRegime('graduated_itemized'); // Partnerships can't use 8%
    }
  }, [entityType]);

  useEffect(() => {
    if (vatStatus === 'vat' && taxRegime === '8_percent') {
      setTaxRegime('graduated_itemized'); // VAT cannot use 8%
    }
  }, [vatStatus, taxRegime]);

  const revenue = parseFloat(revenueStr.replace(/,/g, '')) || 0;
  const cogs = parseFloat(cogsStr.replace(/,/g, '')) || 0;
  const opex = parseFloat(opexStr.replace(/,/g, '')) || 0;

  const results = useMemo(() => {
    const financials: BusinessFinancials = { revenue, cogs, opex };
    return calculateBusinessTax(entityType, financials, vatStatus, taxRegime);
  }, [entityType, vatStatus, taxRegime, revenue, cogs, opex]);

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-3 sm:p-4">
      {/* Backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-sm transition-opacity cursor-pointer"
        onClick={onClose}
      />

      {/* Modal Dialog */}
      <div className="relative w-full max-w-md bg-white dark:bg-[#27201A] rounded-3xl p-5 sm:p-6 shadow-2xl border border-[#F3DFCD] dark:border-[#383029] max-h-[92vh] flex flex-col min-h-0 overflow-hidden">
        
        {/* Header */}
        <div className="flex items-center justify-between pb-3 border-b border-[#F3DFCD] dark:border-[#383029] mb-3 shrink-0">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-2xl bg-[#FFEEDF] dark:bg-[#14100D] flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shrink-0 shadow-xs">
              <Building2 size={18} />
            </div>
            <div>
              <h2 className="text-base font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                Business Tax & Compliance
              </h2>
              <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] block">
                Sole Prop, Partnership & BIR Deadlines
              </span>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="p-1.5 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] hover:bg-[#FFEEDF] dark:hover:bg-[#383029] transition-colors cursor-pointer shrink-0"
          >
            <X size={18} />
          </button>
        </div>

        {/* Scrollable Body */}
        <div className="flex-1 min-h-0 overflow-y-auto space-y-4 pr-1">
          
          {/* Settings Section */}
          <div className="space-y-3 bg-[#FFEEDF]/20 dark:bg-[#14100D]/50 p-3 rounded-2xl border border-[#F3DFCD]/50 dark:border-[#383029]/50">
            
            {/* Entity Selection */}
            <div>
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1.5 block">
                Business Type
              </label>
              <div className="flex rounded-xl p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
                <button
                  type="button"
                  onClick={() => setEntityType('sole_prop')}
                  className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all ${
                    entityType === 'sole_prop' ? 'bg-[#B03C09] text-white' : 'text-[#6B6156] dark:text-[#AC9E92]'
                  }`}
                >
                  Sole Proprietorship
                </button>
                <button
                  type="button"
                  onClick={() => setEntityType('partnership')}
                  className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all ${
                    entityType === 'partnership' ? 'bg-[#B03C09] text-white' : 'text-[#6B6156] dark:text-[#AC9E92]'
                  }`}
                >
                  Partnership / Corp
                </button>
              </div>
            </div>

            {/* VAT Status */}
            <div>
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1.5 block">
                VAT Registration
              </label>
              <div className="flex rounded-xl p-1 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]">
                <button
                  type="button"
                  onClick={() => setVatStatus('non_vat')}
                  className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all ${
                    vatStatus === 'non_vat' ? 'bg-[#B03C09] text-white' : 'text-[#6B6156] dark:text-[#AC9E92]'
                  }`}
                >
                  Non-VAT (&lt; ₱3M)
                </button>
                <button
                  type="button"
                  onClick={() => setVatStatus('vat')}
                  className={`flex-1 py-1.5 px-2 text-xs font-bold rounded-lg transition-all ${
                    vatStatus === 'vat' ? 'bg-[#B03C09] text-white' : 'text-[#6B6156] dark:text-[#AC9E92]'
                  }`}
                >
                  VAT Registered
                </button>
              </div>
            </div>

            {/* Tax Regime */}
            <div>
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] mb-1.5 block">
                Income Tax Regime
              </label>
              <select
                value={taxRegime}
                onChange={(e) => setTaxRegime(e.target.value as TaxRegime)}
                className="w-full px-3 py-2.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
              >
                {entityType === 'sole_prop' && vatStatus === 'non_vat' && (
                  <option value="8_percent">8% Gross Income Tax (Replaces OIT & % Tax)</option>
                )}
                {entityType === 'sole_prop' && (
                  <>
                    <option value="graduated_osd">Graduated IT - OSD (40% Standard Deduction)</option>
                    <option value="graduated_itemized">Graduated IT - Itemized Deductions</option>
                  </>
                )}
                {entityType === 'partnership' && (
                  <>
                    <option value="graduated_osd">Corporate RCIT (20%) - OSD (40%)</option>
                    <option value="graduated_itemized">Corporate RCIT (20%) - Itemized Deductions</option>
                  </>
                )}
              </select>
            </div>
          </div>

          {/* Financial Inputs */}
          <div className="space-y-3">
            <div>
              <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                Annual Gross Revenue / Sales
              </label>
              <div className="relative">
                <span className="absolute left-3 top-1/2 -translate-y-1/2 text-sm font-bold text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                <input
                  type="number" step="any" value={revenueStr}
                  onChange={(e) => setRevenueStr(e.target.value)}
                  className="w-full pl-7 pr-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-sm font-extrabold focus:outline-none focus:border-[#B03C09]"
                />
              </div>
            </div>
            
            <div className="grid grid-cols-2 gap-3">
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                  Cost of Sales (COGS)
                </label>
                <div className="relative">
                  <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-xs text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                  <input
                    type="number" step="any" value={cogsStr}
                    onChange={(e) => setCogsStr(e.target.value)}
                    className="w-full pl-6 pr-2 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
              </div>
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] mb-1 block">
                  Operating Expenses (OPEX)
                </label>
                <div className="relative">
                  <span className="absolute left-2.5 top-1/2 -translate-y-1/2 text-xs text-[#6B6156] dark:text-[#AC9E92]">₱</span>
                  <input
                    type="number" step="any" value={opexStr}
                    onChange={(e) => setOpexStr(e.target.value)}
                    className="w-full pl-6 pr-2 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold focus:outline-none focus:border-[#B03C09]"
                  />
                </div>
              </div>
            </div>
          </div>

          {/* Results Summary */}
          <div className="p-4 rounded-2xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-3 shadow-xs">
            <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
              <TrendingUp size={14} className="text-[#B03C09] dark:text-[#FF9A52]" /> Profitability & Tax Computation
            </h3>
            
            <div className="divide-y divide-[#F3DFCD] dark:divide-[#383029] space-y-2 text-xs">
              <div className="flex justify-between items-center pt-1">
                <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC]">Gross Profit</span>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">{formatPeso(results.grossProfit)}</span>
              </div>
              <div className="flex justify-between items-center pt-2">
                <span className="font-medium text-[#5A5148] dark:text-[#C6B8AC]">Net Taxable Income Base</span>
                <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">{formatPeso(results.netTaxableIncome)}</span>
              </div>
              
              <div className="flex justify-between items-center pt-2">
                <div>
                  <span className="font-medium text-rose-700 dark:text-rose-500 block">Income Tax Due</span>
                  <span className="text-[9px] text-[#6B6156] dark:text-[#AC9E92]">Based on selected regime</span>
                </div>
                <span className="font-bold text-rose-700 dark:text-rose-500">-{formatPeso(results.incomeTax)}</span>
              </div>
              
              <div className="flex justify-between items-center pt-2">
                <div>
                  <span className="font-medium text-rose-700 dark:text-rose-500 block">
                    {vatStatus === 'vat' ? 'Output VAT Payable (Est)' : 'Percentage Tax Due'}
                  </span>
                  <span className="text-[9px] text-[#6B6156] dark:text-[#AC9E92]">
                    {vatStatus === 'vat' ? 'Pass-through tax not deducted from Net' : '3% of Gross Sales'}
                  </span>
                </div>
                <span className="font-bold text-rose-700 dark:text-rose-500">
                  {vatStatus === 'vat' ? 'Filed separately' : `-${formatPeso(results.businessTax)}`}
                </span>
              </div>
              
              <div className="flex justify-between items-center pt-3 mt-1 border-t-2 border-[#F3DFCD] dark:border-[#383029]">
                <div>
                  <span className="font-bold text-[#16643F] dark:text-[#5FCB8E] text-sm block">Net Income</span>
                  <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">Real cash flow after taxes & expenses</span>
                </div>
                <span className="font-black text-lg text-[#16643F] dark:text-[#5FCB8E] tabular-nums">{formatPeso(results.netIncome)}</span>
              </div>
            </div>
            
            <div className="flex items-start gap-2 p-2.5 rounded-xl bg-amber-50 dark:bg-amber-950/20 border border-amber-200 dark:border-amber-900/30">
              <Info size={14} className="text-amber-600 dark:text-amber-500 shrink-0 mt-0.5" />
              <p className="text-[10px] text-amber-800 dark:text-amber-400/90 leading-relaxed">
                Effective Tax Rate: <strong>{results.effectiveTaxRate.toFixed(1)}%</strong> of Gross Revenue.
                Always consult with a professional accountant or licensed CPA to confirm deductions, VAT input crediting, and updated BIR memos.
              </p>
            </div>
          </div>

          {/* Compliance & Deadlines */}
          <div className="space-y-2">
            <div className="flex items-center justify-between px-1">
              <h3 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1.5">
                <Calendar size={14} className="text-[#B03C09] dark:text-[#FF9A52]" /> BIR Compliance Calendar
              </h3>
              <button
                onClick={() => setNotificationsEnabled(!notificationsEnabled)}
                className={`flex items-center gap-1 px-2 py-1 rounded-full text-[9px] font-bold transition-colors ${
                  notificationsEnabled 
                    ? 'bg-[#16643F] text-white' 
                    : 'bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-[#6B6156] dark:text-[#AC9E92]'
                }`}
              >
                <Bell size={10} />
                {notificationsEnabled ? 'Alerts On' : 'Alerts Off'}
              </button>
            </div>
            
            <div className="space-y-2">
              {results.complianceForms.map((form, idx) => (
                <div key={idx} className="p-3 bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-xl shadow-xs flex items-start gap-3">
                  <div className="w-8 h-8 rounded-full bg-[#FFEEDF]/50 dark:bg-[#14100D] text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center shrink-0 border border-[#F3DFCD] dark:border-[#383029]">
                    <ShieldCheck size={14} />
                  </div>
                  <div className="flex-1">
                    <div className="flex items-center justify-between gap-2">
                      <h4 className="text-[11px] font-extrabold text-[#15120F] dark:text-[#F6EFE8]">{form.form}</h4>
                      <span className="text-[9px] font-bold px-1.5 py-0.5 rounded bg-[#F3DFCD] dark:bg-[#383029] text-[#6B6156] dark:text-[#AC9E92]">
                        {form.frequency}
                      </span>
                    </div>
                    <p className="text-[10px] text-[#B03C09] dark:text-[#FF9A52] font-semibold mt-0.5">Due: {form.deadline}</p>
                    <p className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] mt-0.5 leading-tight">{form.name} -- {form.description}</p>
                  </div>
                </div>
              ))}
              
              
              {notificationsEnabled && (
                <div className="text-center p-2 mt-2">
                  <span className="inline-flex items-center gap-1 px-2 py-1 rounded-full bg-[#16643F]/10 text-[#16643F] dark:text-[#5FCB8E] text-[10px] font-bold">
                    <Check size={12} /> Push Notifications Scheduled to avoid LOA
                  </span>
                </div>
              )}

              {/* Disclaimer and EOPT Update Info */}
              <div className="mt-4 p-3 rounded-xl bg-slate-50 dark:bg-slate-900/30 border border-slate-200 dark:border-slate-800 flex items-start gap-2.5">
                <AlertCircle size={16} className="text-slate-500 dark:text-slate-400 shrink-0 mt-0.5" />
                <div className="flex flex-col gap-1.5">
                  <p className="text-[10px] text-slate-700 dark:text-slate-300 leading-relaxed">
                    <strong>Disclaimer:</strong> This simulator is for reference and estimation only and is not a replacement for official BIR assessments or professional advice from accountants or CPAs. Deadlines reflect updates from the <strong>Ease of Paying Taxes (EOPT) Act (RA 11976)</strong>, including the repeal of the ₱500 Annual Registration Fee.
                  </p>
                  <a 
                    href="https://www.bir.gov.ph" 
                    target="_blank" 
                    rel="noopener noreferrer"
                    className="inline-flex items-center gap-1 text-[10px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline"
                  >
                    Visit Official BIR Website <ExternalLink size={10} />
                  </a>
                </div>
              </div>

            </div>
          </div>
          
        </div>
      </div>
    </div>
  );
};
