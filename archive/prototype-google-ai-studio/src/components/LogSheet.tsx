import React, { useState, useEffect, useRef } from 'react';
import {
  X,
  Sparkles,
  Check,
  Paperclip,
  Tag,
  User,
  Building,
  Calendar,
  ChevronDown,
  Plus,
  Coins,
  Calculator,
  Wallet,
  Smartphone,
  Copy,
  Camera,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { parseFastLog } from '../utils/fastlog';
import { parsePhilippineSmsReceipt } from '../utils/smsParser';
import {
  TransactionType,
  ProfileEntity,
  TransactionStatus,
  CurrencyCode,
} from '../types';
import {
  PROFILE_OPTIONS,
} from '../data/categories';
import {
  CURRENCY_NAMES,
  CURRENCY_SYMBOLS,
  convertToPhp,
  formatCurrency,
} from '../utils/currencies';
import { calculateCashTotal, CashDenominations } from '../utils/philippineFinances';

interface LogSheetProps {
  isOpen: boolean;
  onClose: () => void;
  initialType?: TransactionType;
  onOpenScan?: () => void;
}

export const LogSheet: React.FC<LogSheetProps> = ({
  isOpen,
  onClose,
  initialType = 'expense',
  onOpenScan,
}) => {
  const {
    accounts,
    addTransaction,
    activeProfile,
    categories,
    addMainCategory,
    addSubcategory,
  } = useFinancial();

  const [fastLogInput, setFastLogInput] = useState('');
  const [type, setType] = useState<TransactionType>(initialType);
  const [amountStr, setAmountStr] = useState('');
  const [currency, setCurrency] = useState<CurrencyCode>('PHP');
  const [selectedCategory, setSelectedCategory] = useState('Food & Dining');
  const [selectedSubcategory, setSelectedSubcategory] = useState('');
  const [profile, setProfile] = useState<ProfileEntity>(
    activeProfile === 'all' ? 'personal' : activeProfile
  );
  const [selectedAccountId, setSelectedAccountId] = useState(accounts[0]?.id || '');
  const [toAccountId, setToAccountId] = useState(accounts[1]?.id || '');
  const [merchant, setMerchant] = useState('');
  const [person, setPerson] = useState('');
  const [tagsInput, setTagsInput] = useState('');
  const [note, setNote] = useState('');
  const [date, setDate] = useState(new Date().toISOString().split('T')[0]);
  const [status, setStatus] = useState<TransactionStatus>('confirmed');
  const [attachmentUrl, setAttachmentUrl] = useState<string | undefined>(undefined);
  const [attachmentName, setAttachmentName] = useState<string | undefined>(undefined);
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [savedSuccess, setSavedSuccess] = useState(false);

  // Quick Inline Category creation state
  const [showQuickAddCat, setShowQuickAddCat] = useState(false);
  const [quickCatName, setQuickCatName] = useState('');
  const [quickCatEmoji, setQuickCatEmoji] = useState('🏷️');

  // Quick Inline Subcategory creation state
  const [showQuickAddSub, setShowQuickAddSub] = useState(false);
  const [quickSubName, setQuickSubName] = useState('');

  // Cash Denominations State for Cash-First entry
  const [showCashCounter, setShowCashCounter] = useState(false);
  const [cashDenoms, setCashDenoms] = useState<CashDenominations>({
    p1000: 0,
    p500: 0,
    p200: 0,
    p100: 0,
    p50: 0,
    p20: 0,
    coins: 0,
  });

  // SMS / E-Wallet Quick-Catcher State
  const [showSmsCatcher, setShowSmsCatcher] = useState(false);
  const [smsInput, setSmsInput] = useState('');
  const [smsSuccessMessage, setSmsSuccessMessage] = useState<string | null>(null);

  const handleProcessSms = (textToParse: string) => {
    const res = parsePhilippineSmsReceipt(textToParse, accounts);
    if (res) {
      setType('expense');
      setAmountStr(res.amount.toString());
      setMerchant(res.merchant);
      setSelectedCategory(res.category);
      if (res.subcategory) setSelectedSubcategory(res.subcategory);
      if (res.suggestedAccountId) setSelectedAccountId(res.suggestedAccountId);
      if (res.refNumber) setNote(`Ref: ${res.refNumber}`);
      setSmsSuccessMessage(`✨ Auto-caught ${res.sourceType.toUpperCase()}: ₱${res.amount.toLocaleString()} at ${res.merchant}!`);
      setTimeout(() => setSmsSuccessMessage(null), 4000);
      setShowSmsCatcher(false);
    }
  };

  const fileInputRef = useRef<HTMLInputElement>(null);

  // Fast-log real-time parsing
  const parsed = parseFastLog(fastLogInput);

  useEffect(() => {
    if (parsed.isValid && fastLogInput.trim().length > 0) {
      setType(parsed.type);
      setAmountStr(parsed.amount.toString());
      setMerchant(parsed.merchant);
      setSelectedCategory(parsed.category);
      if (parsed.suggestedPerson) setPerson(parsed.suggestedPerson);
      if (parsed.suggestedProfile) setProfile(parsed.suggestedProfile);
      if (parsed.suggestedAccountKind) {
        const matchAcc = accounts.find((a) => a.kind === parsed.suggestedAccountKind);
        if (matchAcc) setSelectedAccountId(matchAcc.id);
      }
    }
  }, [fastLogInput]);

  // Update amountStr whenever cash denominations change and counter is active
  const handleDenomChange = (key: keyof CashDenominations, val: number) => {
    const updated = { ...cashDenoms, [key]: Math.max(0, val) };
    setCashDenoms(updated);
    const total = calculateCashTotal(updated);
    setAmountStr(total > 0 ? total.toString() : '');
  };

  const handleResetDenoms = () => {
    setCashDenoms({
      p1000: 0,
      p500: 0,
      p200: 0,
      p100: 0,
      p50: 0,
      p20: 0,
      coins: 0,
    });
  };

  useEffect(() => {
    if (isOpen) {
      setSavedSuccess(false);
      setFastLogInput('');
      setAmountStr('');
      setMerchant('');
      setPerson('');
      setTagsInput('');
      setNote('');
      setAttachmentUrl(undefined);
      setAttachmentName(undefined);
      setDate(new Date().toISOString().split('T')[0]);
      setStatus('confirmed');
      setCurrency('PHP');
      setProfile(activeProfile === 'all' ? 'personal' : activeProfile);
      setShowAdvanced(false);
      setShowQuickAddCat(false);
      setShowQuickAddSub(false);

      if (accounts.length > 0 && !selectedAccountId) {
        setSelectedAccountId(accounts[0].id);
      }
      if (accounts.length > 1 && !toAccountId) {
        setToAccountId(accounts[1].id);
      }
    }
  }, [isOpen, activeProfile, accounts]);

  // When category changes, reset or pick appropriate subcategories
  const availableCategories = categories.filter((c) =>
    type === 'expense'
      ? c.type === 'expense' || c.type === 'both'
      : type === 'income'
      ? c.type === 'income' || c.type === 'both'
      : c.type === 'both'
  );

  const currentCategoryObj = categories.find(
    (c) => c.name.toLowerCase() === selectedCategory.toLowerCase()
  );
  const subcategoriesList = currentCategoryObj?.subcategories || [];

  // If selectedCategory is not in the type's available categories, pick the first valid one
  useEffect(() => {
    if (type === 'transfer') {
      setSelectedCategory('Transfer');
      setSelectedSubcategory('Bank to Wallet');
    } else {
      const match = availableCategories.find((c) => c.name.toLowerCase() === selectedCategory.toLowerCase());
      if (!match && availableCategories[0]) {
        setSelectedCategory(availableCategories[0].name);
        setSelectedSubcategory(availableCategories[0].subcategories[0] || '');
      }
    }
  }, [type, categories]);

  const handleQuickAddCategory = (e: React.FormEvent) => {
    e.preventDefault();
    if (!quickCatName.trim()) return;

    const res = addMainCategory({
      name: quickCatName.trim(),
      emoji: quickCatEmoji || '🏷️',
      type: type === 'income' ? 'income' : 'expense',
      subcategories: ['General'],
      initialBudgetLimit: 2500,
    });

    if (res.success) {
      setSelectedCategory(quickCatName.trim());
      setSelectedSubcategory('General');
      setQuickCatName('');
      setQuickCatEmoji('🏷️');
      setShowQuickAddCat(false);
    }
  };

  const handleQuickAddSubcategory = (e: React.FormEvent) => {
    e.preventDefault();
    if (!quickSubName.trim() || !currentCategoryObj) return;

    const res = addSubcategory(currentCategoryObj.id, quickSubName.trim());
    if (res.success) {
      setSelectedSubcategory(quickSubName.trim());
      setQuickSubName('');
      setShowQuickAddSub(false);
    }
  };

  if (!isOpen) return null;

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setAttachmentName(file.name);
    const reader = new FileReader();
    reader.onload = () => {
      if (typeof reader.result === 'string') {
        setAttachmentUrl(reader.result);
      }
    };
    reader.readAsDataURL(file);
  };

  const addTagQuick = (tag: string) => {
    const current = tagsInput
      .split(',')
      .map((t) => t.trim())
      .filter(Boolean);
    if (!current.includes(tag)) {
      setTagsInput([...current, tag].join(', '));
    }
  };

  const handleSave = (e: React.FormEvent) => {
    e.preventDefault();
    const rawAmount = parseFloat(amountStr.replace(/,/g, ''));
    if (isNaN(rawAmount) || rawAmount <= 0) return;

    // Convert to PHP if foreign currency logged
    const finalAmount = currency === 'PHP' ? rawAmount : convertToPhp(rawAmount, currency);

    const tagsArray = tagsInput
      .split(',')
      .map((t) => t.trim())
      .filter((t) => t.length > 0)
      .map((t) => (t.startsWith('#') ? t : `#${t}`));

    addTransaction({
      type,
      amount: finalAmount,
      originalAmount: finalAmount,
      currency,
      category: type === 'transfer' ? 'Transfer' : selectedCategory,
      subcategory: type === 'transfer' ? undefined : selectedSubcategory || undefined,
      accountId: selectedAccountId,
      toAccountId: type === 'transfer' ? toAccountId : undefined,
      profile,
      person: person.trim() || undefined,
      tags: tagsArray.length > 0 ? tagsArray : undefined,
      merchant: merchant.trim() || undefined,
      note: note.trim() || undefined,
      attachmentUrl,
      attachmentName,
      date,
      status,
    });

    setSavedSuccess(true);
    setTimeout(() => {
      onClose();
    }, 400);
  };

  const numAmount = parseFloat(amountStr.replace(/,/g, '')) || 0;
  const phpEquivalent = currency !== 'PHP' ? convertToPhp(numAmount, currency) : null;

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4">
      {/* Dimmed backdrop */}
      <div
        className="fixed inset-0 bg-black/60 backdrop-blur-xs transition-opacity"
        onClick={onClose}
      />

      {/* Sheet panel */}
      <div className="relative w-full max-w-lg bg-white dark:bg-[#27201A] rounded-t-3xl sm:rounded-3xl shadow-2xl max-h-[92vh] flex flex-col overflow-hidden border border-[#F3DFCD] dark:border-[#383029] animate-in slide-in-from-bottom duration-250">
        {/* Header with drag indicator */}
        <div className="flex flex-col items-center pt-3 pb-2 px-5 border-b border-[#F3DFCD] dark:border-[#383029]">
          <div className="w-10 h-1.5 rounded-full bg-[#F3DFCD] dark:bg-[#383029] mb-2 sm:hidden" />
          <div className="w-full flex items-center justify-between">
            <div className="flex items-center gap-2">
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Accounting Ledger Entry
              </h2>
              <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] uppercase tracking-wider">
                Double-Entry
              </span>
            </div>
            <button
              type="button"
              onClick={onClose}
              className="p-1 rounded-full text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8] cursor-pointer"
            >
              <X size={19} />
            </button>
          </div>
        </div>

        {/* Scrollable form content */}
        <form onSubmit={handleSave} className="overflow-y-auto p-5 space-y-4">
          {/* SMS / E-Wallet Receipt Catcher Banner & Controls */}
          <div className="flex flex-col gap-2">
            <div className="flex items-center justify-between flex-wrap gap-2">
              <button
                type="button"
                onClick={() => setShowSmsCatcher(!showSmsCatcher)}
                className="flex items-center gap-1.5 text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
              >
                <Smartphone size={14} />
                <span>{showSmsCatcher ? 'Hide SMS Catcher' : '⚡ Paste SMS'}</span>
              </button>

              {onOpenScan && (
                <button
                  type="button"
                  onClick={() => {
                    onClose();
                    onOpenScan();
                  }}
                  className="flex items-center gap-1.5 text-xs font-bold text-[#16643F] dark:text-[#5FCB8E] hover:underline cursor-pointer"
                >
                  <Camera size={14} />
                  <span>📸 Scan Receipt / OCR</span>
                </button>
              )}

              <span className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                Instant Auto-fill
              </span>
            </div>

            {smsSuccessMessage && (
              <div className="p-2.5 rounded-xl bg-emerald-50 dark:bg-emerald-950/40 border border-emerald-200 dark:border-emerald-800 text-xs font-bold text-emerald-800 dark:text-emerald-300 animate-in fade-in">
                {smsSuccessMessage}
              </div>
            )}

            {showSmsCatcher && (
              <div className="p-3 rounded-2xl bg-[#FFEEDF]/60 dark:bg-[#1C1713] border border-[#F3DFCD] dark:border-[#383029] space-y-2 animate-in fade-in slide-in-from-top-2">
                <textarea
                  rows={2}
                  value={smsInput}
                  onChange={(e) => setSmsInput(e.target.value)}
                  placeholder="Paste your bank or e-wallet SMS here (e.g. 'You sent PHP 450.00 of GCash to JOLLIBEE on 09-20-26...')"
                  className="w-full p-2 text-xs rounded-xl bg-white dark:bg-[#251E18] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                />

                <div className="flex items-center justify-between gap-2">
                  <div className="flex flex-wrap gap-1">
                    <button
                      type="button"
                      onClick={() =>
                        handleProcessSms(
                          'You have sent PHP 450.00 of GCash to JOLLIBEE 09171234567 on 09-20-26 12:30. Ref. No. 100234567891.'
                        )
                      }
                      className="px-2 py-0.5 rounded text-[10px] font-bold bg-[#FFEEDF] dark:bg-[#2E241D] text-[#8C430B] dark:text-[#FFB076] hover:bg-[#F4DCC7] cursor-pointer"
                    >
                      Sample: GCash ₱450
                    </button>
                    <button
                      type="button"
                      onClick={() =>
                        handleProcessSms(
                          'You paid PHP 350.00 to Grab Philippines using your Maya card ending in 1234 on Sep 20. Ref: 987654.'
                        )
                      }
                      className="px-2 py-0.5 rounded text-[10px] font-bold bg-[#FFEEDF] dark:bg-[#2E241D] text-[#8C430B] dark:text-[#FFB076] hover:bg-[#F4DCC7] cursor-pointer"
                    >
                      Sample: Maya ₱350
                    </button>
                    <button
                      type="button"
                      onClick={() =>
                        handleProcessSms(
                          'Thank you for using your BPI Card ending in 5678 for PHP 850.00 at STARBUCKS BGC on 20-Sep-26.'
                        )
                      }
                      className="px-2 py-0.5 rounded text-[10px] font-bold bg-[#FFEEDF] dark:bg-[#2E241D] text-[#8C430B] dark:text-[#FFB076] hover:bg-[#F4DCC7] cursor-pointer"
                    >
                      Sample: BPI ₱850
                    </button>
                  </div>

                  <button
                    type="button"
                    onClick={() => handleProcessSms(smsInput)}
                    disabled={!smsInput.trim()}
                    className="px-3 py-1 rounded-xl text-xs font-bold bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1A0E04] disabled:opacity-40 cursor-pointer shrink-0"
                  >
                    Parse SMS
                  </button>
                </div>
              </div>
            )}
          </div>

          {/* 1. Fast-log natural input field */}
          <div className="flex flex-col gap-1.5">
            <div className="relative">
              <input
                type="text"
                autoFocus
                value={fastLogInput}
                onChange={(e) => setFastLogInput(e.target.value)}
                placeholder='Quick parse: "jollibee 250" or "freelance 15000"'
                className="w-full px-3.5 py-2.5 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs sm:text-sm font-medium text-[#15120F] dark:text-[#F6EFE8] placeholder:text-[#6B6156]/70 dark:placeholder:text-[#AC9E92]/60 focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52]"
              />
              <Sparkles
                size={16}
                className="absolute right-3 top-3 text-[#B03C09] dark:text-[#FF9A52] pointer-events-none"
              />
            </div>
            {parsed.isValid && (
              <div className="text-[11px] font-semibold text-[#B03C09] dark:text-[#FF9A52] px-1 truncate">
                {parsed.displayPreview}
              </div>
            )}
          </div>

          {/* 2. Type Segmented */}
          <div className="flex rounded-xl p-1 bg-[#FFEEDF] dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029]">
            {(['expense', 'income', 'transfer'] as TransactionType[]).map((t) => (
              <button
                key={t}
                type="button"
                onClick={() => setType(t)}
                className={`flex-1 py-1.5 text-xs font-bold rounded-lg capitalize transition-all cursor-pointer ${
                  type === t
                    ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                    : 'text-[#6B6156] dark:text-[#AC9E92]'
                }`}
              >
                {t}
              </button>
            ))}
          </div>

          {/* 3. Hero Amount Input with Multi-Currency Selector */}
          <div className="flex flex-col items-center justify-center py-2 bg-[#FFEEDF]/20 dark:bg-[#14100D]/30 rounded-2xl border border-[#F3DFCD]/60 dark:border-[#383029]/60 p-3">
            <div className="flex items-center gap-2 mb-1">
              <span className="text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92]">
                Amount & Currency
              </span>
              <select
                value={currency}
                onChange={(e) => setCurrency(e.target.value as CurrencyCode)}
                className="text-xs font-bold bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] rounded-lg px-2 py-0.5 text-[#B03C09] dark:text-[#FF9A52] focus:outline-none cursor-pointer"
              >
                {(['PHP', 'USD', 'EUR', 'JPY', 'SGD'] as CurrencyCode[]).map((c) => (
                  <option key={c} value={c}>
                    {c} ({CURRENCY_SYMBOLS[c]})
                  </option>
                ))}
              </select>
            </div>
            <div className="flex items-center justify-center gap-1.5">
              <span className="text-3xl font-extrabold text-[#15120F] dark:text-[#F6EFE8]">
                {CURRENCY_SYMBOLS[currency]}
              </span>
              <input
                type="number"
                step="any"
                required
                value={amountStr}
                onChange={(e) => setAmountStr(e.target.value)}
                placeholder="0.00"
                className="w-48 text-3xl font-extrabold text-[#15120F] dark:text-[#F6EFE8] bg-transparent border-b-2 border-[#F3DFCD] dark:border-[#383029] text-center focus:border-[#B03C09] dark:focus:border-[#FF9A52] focus:outline-none"
              />
            </div>

            {/* Quick Cash-First Denomination Counter Toggle */}
            <div className="mt-2 flex items-center justify-center gap-2">
              <button
                type="button"
                onClick={() => setShowCashCounter(!showCashCounter)}
                className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg text-[11px] font-bold bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] border border-[#F3DFCD] dark:border-[#383029] hover:bg-[#FFEEDF]/40 cursor-pointer transition-all"
              >
                <Coins size={13} />
                <span>{showCashCounter ? 'Hide Cash Counter' : 'Barya & Papel Quick Counter'}</span>
              </button>
            </div>

            {/* Interactive Philippine Cash Breakdown Tool */}
            {showCashCounter && (
              <div className="w-full mt-3 p-3 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] space-y-2.5 animate-in fade-in duration-150">
                <div className="flex items-center justify-between border-b border-[#F3DFCD]/60 dark:border-[#383029]/60 pb-1.5">
                  <span className="text-[11px] font-bold text-[#15120F] dark:text-[#F6EFE8] flex items-center gap-1">
                    <Wallet size={12} className="text-[#B03C09] dark:text-[#FF9A52]" />
                    <span>Philippine Peso Denominations</span>
                  </span>
                  <button
                    type="button"
                    onClick={handleResetDenoms}
                    className="text-[10px] font-semibold text-[#6B6156] dark:text-[#AC9E92] hover:text-[#B03C09] dark:hover:text-[#FF9A52] cursor-pointer"
                  >
                    Reset Count
                  </button>
                </div>

                <div className="grid grid-cols-3 gap-2">
                  {[
                    { key: 'p1000', label: '₱1,000', value: 1000 },
                    { key: 'p500', label: '₱500', value: 500 },
                    { key: 'p200', label: '₱200', value: 200 },
                    { key: 'p100', label: '₱100', value: 100 },
                    { key: 'p50', label: '₱50', value: 50 },
                    { key: 'p20', label: '₱20', value: 20 },
                    { key: 'coins', label: 'Barya / Coins', value: 1 },
                  ].map((denom) => (
                    <div
                      key={denom.key}
                      className="flex items-center justify-between p-1.5 rounded-lg bg-[#FFEEDF]/40 dark:bg-[#14100D]/60 border border-[#F3DFCD]/80 dark:border-[#383029]/80"
                    >
                      <span className="text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                        {denom.label}
                      </span>
                      <input
                        type="number"
                        min="0"
                        value={cashDenoms[denom.key as keyof CashDenominations] || ''}
                        onChange={(e) =>
                          handleDenomChange(
                            denom.key as keyof CashDenominations,
                            parseInt(e.target.value, 10) || 0
                          )
                        }
                        placeholder="0"
                        className="w-12 text-center text-xs font-bold py-0.5 rounded bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                      />
                    </div>
                  ))}
                </div>

                <div className="flex items-center justify-between pt-1 text-xs">
                  <span className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                    Total Cash Counted:
                  </span>
                  <span className="font-extrabold text-[#16643F] dark:text-[#5FCB8E]">
                    ₱{calculateCashTotal(cashDenoms).toLocaleString()}
                  </span>
                </div>
              </div>
            )}

            {phpEquivalent !== null && phpEquivalent > 0 && (
              <div className="text-xs font-semibold text-[#16643F] dark:text-[#5FCB8E] mt-1.5">
                ≈ {formatCurrency(phpEquivalent, 'PHP')} base PHP ledger value
              </div>
            )}
          </div>

          {/* 4. Entity Profile Selector */}
          <div className="flex flex-col gap-1.5">
            <div className="flex justify-between items-center">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1">
                <Building size={12} className="text-[#B03C09] dark:text-[#FF9A52]" />
                <span>Entity / Profile</span>
              </label>
              <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92]">
                Isolates personal vs business books
              </span>
            </div>
            <div className="grid grid-cols-4 gap-1.5">
              {PROFILE_OPTIONS.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  onClick={() => setProfile(p.id)}
                  className={`py-1.5 px-2 rounded-xl text-xs font-bold capitalize transition-all border text-center cursor-pointer ${
                    profile === p.id
                      ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent shadow-xs'
                      : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                  }`}
                >
                  {p.name}
                </button>
              ))}
            </div>
          </div>

          {/* Label / Merchant */}
          <div className="flex flex-col gap-1">
            <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
              Description / Payee / Merchant
            </label>
            <input
              type="text"
              value={merchant}
              onChange={(e) => setMerchant(e.target.value)}
              placeholder="e.g. Meralco, Grab, Jollibee, Client Apex"
              className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52]"
            />
          </div>

          {/* 5. Main Category & Subcategory */}
          {type !== 'transfer' && (
            <div className="space-y-2">
              <div className="flex flex-col gap-1.5">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                    Main Category
                  </label>
                  <button
                    type="button"
                    onClick={() => setShowQuickAddCat(!showQuickAddCat)}
                    className="flex items-center gap-1 text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                  >
                    <Plus size={12} />
                    <span>New Category</span>
                  </button>
                </div>

                {/* Quick Add Category inline form */}
                {showQuickAddCat && (
                  <div className="p-2.5 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] space-y-2 animate-in fade-in duration-150">
                    <div className="text-[11px] font-bold text-[#15120F] dark:text-[#F6EFE8]">
                      Add Quick Category ({type})
                    </div>
                    <div className="flex items-center gap-1.5">
                      <input
                        type="text"
                        maxLength={2}
                        value={quickCatEmoji}
                        onChange={(e) => setQuickCatEmoji(e.target.value)}
                        className="w-10 h-8 text-center text-sm rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029]"
                      />
                      <input
                        type="text"
                        value={quickCatName}
                        onChange={(e) => setQuickCatName(e.target.value)}
                        placeholder="Category name (e.g. Hobbies)"
                        className="flex-1 h-8 px-2 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                      />
                      <button
                        type="button"
                        onClick={handleQuickAddCategory}
                        className="h-8 px-2.5 rounded-lg bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold cursor-pointer"
                      >
                        Add
                      </button>
                    </div>
                  </div>
                )}

                <div className="flex flex-wrap gap-1.5 max-h-32 overflow-y-auto p-0.5">
                  {availableCategories.map((cat) => {
                    const isSelected = selectedCategory.toLowerCase() === cat.name.toLowerCase();
                    return (
                      <button
                        key={cat.id}
                        type="button"
                        onClick={() => {
                          setSelectedCategory(cat.name);
                          setSelectedSubcategory(cat.subcategories[0] || '');
                        }}
                        className={`px-2.5 py-1.5 rounded-full text-xs font-medium flex items-center gap-1.5 transition-all cursor-pointer border whitespace-nowrap ${
                          isSelected
                            ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent font-bold shadow-xs'
                            : 'bg-[#FFEEDF]/50 dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029] hover:border-[#B03C09]/40'
                        }`}
                      >
                        <span className="shrink-0">{cat.emoji}</span>
                        <span>{cat.name}</span>
                      </button>
                    );
                  })}
                </div>
              </div>

              {/* Subcategory */}
              <div className="flex flex-col gap-1">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                    Subcategory (Detailed Classification)
                  </label>
                  {currentCategoryObj && (
                    <button
                      type="button"
                      onClick={() => setShowQuickAddSub(!showQuickAddSub)}
                      className="flex items-center gap-1 text-[11px] font-bold text-[#B03C09] dark:text-[#FF9A52] hover:underline cursor-pointer"
                    >
                      <Plus size={12} />
                      <span>New Subcategory</span>
                    </button>
                  )}
                </div>

                {/* Quick Add Subcategory inline form */}
                {showQuickAddSub && currentCategoryObj && (
                  <div className="p-2 rounded-xl bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] flex items-center gap-1.5 animate-in fade-in duration-150">
                    <input
                      type="text"
                      value={quickSubName}
                      onChange={(e) => setQuickSubName(e.target.value)}
                      placeholder={`New subcategory for ${currentCategoryObj.name}...`}
                      className="flex-1 h-8 px-2 rounded-lg bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                    />
                    <button
                      type="button"
                      onClick={handleQuickAddSubcategory}
                      className="h-8 px-2.5 rounded-lg bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold cursor-pointer"
                    >
                      Add
                    </button>
                  </div>
                )}

                <select
                  value={selectedSubcategory}
                  onChange={(e) => setSelectedSubcategory(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                >
                  <option value="">Select subcategory (optional)</option>
                  {subcategoriesList.map((sub) => (
                    <option key={sub} value={sub}>
                      {sub}
                    </option>
                  ))}
                </select>
              </div>
            </div>
          )}

          {/* 6. Accounts (Source & Destination) */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            <div className="flex flex-col gap-1">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                {type === 'transfer' ? 'Source Account (Outflow)' : 'Account'}
              </label>
              <select
                value={selectedAccountId}
                onChange={(e) => setSelectedAccountId(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
              >
                {accounts.map((acc) => (
                  <option key={acc.id} value={acc.id}>
                    [{acc.monogram}] {acc.name} (₱{acc.balance.toLocaleString()})
                  </option>
                ))}
              </select>
            </div>

            {type === 'transfer' && (
              <div className="flex flex-col gap-1">
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                  Destination Account (Inflow)
                </label>
                <select
                  value={toAccountId}
                  onChange={(e) => setToAccountId(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer"
                >
                  {accounts
                    .filter((a) => a.id !== selectedAccountId)
                    .map((acc) => (
                      <option key={acc.id} value={acc.id}>
                        [{acc.monogram}] {acc.name} (₱{acc.balance.toLocaleString()})
                      </option>
                    ))}
                </select>
              </div>
            )}
          </div>

          {/* 7. Status & Date */}
          <div className="grid grid-cols-2 gap-2">
            <div className="flex flex-col gap-1">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                Ledger Status
              </label>
              <select
                value={status}
                onChange={(e) => setStatus(e.target.value as TransactionStatus)}
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-semibold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none cursor-pointer capitalize"
              >
                <option value="confirmed">Confirmed</option>
                <option value="reconciled">Reconciled</option>
                <option value="pending">Pending</option>
              </select>
            </div>
            <div className="flex flex-col gap-1">
              <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                Transaction Date
              </label>
              <input
                type="date"
                value={date}
                onChange={(e) => setDate(e.target.value)}
                className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
              />
            </div>
          </div>

          {/* Advanced fields toggle */}
          <button
            type="button"
            onClick={() => setShowAdvanced(!showAdvanced)}
            className="w-full py-1.5 text-xs font-semibold text-[#B03C09] dark:text-[#FF9A52] flex items-center justify-center gap-1 hover:underline cursor-pointer"
          >
            <span>{showAdvanced ? 'Hide Additional Details' : 'Add Person, Tags, Receipt & Notes'}</span>
            <ChevronDown
              size={14}
              className={`transition-transform duration-200 ${showAdvanced ? 'rotate-180' : ''}`}
            />
          </button>

          {/* Additional details drawer */}
          {showAdvanced && (
            <div className="space-y-3 pt-1 border-t border-[#F3DFCD]/60 dark:border-[#383029]/60 animate-in fade-in duration-200">
              {/* Person Involved */}
              <div className="flex flex-col gap-1">
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1">
                  <User size={12} className="text-[#B03C09] dark:text-[#FF9A52]" />
                  <span>Person Involved (Optional)</span>
                </label>
                <input
                  type="text"
                  value={person}
                  onChange={(e) => setPerson(e.target.value)}
                  placeholder="e.g. Kuya Mark, Client Sarah, Mom"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>

              {/* Tags */}
              <div className="flex flex-col gap-1">
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1">
                  <Tag size={12} className="text-[#B03C09] dark:text-[#FF9A52]" />
                  <span>Tags (Comma separated)</span>
                </label>
                <input
                  type="text"
                  value={tagsInput}
                  onChange={(e) => setTagsInput(e.target.value)}
                  placeholder="#tax-deductible, #sweldo, #project-titan"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
                <div className="flex flex-wrap gap-1 pt-1">
                  {['#tax-deductible', '#sweldo', '#household', '#business', '#pahiram'].map(
                    (quick) => (
                      <button
                        key={quick}
                        type="button"
                        onClick={() => addTagQuick(quick)}
                        className="px-2 py-0.5 rounded-full text-[10px] font-semibold bg-[#FFEEDF] dark:bg-[#383029] text-[#B03C09] dark:text-[#FF9A52] hover:opacity-80 cursor-pointer"
                      >
                        +{quick}
                      </button>
                    )
                  )}
                </div>
              </div>

              {/* Notes */}
              <div className="flex flex-col gap-1">
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                  Notes & Details
                </label>
                <textarea
                  rows={2}
                  value={note}
                  onChange={(e) => setNote(e.target.value)}
                  placeholder="Official receipt number, purpose, or split details"
                  className="w-full px-3 py-2 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] focus:outline-none resize-none"
                />
              </div>

              {/* Receipt Attachment Upload */}
              <div className="flex flex-col gap-1">
                <label className="text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC] flex items-center gap-1">
                  <Paperclip size={12} className="text-[#B03C09] dark:text-[#FF9A52]" />
                  <span>Receipt or Attachment</span>
                </label>
                <div className="flex items-center gap-2">
                  <input
                    type="file"
                    ref={fileInputRef}
                    accept="image/*,.pdf"
                    onChange={handleFileUpload}
                    className="hidden"
                  />
                  <button
                    type="button"
                    onClick={() => fileInputRef.current?.click()}
                    className="px-3 py-2 rounded-xl border border-dashed border-[#B03C09] dark:border-[#FF9A52] text-xs font-bold text-[#B03C09] dark:text-[#FF9A52] hover:bg-[#FFEEDF]/30 dark:hover:bg-[#14100D] flex items-center gap-1.5 cursor-pointer"
                  >
                    <Paperclip size={13} />
                    <span>{attachmentName ? 'Change File' : 'Upload Receipt / Slip'}</span>
                  </button>
                  {attachmentName && (
                    <span className="text-xs text-[#6B6156] dark:text-[#AC9E92] truncate max-w-[180px]">
                      {attachmentName}
                    </span>
                  )}
                </div>
                {attachmentUrl && (
                  <div className="mt-2 p-1.5 rounded-xl border border-[#F3DFCD] dark:border-[#383029] bg-stone-900 flex justify-center">
                    <img
                      src={attachmentUrl}
                      alt="Receipt preview"
                      className="max-h-24 object-contain rounded"
                    />
                  </div>
                )}
              </div>
            </div>
          )}

          {/* 8. Save entry button */}
          <div className="pt-2">
            <button
              type="submit"
              disabled={!amountStr || parseFloat(amountStr) <= 0}
              className={`w-full py-3.5 px-4 rounded-2xl font-bold text-sm shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer ${
                savedSuccess
                  ? 'bg-[#16643F] text-white'
                  : 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] hover:opacity-90 active:scale-98 disabled:opacity-50 disabled:cursor-not-allowed'
              }`}
            >
              {savedSuccess ? (
                <>
                  <Check size={18} /> Recorded in Shared Ledger
                </>
              ) : (
                'Post to Accounting Ledger'
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};
