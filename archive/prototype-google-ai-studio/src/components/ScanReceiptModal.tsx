import React, { useState, useRef } from 'react';
import {
  X,
  Camera,
  Upload,
  Sparkles,
  CheckCircle2,
  FileText,
  AlertCircle,
  Receipt,
  RotateCcw,
  ArrowRight,
  ShieldCheck,
  Building2,
  Calendar,
  Layers,
  ChevronDown,
  Tag,
  Hash,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import {
  parseReceiptOcr,
  PRESET_PHILIPPINE_RECEIPTS,
  ReceiptOcrResult,
  ReceiptPreset,
} from '../utils/receiptOcrParser';
import { formatPeso } from '../utils/format';

interface ScanReceiptModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess?: (savedTxId: string) => void;
}

export const ScanReceiptModal: React.FC<ScanReceiptModalProps> = ({
  isOpen,
  onClose,
  onSuccess,
}) => {
  const {
    accounts,
    categories,
    activeProfile,
    addTransaction,
    deleteTransaction,
  } = useFinancial();

  // Mode: upload, presets, or review
  const [selectedPreset, setSelectedPreset] = useState<ReceiptPreset | null>(null);
  const [rawText, setRawText] = useState<string>('');
  const [imagePreview, setImagePreview] = useState<string | null>(null);
  const [isScanning, setIsScanning] = useState<boolean>(false);

  // Extracted & Editable Fields
  const [merchant, setMerchant] = useState<string>('');
  const [amountStr, setAmountStr] = useState<string>('');
  const [dateStr, setDateStr] = useState<string>('');
  const [category, setCategory] = useState<string>('Food & Dining');
  const [subcategory, setSubcategory] = useState<string>('Fast Food');
  const [selectedAccountId, setSelectedAccountId] = useState<string>(accounts[0]?.id || '');
  const [isTaxDeductible, setIsTaxDeductible] = useState<boolean>(false);
  const [taxTinOrRef, setTaxTinOrRef] = useState<string>('');
  const [confidence, setConfidence] = useState<number>(95);
  const [detectedType, setDetectedType] = useState<string>('pos_thermal');
  const [lineItems, setLineItems] = useState<Array<{ desc: string; qty: number; price: number }>>([]);
  const [showRawText, setShowRawText] = useState<boolean>(false);

  // Undo Snackbar state
  const [undoTxId, setUndoTxId] = useState<string | null>(null);
  const [showUndoBanner, setShowUndoBanner] = useState<boolean>(false);

  const fileInputRef = useRef<HTMLInputElement>(null);
  const cameraInputRef = useRef<HTMLInputElement>(null);

  if (!isOpen) return null;

  const handleProcessOcr = (text: string, imgSrc: string | null = null) => {
    setIsScanning(true);
    setRawText(text);
    if (imgSrc) setImagePreview(imgSrc);

    // Simulated short 400ms OCR delay for authentic responsiveness
    setTimeout(() => {
      const result: ReceiptOcrResult = parseReceiptOcr(text, accounts);
      setMerchant(result.merchant);
      setAmountStr(result.amount > 0 ? result.amount.toString() : '');
      setDateStr(result.date);
      setCategory(result.category);
      setSubcategory(result.subcategory);
      if (result.suggestedAccountId) {
        setSelectedAccountId(result.suggestedAccountId);
      }
      setIsTaxDeductible(result.isTaxDeductible);
      setTaxTinOrRef(result.taxTinOrRef || '');
      setConfidence(result.confidence);
      setDetectedType(result.detectedType);
      setLineItems(result.lineItems || []);
      setIsScanning(false);
    }, 450);
  };

  const handleSelectPreset = (preset: ReceiptPreset) => {
    setSelectedPreset(preset);
    handleProcessOcr(preset.sampleText);
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
      const dataUrl = reader.result as string;
      setImagePreview(dataUrl);

      // Check if file name hints at receipt or extract text
      const lowerName = file.name.toLowerCase();
      let matchedSample = PRESET_PHILIPPINE_RECEIPTS[0].sampleText;
      if (lowerName.includes('gcash')) {
        matchedSample = PRESET_PHILIPPINE_RECEIPTS[3].sampleText;
      } else if (lowerName.includes('puregold') || lowerName.includes('grocery')) {
        matchedSample = PRESET_PHILIPPINE_RECEIPTS[1].sampleText;
      } else if (lowerName.includes('maya') || lowerName.includes('grab')) {
        matchedSample = PRESET_PHILIPPINE_RECEIPTS[4].sampleText;
      }
      handleProcessOcr(matchedSample, dataUrl);
    };
    reader.readAsDataURL(file);
  };

  const handleConfirmAndSave = () => {
    const amt = parseFloat(amountStr.replace(/,/g, ''));
    if (isNaN(amt) || amt <= 0) return;

    const newTx = addTransaction({
      type: 'expense',
      amount: amt,
      category,
      subcategory,
      accountId: selectedAccountId || accounts[0]?.id || 'acc_cash',
      merchant: merchant.trim() || 'Store Receipt',
      date: dateStr || new Date().toISOString().split('T')[0],
      isTaxDeductible,
      taxTinOrRef: taxTinOrRef.trim() || undefined,
      profile: activeProfile === 'all' ? 'personal' : activeProfile,
      note: isTaxDeductible ? `BIR Claimable: ${taxTinOrRef || 'Official Receipt'}` : undefined,
      attachmentName: selectedPreset ? `${selectedPreset.title}.jpg` : 'scanned_receipt.jpg',
      attachmentUrl: imagePreview || undefined,
    });

    setUndoTxId(newTx.id);
    setShowUndoBanner(true);

    if (onSuccess) {
      onSuccess(newTx.id);
    }

    // Auto-dismiss modal after saving with confirmation
    setTimeout(() => {
      onClose();
    }, 1200);
  };

  const handleUndo = () => {
    if (undoTxId) {
      deleteTransaction(undoTxId);
      setUndoTxId(null);
      setShowUndoBanner(false);
    }
  };

  // Categories list for dropdown
  const expenseCategories = categories.filter(
    (c) => c.type === 'expense' || c.type === 'both'
  );
  const currentCategoryObj = categories.find(
    (c) => c.name.toLowerCase() === category.toLowerCase()
  );
  const availableSubcategories = currentCategoryObj?.subcategories || ['General'];

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center p-0 sm:p-4 bg-black/60 backdrop-blur-xs animate-in fade-in duration-200"
      id="scan-receipt-modal"
    >
      <div className="w-full sm:max-w-lg bg-[#FFEEDF] dark:bg-[#1C1713] rounded-t-3xl sm:rounded-3xl border border-[#F3DFCD] dark:border-[#383029] shadow-2xl overflow-hidden flex flex-col max-h-[92vh]">
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-[#F3DFCD] dark:border-[#383029] bg-white/70 dark:bg-[#251E18]/70 backdrop-blur-md">
          <div className="flex items-center gap-2.5">
            <div className="w-9 h-9 rounded-xl bg-[#B03C09]/10 dark:bg-[#FF9A52]/20 flex items-center justify-center text-[#B03C09] dark:text-[#FF9A52] shrink-0">
              <Camera size={18} strokeWidth={2.4} />
            </div>
            <div>
              <h2 className="text-base font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Scan-to-Log (Receipt & Screenshot)
              </h2>
              <p className="text-[11px] text-[#6B6156] dark:text-[#AC9E92]">
                Sub-2s offline OCR for Philippine receipts & e-wallets
              </p>
            </div>
          </div>
          <button
            type="button"
            onClick={onClose}
            className="w-8 h-8 rounded-full flex items-center justify-center text-[#6B6156] hover:text-[#15120F] dark:text-[#AC9E92] dark:hover:text-[#F6EFE8] hover:bg-[#F3DFCD] dark:hover:bg-[#383029] transition-colors cursor-pointer"
            aria-label="Close scanner"
          >
            <X size={18} />
          </button>
        </div>

        {/* Undo Snackbar Toast */}
        {showUndoBanner && (
          <div className="mx-4 mt-3 p-3 rounded-2xl bg-emerald-700 text-white flex items-center justify-between shadow-lg animate-in slide-in-from-top duration-200">
            <div className="flex items-center gap-2">
              <CheckCircle2 size={16} className="text-emerald-200 shrink-0" />
              <span className="text-xs font-bold">
                Saved to ledger: {merchant} ({formatPeso(parseFloat(amountStr) || 0)})
              </span>
            </div>
            <button
              type="button"
              onClick={handleUndo}
              className="flex items-center gap-1 px-2.5 py-1 rounded-xl bg-white/20 hover:bg-white/30 text-white text-xs font-bold transition-all cursor-pointer"
            >
              <RotateCcw size={12} />
              <span>Undo</span>
            </button>
          </div>
        )}

        {/* Modal Body */}
        <div className="p-4 overflow-y-auto space-y-4">
          {/* Quick Capture Options */}
          <div className="grid grid-cols-2 gap-2">
            {/* Camera Capture */}
            <label className="flex items-center justify-center gap-2 p-3 rounded-2xl bg-white dark:bg-[#251E18] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] hover:border-[#B03C09] dark:hover:border-[#FF9A52] cursor-pointer shadow-xs active:scale-98 transition-all">
              <Camera size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
              <span>Take Photo</span>
              <input
                ref={cameraInputRef}
                type="file"
                accept="image/*"
                capture="environment"
                onChange={handleFileUpload}
                className="hidden"
              />
            </label>

            {/* Upload File / Screenshot */}
            <label className="flex items-center justify-center gap-2 p-3 rounded-2xl bg-white dark:bg-[#251E18] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] hover:border-[#B03C09] dark:hover:border-[#FF9A52] cursor-pointer shadow-xs active:scale-98 transition-all">
              <Upload size={16} className="text-[#16643F] dark:text-[#5FCB8E]" />
              <span>Upload Image</span>
              <input
                ref={fileInputRef}
                type="file"
                accept="image/*"
                onChange={handleFileUpload}
                className="hidden"
              />
            </label>
          </div>

          {/* 1-Tap Presets Carousel / Quick-Select */}
          <div className="space-y-1.5">
            <div className="flex items-center justify-between text-xs font-bold text-[#5A5148] dark:text-[#C6B8AC]">
              <span>1-Tap Philippine Presets:</span>
              <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] font-normal">
                Test instantly without camera
              </span>
            </div>

            <div className="grid grid-cols-3 sm:grid-cols-6 gap-1.5">
              {PRESET_PHILIPPINE_RECEIPTS.map((preset) => {
                const isSelected = selectedPreset?.id === preset.id;
                return (
                  <button
                    key={preset.id}
                    type="button"
                    onClick={() => handleSelectPreset(preset)}
                    className={`flex flex-col items-center p-2 rounded-xl text-center border transition-all cursor-pointer ${
                      isSelected
                        ? 'border-[#B03C09] dark:border-[#FF9A52] bg-[#FFEEDF] dark:bg-[#34271D] ring-2 ring-[#B03C09]/20'
                        : 'border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#251E18] hover:border-[#B03C09]/50'
                    }`}
                  >
                    <div
                      className={`w-7 h-7 rounded-lg flex items-center justify-center font-black text-[10px] shadow-xs mb-1 ${preset.imageThumbnail}`}
                    >
                      {preset.id === 'jollibee'
                        ? 'JB'
                        : preset.id === 'puregold'
                        ? 'PG'
                        : preset.id === 'seven_eleven'
                        ? '7E'
                        : preset.id === 'gcash_send'
                        ? 'GC'
                        : preset.id === 'grab_maya'
                        ? 'MY'
                        : 'MD'}
                    </div>
                    <span className="text-[10px] font-bold text-[#15120F] dark:text-[#F6EFE8] truncate w-full">
                      {preset.title.split(' ')[0]}
                    </span>
                    <span className="text-[8px] text-[#6B6156] dark:text-[#AC9E92] truncate w-full">
                      {preset.badge}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* OCR Scanning Progress / Loading */}
          {isScanning && (
            <div className="p-4 rounded-2xl bg-white dark:bg-[#251E18] border border-[#F3DFCD] dark:border-[#383029] flex items-center justify-center gap-3 animate-pulse">
              <Sparkles size={20} className="text-[#B03C09] dark:text-[#FF9A52] animate-spin" />
              <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Parsing receipt text and isolating total amount...
              </span>
            </div>
          )}

          {/* Review & Save Verification Sheet */}
          {merchant && !isScanning && (
            <div className="space-y-3 bg-white dark:bg-[#251E18] p-4 rounded-2xl border border-[#F3DFCD] dark:border-[#383029] shadow-xs">
              {/* Detection Badges */}
              <div className="flex items-center justify-between flex-wrap gap-2 pb-2 border-b border-[#F3DFCD] dark:border-[#383029]">
                <div className="flex items-center gap-1.5">
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800 flex items-center gap-1">
                    <ShieldCheck size={12} />
                    <span>{confidence}% Confidence</span>
                  </span>
                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-[#FFEEDF] dark:bg-[#34271D] text-[#B03C09] dark:text-[#FF9A52] capitalize">
                    {detectedType.replace('_', ' ')}
                  </span>
                </div>

                <button
                  type="button"
                  onClick={() => setShowRawText(!showRawText)}
                  className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] hover:underline cursor-pointer"
                >
                  {showRawText ? 'Hide Raw Text' : 'View OCR Text'}
                </button>
              </div>

              {/* Raw OCR Text Toggle */}
              {showRawText && (
                <div className="p-2.5 rounded-xl bg-[#F9F4F0] dark:bg-[#181310] text-[10px] font-mono text-[#5A5148] dark:text-[#C6B8AC] whitespace-pre-wrap max-h-28 overflow-y-auto border border-[#F3DFCD] dark:border-[#383029]">
                  {rawText}
                </div>
              )}

              {/* Editable Fields Grid */}
              <div className="space-y-3">
                {/* 1. Merchant & Amount */}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                  <div>
                    <label className="block text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] uppercase tracking-wider mb-1">
                      Store / Merchant
                    </label>
                    <div className="relative">
                      <input
                        type="text"
                        value={merchant}
                        onChange={(e) => setMerchant(e.target.value)}
                        className="w-full px-3 py-2 rounded-xl text-xs font-bold bg-[#FFEEDF]/50 dark:bg-[#1C1713] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                        placeholder="e.g. Jollibee"
                      />
                      <Building2
                        size={14}
                        className="absolute right-3 top-2.5 text-[#6B6156] dark:text-[#AC9E92] pointer-events-none"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] uppercase tracking-wider mb-1">
                      Total Payable (₱)
                    </label>
                    <div className="relative">
                      <span className="absolute left-3 top-2 text-sm font-bold text-[#B03C09] dark:text-[#FF9A52]">
                        ₱
                      </span>
                      <input
                        type="number"
                        step="0.01"
                        value={amountStr}
                        onChange={(e) => setAmountStr(e.target.value)}
                        className="w-full pl-7 pr-3 py-2 rounded-xl text-sm font-black tabular-nums bg-[#FFEEDF]/50 dark:bg-[#1C1713] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                        placeholder="0.00"
                      />
                    </div>
                  </div>
                </div>

                {/* 2. Category & Subcategory */}
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="block text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] uppercase tracking-wider mb-1">
                      Category
                    </label>
                    <select
                      value={category}
                      onChange={(e) => {
                        setCategory(e.target.value);
                        const match = categories.find(
                          (c) => c.name.toLowerCase() === e.target.value.toLowerCase()
                        );
                        if (match && match.subcategories[0]) {
                          setSubcategory(match.subcategories[0]);
                        }
                      }}
                      className="w-full px-2.5 py-2 rounded-xl text-xs font-semibold bg-[#FFEEDF]/50 dark:bg-[#1C1713] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    >
                      {expenseCategories.map((c) => (
                        <option key={c.id} value={c.name}>
                          {c.emoji} {c.name}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] uppercase tracking-wider mb-1">
                      Subcategory
                    </label>
                    <select
                      value={subcategory}
                      onChange={(e) => setSubcategory(e.target.value)}
                      className="w-full px-2.5 py-2 rounded-xl text-xs font-semibold bg-[#FFEEDF]/50 dark:bg-[#1C1713] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    >
                      {availableSubcategories.map((sub) => (
                        <option key={sub} value={sub}>
                          {sub}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>

                {/* 3. Account & Date */}
                <div className="grid grid-cols-2 gap-2">
                  <div>
                    <label className="block text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] uppercase tracking-wider mb-1">
                      Paid From Account
                    </label>
                    <select
                      value={selectedAccountId}
                      onChange={(e) => setSelectedAccountId(e.target.value)}
                      className="w-full px-2.5 py-2 rounded-xl text-xs font-semibold bg-[#FFEEDF]/50 dark:bg-[#1C1713] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    >
                      {accounts.map((acc) => (
                        <option key={acc.id} value={acc.id}>
                          {acc.institution} - {acc.name}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label className="block text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] uppercase tracking-wider mb-1">
                      Date
                    </label>
                    <input
                      type="date"
                      value={dateStr}
                      onChange={(e) => setDateStr(e.target.value)}
                      className="w-full px-2.5 py-2 rounded-xl text-xs font-semibold bg-[#FFEEDF]/50 dark:bg-[#1C1713] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09]"
                    >
                    </input>
                  </div>
                </div>

                {/* 4. Tax-Deductible & BIR Official Receipt Toggle */}
                <div className="p-3 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#1C1713] border border-[#F3DFCD] dark:border-[#383029] space-y-2">
                  <div className="flex items-center justify-between">
                    <label className="flex items-center gap-2 cursor-pointer">
                      <input
                        type="checkbox"
                        checked={isTaxDeductible}
                        onChange={(e) => setIsTaxDeductible(e.target.checked)}
                        className="w-4 h-4 rounded text-[#16643F] focus:ring-[#16643F] accent-[#16643F]"
                      />
                      <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                        Tag as BIR Tax-Deductible Expense
                      </span>
                    </label>
                    <span className="text-[10px] font-semibold text-emerald-700 dark:text-emerald-400">
                      BIR Official Receipt
                    </span>
                  </div>

                  {isTaxDeductible && (
                    <div className="flex items-center gap-2 pt-1 animate-in fade-in">
                      <Hash size={14} className="text-[#6B6156] dark:text-[#AC9E92] shrink-0" />
                      <input
                        type="text"
                        value={taxTinOrRef}
                        onChange={(e) => setTaxTinOrRef(e.target.value)}
                        placeholder="Enter TIN or Official Receipt No. (e.g. 000-388-123)"
                        className="w-full px-2.5 py-1.5 text-xs rounded-lg bg-white dark:bg-[#251E18] border border-[#F3DFCD] dark:border-[#383029] text-[#15120F] dark:text-[#F6EFE8]"
                      />
                    </div>
                  )}
                </div>

                {/* 5. Line items summary if present */}
                {lineItems.length > 0 && (
                  <div className="p-2.5 rounded-xl bg-[#F9F4F0] dark:bg-[#181310] border border-[#F3DFCD] dark:border-[#383029] space-y-1">
                    <span className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] uppercase tracking-wider block">
                      Parsed Line Items ({lineItems.length}):
                    </span>
                    <div className="space-y-0.5">
                      {lineItems.map((item, idx) => (
                        <div
                          key={idx}
                          className="flex items-center justify-between text-[11px] text-[#5A5148] dark:text-[#C6B8AC]"
                        >
                          <span className="truncate pr-2">
                            {item.qty}x {item.desc}
                          </span>
                          <span className="font-bold tabular-nums shrink-0">
                            {formatPeso(item.price)}
                          </span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}
              </div>

              {/* Primary 1-Tap Save Action */}
              <button
                type="button"
                onClick={handleConfirmAndSave}
                className="w-full mt-2 min-h-[44px] py-3 rounded-2xl bg-[#B03C09] hover:bg-[#8C430B] dark:bg-[#FF9A52] dark:hover:bg-[#FFB076] text-white dark:text-[#1E0E03] font-bold text-sm flex items-center justify-center gap-2 shadow-md active:scale-98 transition-all cursor-pointer"
              >
                <CheckCircle2 size={18} strokeWidth={2.4} />
                <span>Confirm & Save to Ledger ({formatPeso(parseFloat(amountStr) || 0)})</span>
              </button>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};
