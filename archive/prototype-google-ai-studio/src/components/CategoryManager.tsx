import React, { useState, useMemo } from 'react';
import {
  Plus,
  Trash2,
  Lock,
  ChevronDown,
  ChevronUp,
  AlertCircle,
  CheckCircle2,
  Search,
  ShieldCheck,
  Tag,
  FolderPlus,
  HelpCircle,
} from 'lucide-react';
import { useFinancial } from '../context/FinancialContext';
import { CategoryInfo } from '../types';

const QUICK_EMOJIS = ['🏷️', '🐾', '🎮', '☕', '📸', '🌿', '✈️', '📚', '🎨', '👶', '🚴', '🎁', '🛠️', '🍕', '💻', '💊', '🚗', '👗', '💼', '🏡'];

export const CategoryManager: React.FC = () => {
  const {
    categories,
    getCategoryTransactionCount,
    addMainCategory,
    addSubcategory,
    deleteMainCategory,
    deleteSubcategory,
    budgets,
    updateBudgetLimit,
  } = useFinancial();

  const [searchQuery, setSearchQuery] = useState('');
  const [typeFilter, setTypeFilter] = useState<'all' | 'expense' | 'income' | 'both'>('all');
  const [expandedCatId, setExpandedCatId] = useState<string | null>(null);

  // New Main Category Form state
  const [showAddForm, setShowAddForm] = useState(false);
  const [newName, setNewName] = useState('');
  const [newEmoji, setNewEmoji] = useState('🏷️');
  const [newType, setNewType] = useState<'expense' | 'income' | 'both'>('expense');
  const [newSubcategoriesStr, setNewSubcategoriesStr] = useState('');
  const [newBudgetLimit, setNewBudgetLimit] = useState('2500');
  const [formError, setFormError] = useState<string | null>(null);
  const [actionNotice, setActionNotice] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  // Inline Subcategory creation state per category
  const [newSubInput, setNewSubInput] = useState<{ [catId: string]: string }>({});
  const [subError, setSubError] = useState<{ [catId: string]: string }>({});

  // Delete confirmation state
  const [deleteConfirmCat, setDeleteConfirmCat] = useState<CategoryInfo | null>(null);

  const filteredCategories = useMemo(() => {
    return categories.filter((cat) => {
      const matchesType =
        typeFilter === 'all'
          ? true
          : cat.type === typeFilter || (typeFilter === 'expense' && cat.type === 'both') || (typeFilter === 'income' && cat.type === 'both');

      const matchesSearch =
        searchQuery.trim() === '' ||
        cat.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        cat.subcategories.some((s) => s.toLowerCase().includes(searchQuery.toLowerCase()));

      return matchesType && matchesSearch;
    });
  }, [categories, typeFilter, searchQuery]);

  const handleCreateCategory = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);

    const subcats = newSubcategoriesStr
      .split(',')
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

    const limit = parseFloat(newBudgetLimit);

    const res = addMainCategory({
      name: newName,
      emoji: newEmoji,
      type: newType,
      subcategories: subcats,
      initialBudgetLimit: isNaN(limit) ? 2500 : limit,
    });

    if (!res.success) {
      setFormError(res.error || 'Failed to add category');
      return;
    }

    setActionNotice({
      type: 'success',
      message: `Main category "${newName}" added successfully with ${subcats.length} subcategories.`,
    });
    setTimeout(() => setActionNotice(null), 3000);

    // Reset form
    setNewName('');
    setNewEmoji('🏷️');
    setNewType('expense');
    setNewSubcategoriesStr('');
    setNewBudgetLimit('2500');
    setShowAddForm(false);
  };

  const handleAddSubcat = (cat: CategoryInfo) => {
    const inputVal = (newSubInput[cat.id] || '').trim();
    if (!inputVal) return;

    const res = addSubcategory(cat.id, inputVal);
    if (!res.success) {
      setSubError((prev) => ({ ...prev, [cat.id]: res.error || 'Failed to add subcategory' }));
      return;
    }

    setSubError((prev) => ({ ...prev, [cat.id]: '' }));
    setNewSubInput((prev) => ({ ...prev, [cat.id]: '' }));
    setActionNotice({
      type: 'success',
      message: `Added subcategory "${inputVal}" to ${cat.name}.`,
    });
    setTimeout(() => setActionNotice(null), 2500);
  };

  const handleDeleteSubcat = (cat: CategoryInfo, sub: string) => {
    const res = deleteSubcategory(cat.id, sub);
    if (!res.success) {
      setActionNotice({
        type: 'error',
        message: res.error || 'Cannot delete subcategory.',
      });
      setTimeout(() => setActionNotice(null), 4000);
      return;
    }

    setActionNotice({
      type: 'success',
      message: `Removed subcategory "${sub}".`,
    });
    setTimeout(() => setActionNotice(null), 2500);
  };

  const handleConfirmDeleteCat = () => {
    if (!deleteConfirmCat) return;
    const res = deleteMainCategory(deleteConfirmCat.id);
    if (!res.success) {
      setActionNotice({
        type: 'error',
        message: res.error || 'Failed to delete category.',
      });
      setTimeout(() => setActionNotice(null), 4000);
      setDeleteConfirmCat(null);
      return;
    }

    setActionNotice({
      type: 'success',
      message: `Category "${deleteConfirmCat.name}" deleted.`,
    });
    setTimeout(() => setActionNotice(null), 2500);
    setDeleteConfirmCat(null);
  };

  return (
    <div className="space-y-4">
      {/* Informative Accounting Notice */}
      <div className="p-3 rounded-2xl bg-[#FFEEDF]/60 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] flex items-start gap-2.5">
        <ShieldCheck size={18} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0 mt-0.5" />
        <div className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
          <span className="font-bold text-[#15120F] dark:text-[#F6EFE8]">
            Custom Categories & Accounting Guard:{' '}
          </span>
          Customize categories and subcategories to match your lifestyle. To protect audit integrity and prevent orphaned transactions, any category with existing transactions cannot be deleted.
        </div>
      </div>

      {/* Action Notification Banner */}
      {actionNotice && (
        <div
          className={`p-3 rounded-xl text-xs font-semibold flex items-center gap-2 border animate-in fade-in duration-200 ${
            actionNotice.type === 'success'
              ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-800 dark:text-emerald-300'
              : 'bg-red-500/10 border-red-500/30 text-red-800 dark:text-red-300'
          }`}
        >
          {actionNotice.type === 'success' ? (
            <CheckCircle2 size={16} className="shrink-0" />
          ) : (
            <AlertCircle size={16} className="shrink-0" />
          )}
          <span>{actionNotice.message}</span>
        </div>
      )}

      {/* Action Bar: Search & New Category Button */}
      <div className="flex flex-col sm:flex-row gap-2 items-stretch sm:items-center justify-between">
        <div className="relative flex-1">
          <Search size={14} className="absolute left-3 top-1/2 -translate-y-1/2 text-[#6B6156] dark:text-[#AC9E92]" />
          <input
            type="text"
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            placeholder="Search categories or subcategories..."
            className="w-full pl-8 pr-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs font-medium text-[#15120F] dark:text-[#F6EFE8] placeholder:text-[#6B6156] dark:placeholder:text-[#AC9E92] focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52]"
          />
        </div>

        <button
          type="button"
          onClick={() => {
            setShowAddForm(!showAddForm);
            setFormError(null);
          }}
          className="flex items-center justify-center gap-1.5 px-3 py-2 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold transition-all shadow-xs cursor-pointer hover:opacity-90 shrink-0"
        >
          <Plus size={14} />
          <span>New Main Category</span>
        </button>
      </div>

      {/* Filter Tabs */}
      <div className="flex items-center gap-1.5 p-1 rounded-xl bg-[#FFEEDF]/40 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs overflow-x-auto">
        {(['all', 'expense', 'income', 'both'] as const).map((tab) => (
          <button
            key={tab}
            type="button"
            onClick={() => setTypeFilter(tab)}
            className={`px-3 py-1 rounded-lg font-bold capitalize transition-all whitespace-nowrap cursor-pointer ${
              typeFilter === tab
                ? 'bg-white dark:bg-[#27201A] text-[#B03C09] dark:text-[#FF9A52] shadow-xs'
                : 'text-[#6B6156] dark:text-[#AC9E92] hover:text-[#15120F] dark:hover:text-[#F6EFE8]'
            }`}
          >
            {tab === 'all' ? `All (${categories.length})` : tab}
          </button>
        ))}
      </div>

      {/* Add Category Form Modal/Panel */}
      {showAddForm && (
        <form
          onSubmit={handleCreateCategory}
          className="p-4 rounded-2xl bg-white dark:bg-[#27201A] border-2 border-[#B03C09]/30 dark:border-[#FF9A52]/30 shadow-md space-y-3 animate-in fade-in duration-200"
        >
          <div className="flex items-center justify-between pb-2 border-b border-[#F3DFCD] dark:border-[#383029]">
            <div className="flex items-center gap-2">
              <FolderPlus size={16} className="text-[#B03C09] dark:text-[#FF9A52]" />
              <h4 className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8]">
                Create New Main Category
              </h4>
            </div>
            <button
              type="button"
              onClick={() => setShowAddForm(false)}
              className="text-xs text-[#6B6156] dark:text-[#AC9E92] hover:underline cursor-pointer"
            >
              Cancel
            </button>
          </div>

          {formError && (
            <div className="p-2.5 rounded-xl bg-red-500/10 border border-red-500/30 text-red-700 dark:text-red-300 text-xs flex items-center gap-1.5">
              <AlertCircle size={14} className="shrink-0" />
              <span>{formError}</span>
            </div>
          )}

          {/* Emoji & Name */}
          <div className="grid grid-cols-1 sm:grid-cols-4 gap-2">
            <div className="col-span-1">
              <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                Emoji
              </label>
              <div className="flex items-center gap-1.5">
                <input
                  type="text"
                  maxLength={2}
                  value={newEmoji}
                  onChange={(e) => setNewEmoji(e.target.value)}
                  className="w-12 h-10 text-center text-xl rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] focus:outline-none"
                />
                <div className="flex flex-wrap gap-1 max-w-[120px] max-h-10 overflow-y-auto">
                  {QUICK_EMOJIS.slice(0, 8).map((em) => (
                    <button
                      key={em}
                      type="button"
                      onClick={() => setNewEmoji(em)}
                      className="text-xs hover:scale-125 transition-transform cursor-pointer"
                    >
                      {em}
                    </button>
                  ))}
                </div>
              </div>
            </div>

            <div className="col-span-3">
              <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                Main Category Name *
              </label>
              <input
                type="text"
                required
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                placeholder="e.g. Pet Care, Online Selling, Photography"
                className="w-full h-10 px-3 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52]"
              />
            </div>
          </div>

          {/* Classification & Budget */}
          <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
            <div>
              <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                Category Type
              </label>
              <div className="grid grid-cols-3 gap-1">
                {(['expense', 'income', 'both'] as const).map((t) => (
                  <button
                    key={t}
                    type="button"
                    onClick={() => setNewType(t)}
                    className={`py-1.5 px-2 rounded-xl text-xs font-bold capitalize transition-all border text-center cursor-pointer ${
                      newType === t
                        ? 'bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] border-transparent'
                        : 'bg-[#FFEEDF]/30 dark:bg-[#14100D] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                    }`}
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>

            {(newType === 'expense' || newType === 'both') && (
              <div>
                <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] block mb-1">
                  Initial Monthly Spending Limit (₱)
                </label>
                <input
                  type="number"
                  value={newBudgetLimit}
                  onChange={(e) => setNewBudgetLimit(e.target.value)}
                  placeholder="2500"
                  className="w-full h-9 px-3 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] focus:outline-none"
                />
              </div>
            )}
          </div>

          {/* Subcategories */}
          <div>
            <label className="text-[10px] font-bold text-[#6B6156] dark:text-[#AC9E92] block mb-1">
              Subcategories (comma-separated)
            </label>
            <input
              type="text"
              value={newSubcategoriesStr}
              onChange={(e) => setNewSubcategoriesStr(e.target.value)}
              placeholder="e.g. Pet Food, Vet Clinic, Grooming, Vitamins"
              className="w-full px-3 py-2 rounded-xl bg-[#FFEEDF]/30 dark:bg-[#14100D] border border-[#F3DFCD] dark:border-[#383029] text-xs text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52]"
            />
            <span className="text-[10px] text-[#6B6156] dark:text-[#AC9E92] block mt-0.5">
              You can also add or remove subcategories individually anytime.
            </span>
          </div>

          <div className="flex justify-end gap-2 pt-2 border-t border-[#F3DFCD] dark:border-[#383029]">
            <button
              type="button"
              onClick={() => setShowAddForm(false)}
              className="px-3.5 py-1.5 rounded-xl text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] hover:bg-black/5 cursor-pointer"
            >
              Cancel
            </button>
            <button
              type="submit"
              className="px-4 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold cursor-pointer hover:opacity-90 shadow-xs"
            >
              Save Category
            </button>
          </div>
        </form>
      )}

      {/* Category List */}
      <div className="space-y-2.5">
        {filteredCategories.length === 0 ? (
          <div className="p-8 text-center text-xs text-[#6B6156] dark:text-[#AC9E92] border border-dashed border-[#F3DFCD] dark:border-[#383029] rounded-2xl">
            No categories found matching your filter or search query.
          </div>
        ) : (
          filteredCategories.map((cat) => {
            const txCount = getCategoryTransactionCount(cat.name);
            const isLocked = txCount > 0;
            const isExpanded = expandedCatId === cat.id;
            const budgetItem = budgets.find((b) => b.category.toLowerCase() === cat.name.toLowerCase());

            return (
              <div
                key={cat.id}
                className="rounded-2xl border border-[#F3DFCD] dark:border-[#383029] bg-white dark:bg-[#27201A] overflow-hidden transition-all shadow-2xs"
              >
                {/* Header Row */}
                <div className="p-3 flex items-center justify-between gap-2.5">
                  <div className="flex items-center gap-2.5 min-w-0 flex-1">
                    <span className="text-xl shrink-0">{cat.emoji}</span>
                    <div className="min-w-0 flex-1">
                      <div className="flex items-center gap-2 flex-wrap">
                        <span className="text-xs font-bold text-[#15120F] dark:text-[#F6EFE8] truncate">
                          {cat.name}
                        </span>
                        {cat.isCustom && (
                          <span className="px-1.5 py-0.2 rounded-md bg-[#FFEEDF] dark:bg-[#14100D] border border-[#B03C09]/20 dark:border-[#FF9A52]/20 text-[9px] font-bold text-[#B03C09] dark:text-[#FF9A52]">
                            Custom
                          </span>
                        )}
                        <span className="px-1.5 py-0.2 rounded-md bg-black/5 dark:bg-white/5 text-[9px] font-semibold text-[#6B6156] dark:text-[#AC9E92] capitalize">
                          {cat.type || 'expense'}
                        </span>
                      </div>

                      <div className="flex items-center gap-2 mt-0.5 text-[11px] text-[#6B6156] dark:text-[#AC9E92] flex-wrap">
                        <span>{cat.subcategories.length} subcategories</span>
                        <span>•</span>
                        {isLocked ? (
                          <span className="inline-flex items-center gap-1 font-semibold text-amber-700 dark:text-amber-400">
                            <Lock size={11} className="shrink-0" />
                            <span>{txCount} recorded transaction{txCount > 1 ? 's' : ''} (Protected)</span>
                          </span>
                        ) : (
                          <span className="inline-flex items-center gap-1 text-emerald-700 dark:text-emerald-400 font-medium">
                            <CheckCircle2 size={11} className="shrink-0" />
                            <span>0 transactions (Deletable)</span>
                          </span>
                        )}
                        {budgetItem && (
                          <>
                            <span>•</span>
                            <span>Limit: ₱{budgetItem.limit.toLocaleString()}</span>
                          </>
                        )}
                      </div>
                    </div>
                  </div>

                  {/* Actions */}
                  <div className="flex items-center gap-1.5 shrink-0">
                    <button
                      type="button"
                      onClick={() => setExpandedCatId(isExpanded ? null : cat.id)}
                      className="p-1.5 rounded-lg text-[#6B6156] dark:text-[#AC9E92] hover:bg-[#FFEEDF] dark:hover:bg-[#14100D] transition-colors cursor-pointer"
                      title={isExpanded ? 'Collapse subcategories' : 'View subcategories'}
                    >
                      {isExpanded ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
                    </button>

                    {/* Delete button: strictly verified */}
                    {isLocked ? (
                      <button
                        type="button"
                        onClick={() => {
                          setActionNotice({
                            type: 'error',
                            message: `Cannot delete "${cat.name}": It has ${txCount} transaction${txCount > 1 ? 's' : ''} recorded in your ledger. Delete or reassign those transactions first to protect accounting integrity.`,
                          });
                          setTimeout(() => setActionNotice(null), 5000);
                        }}
                        className="p-1.5 rounded-lg text-[#AC9E92] dark:text-[#5A5148] hover:text-amber-600 dark:hover:text-amber-400 transition-colors cursor-pointer"
                        title={`Locked: ${txCount} transaction${txCount > 1 ? 's' : ''} recorded`}
                      >
                        <Lock size={15} />
                      </button>
                    ) : (
                      <button
                        type="button"
                        onClick={() => setDeleteConfirmCat(cat)}
                        className="p-1.5 rounded-lg text-red-600 dark:text-red-400 hover:bg-red-500/10 transition-colors cursor-pointer"
                        title="Delete category"
                      >
                        <Trash2 size={15} />
                      </button>
                    )}
                  </div>
                </div>

                {/* Expanded Subcategories Drawer */}
                {isExpanded && (
                  <div className="p-3 bg-[#FFEEDF]/30 dark:bg-[#14100D]/50 border-t border-[#F3DFCD] dark:border-[#383029] space-y-2.5">
                    <div className="flex items-center justify-between text-[11px] font-bold text-[#5A5148] dark:text-[#C6B8AC]">
                      <span>Subcategories ({cat.subcategories.length})</span>
                      <span className="text-[10px] font-normal text-[#6B6156] dark:text-[#AC9E92]">
                        Items with transactions are protected
                      </span>
                    </div>

                    {/* Subcategories Chips / List */}
                    {cat.subcategories.length === 0 ? (
                      <div className="text-[11px] text-[#6B6156] dark:text-[#AC9E92] italic py-1">
                        No subcategories yet. Add one below.
                      </div>
                    ) : (
                      <div className="flex flex-wrap gap-1.5">
                        {cat.subcategories.map((sub) => {
                          const subTxCount = getCategoryTransactionCount(cat.name, sub);
                          const isSubLocked = subTxCount > 0;

                          return (
                            <div
                              key={sub}
                              className={`inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs border transition-all ${
                                isSubLocked
                                  ? 'bg-white dark:bg-[#27201A] text-[#15120F] dark:text-[#F6EFE8] border-[#F3DFCD] dark:border-[#383029]'
                                  : 'bg-white dark:bg-[#27201A] text-[#5A5148] dark:text-[#C6B8AC] border-[#F3DFCD] dark:border-[#383029]'
                              }`}
                            >
                              <Tag size={11} className="text-[#B03C09] dark:text-[#FF9A52] shrink-0" />
                              <span>{sub}</span>

                              {isSubLocked ? (
                                <span
                                  className="text-[10px] font-bold text-amber-700 dark:text-amber-400 ml-0.5 flex items-center gap-0.5"
                                  title={`${subTxCount} transaction${subTxCount > 1 ? 's' : ''} recorded (Protected)`}
                                >
                                  <Lock size={10} />
                                  <span>{subTxCount}</span>
                                </span>
                              ) : (
                                <button
                                  type="button"
                                  onClick={() => handleDeleteSubcat(cat, sub)}
                                  className="text-[#6B6156] hover:text-red-600 dark:hover:text-red-400 p-0.5 rounded cursor-pointer transition-colors"
                                  title="Delete subcategory (0 transactions)"
                                >
                                  <Trash2 size={12} />
                                </button>
                              )}
                            </div>
                          );
                        })}
                      </div>
                    )}

                    {/* Inline Add Subcategory input */}
                    <div className="pt-1.5">
                      <div className="flex items-center gap-1.5">
                        <input
                          type="text"
                          value={newSubInput[cat.id] || ''}
                          onChange={(e) => {
                            const val = e.target.value;
                            setNewSubInput((prev) => ({ ...prev, [cat.id]: val }));
                            setSubError((prev) => ({ ...prev, [cat.id]: '' }));
                          }}
                          onKeyDown={(e) => {
                            if (e.key === 'Enter') {
                              e.preventDefault();
                              handleAddSubcat(cat);
                            }
                          }}
                          placeholder={`Add new subcategory to ${cat.name}...`}
                          className="flex-1 px-3 py-1.5 rounded-xl bg-white dark:bg-[#27201A] border border-[#F3DFCD] dark:border-[#383029] text-xs text-[#15120F] dark:text-[#F6EFE8] focus:outline-none focus:border-[#B03C09] dark:focus:border-[#FF9A52]"
                        />
                        <button
                          type="button"
                          onClick={() => handleAddSubcat(cat)}
                          className="px-3 py-1.5 rounded-xl bg-[#B03C09] dark:bg-[#FF9A52] text-white dark:text-[#1E0E03] text-xs font-bold transition-all cursor-pointer hover:opacity-90 shrink-0"
                        >
                          Add
                        </button>
                      </div>
                      {subError[cat.id] && (
                        <div className="text-[11px] text-red-600 dark:text-red-400 mt-1 flex items-center gap-1">
                          <AlertCircle size={11} />
                          <span>{subError[cat.id]}</span>
                        </div>
                      )}
                    </div>
                  </div>
                )}
              </div>
            );
          })
        )}
      </div>

      {/* Delete Category Modal */}
      {deleteConfirmCat && (
        <div className="fixed inset-0 z-60 flex items-center justify-center p-4 bg-black/50 backdrop-blur-xs">
          <div className="w-full max-w-sm bg-white dark:bg-[#27201A] rounded-2xl p-5 border border-[#F3DFCD] dark:border-[#383029] shadow-2xl space-y-3">
            <div className="flex items-center gap-2 text-red-600 dark:text-red-400">
              <Trash2 size={18} />
              <h4 className="text-sm font-bold">Delete Category</h4>
            </div>

            <p className="text-xs text-[#5A5148] dark:text-[#C6B8AC] leading-relaxed">
              Are you sure you want to delete <strong className="text-[#15120F] dark:text-[#F6EFE8]">{deleteConfirmCat.emoji} {deleteConfirmCat.name}</strong> and its {deleteConfirmCat.subcategories.length} subcategories?
            </p>

            <div className="p-2.5 rounded-xl bg-emerald-500/10 border border-emerald-500/20 text-[11px] text-emerald-800 dark:text-emerald-300 flex items-center gap-1.5">
              <CheckCircle2 size={13} className="shrink-0" />
              <span>Accounting audit confirmed: 0 transactions are linked to this category.</span>
            </div>

            <div className="flex justify-end gap-2 pt-2">
              <button
                type="button"
                onClick={() => setDeleteConfirmCat(null)}
                className="px-3.5 py-1.5 rounded-xl text-xs font-semibold text-[#6B6156] dark:text-[#AC9E92] hover:bg-black/5 cursor-pointer"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmDeleteCat}
                className="px-4 py-1.5 rounded-xl bg-red-600 text-white text-xs font-bold cursor-pointer hover:bg-red-700 shadow-xs"
              >
                Confirm Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};
